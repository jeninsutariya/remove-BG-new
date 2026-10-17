//
//  BackgroundRemovalViewModel.swift
//  Background Removal
//
//  State of one project shared by RemovingBackgroundVC, RemovingBackgroundEditorVC and
//  ExportVC / RefineEdgesVC: items, sequential processing queue, caches, backgrounds and edits.
//
//  • Items are processed one at a time (Waiting → Processing → Completed / Failed).
//  • An item is never queued twice and a completed item is never processed again.
//  • Every state change is saved to disk and announced with `itemDidChangeNotification`.
//

import UIKit

/// One undo/redo step of the editor.
nonisolated struct ItemSnapshot: Equatable {
    let itemID: UUID
    let background: BackgroundSelection
    let edits: ItemEdits
    let foregroundFileName: String?
}

final class BackgroundRemovalViewModel {

    static let itemDidChangeNotification = Notification.Name("BackgroundRemovalItemDidChange")
    static let queueDidFinishNotification = Notification.Name("BackgroundRemovalQueueDidFinish")
    static let itemIDKey = "itemID"

    private(set) var project: BackgroundRemovalProject
    private let storage = ProjectStorageService.shared
    private let remover = BackgroundRemovalService.shared
    private let compositor = ImageCompositingService.shared

    private var queue: [UUID] = []
    private var runner: Task<Void, Never>?
    private(set) var currentItemID: UUID?

    private let foregroundCache = NSCache<NSUUID, UIImage>()
    private let imageCache = NSCache<NSString, UIImage>()

    init(project: BackgroundRemovalProject) {
        self.project = project
        foregroundCache.countLimit = 2
        imageCache.countLimit = 60
    }

    // MARK: - Creation

    /// Creates a project from picked photos. Photos are decoded and stored one at a time.
    static func create(from picked: [PickedImage], mode: EditorMode = .removeBackground) async throws -> BackgroundRemovalViewModel {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        let name = picked.count > 1 ? "Batch · \(formatter.string(from: Date()))"
                                    : (picked.first?.suggestedName ?? "Cutout · \(formatter.string(from: Date()))")
        var project = BackgroundRemovalProject(name: name, mode: mode)
        let storage = ProjectStorageService.shared
        let projectID = project.id

        for photo in picked {
            let itemID = UUID()
            let fileName = try await Task.detached(priority: .userInitiated) { () throws -> String in
                defer { photo.discardTemporaryFile() }
                guard let image = photo.loadImage(maxPixel: BackgroundRemovalService.maxProcessingDimension) else {
                    throw BackgroundRemovalError.invalidImage
                }
                return try storage.saveOriginal(image, itemID: itemID, projectID: projectID,
                                                maxDimension: BackgroundRemovalService.maxProcessingDimension)
            }.value
            project.items.append(BackgroundRemovalItem(id: itemID, sourceName: photo.suggestedName, originalFileName: fileName))
        }
        guard !project.items.isEmpty else { throw BackgroundRemovalError.invalidImage }
        try storage.save(project)
        return BackgroundRemovalViewModel(project: project)
    }

    // MARK: - Items

    var items: [BackgroundRemovalItem] { project.items }

    func item(_ id: UUID) -> BackgroundRemovalItem? {
        project.items.first { $0.id == id }
    }

    var isProcessing: Bool { runner != nil }

    var hasPendingItems: Bool {
        project.items.contains { $0.status == .waiting || $0.status == .processing }
    }

    // MARK: - Processing queue

    /// Queues items that still need a transparent foreground. Completed items are skipped
    /// (their saved result is reused). Failed items are only queued when passed explicitly.
    func startProcessing(_ ids: [UUID]? = nil) {
        let candidates = ids ?? project.items.filter { $0.status == .waiting }.map(\.id)
        for id in candidates {
            guard let item = item(id), !item.isCompleted, !queue.contains(id), currentItemID != id else { continue }
            if item.status == .failed { update(id) { $0.status = .waiting; $0.errorMessage = nil } }
            queue.append(id)
        }
        runQueueIfNeeded()
    }

    func retry(_ id: UUID) {
        startProcessing([id])
    }

    /// Stops after the current Vision request; unfinished items stay "Waiting".
    func cancelProcessing() {
        queue.removeAll()
        runner?.cancel()
    }

    private func runQueueIfNeeded() {
        guard runner == nil, !queue.isEmpty else { return }
        runner = Task { [weak self] in
            await self?.drainQueue()
        }
    }

    private func drainQueue() async {
        while !queue.isEmpty, !Task.isCancelled {
            let id = queue.removeFirst()
            guard let item = item(id), !item.isCompleted else { continue }
            await process(item)
        }
        if Task.isCancelled {
            for id in project.items.map(\.id) where item(id)?.status == .processing {
                update(id) { $0.status = .waiting }
            }
        }
        runner = nil
        currentItemID = nil
        if !queue.isEmpty {
            // Items were queued while a cancelled run was finishing.
            runQueueIfNeeded()
            return
        }
        NotificationCenter.default.post(name: Self.queueDidFinishNotification, object: self)
    }

    private func process(_ item: BackgroundRemovalItem) async {
        currentItemID = item.id
        update(item.id) { $0.status = .processing; $0.errorMessage = nil }

        let projectID = project.id
        let storage = self.storage
        let originalName = item.originalFileName
        let original = await Task.detached(priority: .userInitiated) {
            storage.loadImage(originalName, projectID: projectID, maxPixel: BackgroundRemovalService.maxProcessingDimension)
        }.value

        do {
            guard let original else { throw BackgroundRemovalError.invalidImage }
            let foreground = try await remover.removeBackground(from: original)
            let itemID = item.id
            let fileName = try await Task.detached(priority: .userInitiated) {
                try storage.saveForeground(foreground, itemID: itemID, projectID: projectID)
            }.value
            foregroundCache.setObject(foreground, forKey: item.id as NSUUID)
            invalidateImages(for: item.id)
            update(item.id) {
                $0.foregroundFileName = fileName
                $0.status = .completed
                $0.errorMessage = nil
            }
        } catch let error as BackgroundRemovalError where error == .cancelled {
            update(item.id) { $0.status = .waiting }
        } catch is CancellationError {
            update(item.id) { $0.status = .waiting }
        } catch {
            update(item.id) {
                $0.status = .failed
                $0.errorMessage = error.localizedDescription
            }
        }
        currentItemID = nil
    }

    // MARK: - Mutations

    private func update(_ id: UUID, _ change: (inout BackgroundRemovalItem) -> Void) {
        guard let index = project.index(of: id) else { return }
        change(&project.items[index])
        project.items[index].modifiedAt = Date()
        project.modifiedAt = Date()
        save()
        NotificationCenter.default.post(name: Self.itemDidChangeNotification, object: self,
                                        userInfo: [Self.itemIDKey: id])
    }

    func save() {
        try? storage.save(project)
    }

    /// Stores the background for one item only (other items keep theirs). Replaced custom
    /// files are kept until `purgeUnusedFiles()` so undo can bring them back.
    func setBackground(_ selection: BackgroundSelection, for id: UUID) {
        guard let old = item(id)?.background, old != selection else { return }
        update(id) { $0.background = selection }
    }

    /// Stores the Shadow / Resize edits of one item.
    func setEdits(_ edits: ItemEdits, for id: UUID) {
        guard let old = item(id)?.edits, old != edits else { return }
        update(id) { $0.edits = edits }
    }

    /// Restores an editor undo/redo state.
    func restore(_ snapshot: ItemSnapshot) {
        guard let current = item(snapshot.itemID) else { return }
        if current.foregroundFileName != snapshot.foregroundFileName {
            foregroundCache.removeObject(forKey: snapshot.itemID as NSUUID)
        }
        update(snapshot.itemID) {
            $0.background = snapshot.background
            $0.edits = snapshot.edits
            if let foreground = snapshot.foregroundFileName { $0.foregroundFileName = foreground }
        }
    }

    func snapshot(of id: UUID) -> ItemSnapshot? {
        item(id).map { ItemSnapshot(itemID: id, background: $0.background, edits: $0.edits,
                                    foregroundFileName: $0.foregroundFileName) }
    }

    /// Deletes files no item references any more (call when leaving the editor).
    func purgeUnusedFiles() {
        guard !isProcessing else { return }
        storage.purgeUnreferencedFiles(in: project)
    }

    // MARK: - Refine

    /// Original photo and current matte for Refine Edges (same pixel size).
    func refineInputs(for id: UUID) async -> (original: UIImage, mask: CGImage)? {
        guard let item = item(id), item.isCompleted else { return nil }
        let projectID = project.id
        let storage = self.storage
        let originalName = item.originalFileName
        let foreground = await fullForeground(for: id)
        return await Task.detached(priority: .userInitiated) { () -> (original: UIImage, mask: CGImage)? in
            guard let original = storage.loadImage(originalName, projectID: projectID,
                                                    maxPixel: BackgroundRemovalService.maxProcessingDimension),
                  let originalCG = ImageUtilities.uprightCGImage(from: original),
                  let foregroundCG = foreground.flatMap({ ImageUtilities.uprightCGImage(from: $0) }),
                  let mask = MaskRefineService.alphaMask(of: foregroundCG,
                                                         size: CGSize(width: originalCG.width, height: originalCG.height))
            else { return nil }
            return (UIImage(cgImage: originalCG, scale: 1, orientation: .up), mask)
        }.value
    }

    /// Rebuilds the foreground from the original and the refined matte, and saves it as a new file.
    func applyRefinedMask(_ mask: CGImage, original: UIImage, for id: UUID) async throws {
        guard item(id) != nil else { return }
        let projectID = project.id
        let storage = self.storage
        let (fileName, foreground) = try await Task.detached(priority: .userInitiated) { () throws -> (String, UIImage) in
            guard let originalCG = original.cgImage,
                  let cut = MaskRefineService.cutout(original: originalCG, mask: mask) else {
                throw BackgroundRemovalError.compositingFailed
            }
            let image = UIImage(cgImage: cut, scale: 1, orientation: .up)
            return (try storage.saveForeground(image, itemID: id, projectID: projectID), image)
        }.value
        foregroundCache.setObject(foreground, forKey: id as NSUUID)
        update(id) { $0.foregroundFileName = fileName }
    }

    /// Saves a user-picked background into the project folder.
    func addCustomBackground(_ image: UIImage) async throws -> BackgroundSelection {
        let projectID = project.id
        let storage = self.storage
        let fileName = try await Task.detached(priority: .userInitiated) {
            try storage.saveCustomBackground(image, projectID: projectID,
                                             maxDimension: BackgroundRemovalService.maxProcessingDimension)
        }.value
        return .customImage(fileName: fileName)
    }

    /// Removes a custom background file that was added but never kept.
    func discardCustomBackgroundIfUnused(_ selection: BackgroundSelection) {
        if let file = selection.customFileName { storage.deleteFileIfUnreferenced(file, in: project) }
    }

    func recordExport(quality: ExportQuality) {
        project.exportSettings.lastExportQuality = quality
        project.exportSettings.lastExportDate = Date()
        project.modifiedAt = Date()
        save()
    }

    func rename(_ name: String) {
        project.name = name
        save()
    }

    // MARK: - Images

    /// Full-resolution transparent foreground (for export).
    func fullForeground(for id: UUID) async -> UIImage? {
        if let cached = foregroundCache.object(forKey: id as NSUUID) { return cached }
        guard let name = item(id)?.foregroundFileName else { return nil }
        let projectID = project.id
        let storage = self.storage
        let image = await Task.detached(priority: .userInitiated) {
            storage.loadImage(name, projectID: projectID)
        }.value
        if let image { foregroundCache.setObject(image, forKey: id as NSUUID) }
        return image
    }

    /// Downsampled image from the project folder (cached).
    private func projectImage(_ fileName: String?, maxPixel: CGFloat) async -> UIImage? {
        guard let fileName else { return nil }
        let key = "\(fileName)#\(Int(maxPixel))" as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        let projectID = project.id
        let storage = self.storage
        let image = await Task.detached(priority: .userInitiated) {
            storage.loadImage(fileName, projectID: projectID, maxPixel: maxPixel)
        }.value
        if let image { imageCache.setObject(image, forKey: key) }
        return image
    }

    func originalPreview(for id: UUID, maxPixel: CGFloat = 1600) async -> UIImage? {
        await projectImage(item(id)?.originalFileName, maxPixel: maxPixel)
    }

    func foregroundPreview(for id: UUID, maxPixel: CGFloat = 1600) async -> UIImage? {
        await projectImage(item(id)?.foregroundFileName, maxPixel: maxPixel)
    }

    /// Thumbnail for the strip: the cutout when finished, otherwise the original.
    func thumbnail(for id: UUID) async -> UIImage? {
        guard let item = item(id) else { return nil }
        if item.isCompleted { return await foregroundPreview(for: id, maxPixel: 240) }
        return await originalPreview(for: id, maxPixel: 240)
    }

    /// Preview composited with the same service and edits used for export (smaller size).
    func compositePreview(for id: UUID, background: BackgroundSelection, edits: ItemEdits? = nil,
                          maxPixel: CGFloat = 1400) async throws -> UIImage? {
        guard let foreground = await foregroundPreview(for: id, maxPixel: maxPixel) else { return nil }
        let edits = edits ?? item(id)?.edits ?? ItemEdits.unedited
        if background.isTransparent, edits == ItemEdits.unedited { return foreground }
        let resolved = try await resolveBackground(background, maxPixel: maxPixel * 1.5)
        let compositor = self.compositor
        return await Task.detached(priority: .userInitiated) {
            compositor.composeImage(foreground: foreground, background: resolved, edits: edits)
        }.value
    }

    /// Turns a stored selection into a drawable background (downloads remote images via SDWebImage).
    func resolveBackground(_ selection: BackgroundSelection, maxPixel: CGFloat? = nil) async throws -> ResolvedBackground {
        switch selection {
        case .none:
            return .none
        case .color(let hex):
            return .color(UIColor(hexRGB: hex) ?? .white)
        case .remoteImage(_, let url):
            return .image(try await BackgroundImageService.shared.fullImage(for: url))
        case .customImage(let fileName):
            let image: UIImage?
            if let maxPixel {
                image = await projectImage(fileName, maxPixel: maxPixel)
            } else {
                let projectID = project.id
                let storage = self.storage
                image = await Task.detached { storage.loadImage(fileName, projectID: projectID) }.value
            }
            guard let image else { throw ProjectStorageError.writeFailed("The custom background file is missing.") }
            return .image(image)
        }
    }

    private func invalidateImages(for id: UUID) {
        guard let item = item(id) else { return }
        for name in [item.foregroundFileName].compactMap({ $0 }) {
            for size in [240, 1400, 1600] { imageCache.removeObject(forKey: "\(name)#\(size)" as NSString) }
        }
    }
}
