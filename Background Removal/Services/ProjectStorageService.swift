//
//  ProjectStorageService.swift
//  Background Removal
//
//  Local project persistence.
//
//  Application Support/BackgroundRemovalProjects/<projectID>/
//      project.json                    metadata (Codable BackgroundRemovalProject)
//      original_<itemID>.jpg           original photo (stored once, never replaced)
//      foreground_<itemID>.png         transparent foreground (real alpha)
//      background_<uuid>.jpg           custom backgrounds picked by the user
//
//  Large images live on disk; only file names are kept in the metadata (never in UserDefaults).
//  All methods are thread-safe and may be called from background tasks.
//

import UIKit

nonisolated enum ProjectStorageError: LocalizedError {
    case encodingFailed
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "The image couldn't be encoded."
        case .writeFailed(let reason): return "The project couldn't be saved: \(reason)"
        }
    }
}

nonisolated final class ProjectStorageService: Sendable {

    static let shared = ProjectStorageService()
    static let didChangeNotification = Notification.Name("ProjectStorageServiceDidChange")

    private var fileManager: FileManager { .default }

    var rootURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("BackgroundRemovalProjects", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func folder(for projectID: UUID) -> URL {
        let url = rootURL.appendingPathComponent(projectID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func fileURL(_ fileName: String, projectID: UUID) -> URL {
        folder(for: projectID).appendingPathComponent(fileName)
    }

    func fileExists(_ fileName: String?, projectID: UUID) -> Bool {
        guard let fileName else { return false }
        return fileManager.fileExists(atPath: fileURL(fileName, projectID: projectID).path)
    }

    // MARK: - Metadata

    func save(_ project: BackgroundRemovalProject) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(project)
            try data.write(to: folder(for: project.id).appendingPathComponent("project.json"), options: .atomic)
        } catch {
            throw ProjectStorageError.writeFailed(error.localizedDescription)
        }
        Self.notifyChange()
    }

    /// Loads every project, newest first. Corrupted metadata is skipped; items whose files are
    /// missing are repaired (re-queued or marked failed) instead of crashing.
    func loadAllProjects() -> [BackgroundRemovalProject] {
        let folders = (try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var projects: [BackgroundRemovalProject] = []
        for folder in folders {
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("project.json")),
                  var project = try? decoder.decode(BackgroundRemovalProject.self, from: data) else { continue }
            project.items = project.items.compactMap { repaired($0, projectID: project.id) }
            guard !project.items.isEmpty else { continue }
            projects.append(project)
        }
        return projects.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func loadProject(id: UUID) -> BackgroundRemovalProject? {
        loadAllProjects().first { $0.id == id }
    }

    private func repaired(_ item: BackgroundRemovalItem, projectID: UUID) -> BackgroundRemovalItem? {
        // Without its original there is nothing left to edit or re-process.
        guard fileExists(item.originalFileName, projectID: projectID) else { return nil }
        var item = item
        if item.status == .processing {
            // The app was closed during processing.
            item.status = .waiting
        }
        if item.status == .completed, !fileExists(item.foregroundFileName, projectID: projectID) {
            item.status = .waiting
            item.foregroundFileName = nil
        }
        if let custom = item.background.customFileName, !fileExists(custom, projectID: projectID) {
            item.background = .none
        }
        return item
    }

    func deleteProject(id: UUID) {
        try? fileManager.removeItem(at: rootURL.appendingPathComponent(id.uuidString, isDirectory: true))
        Self.notifyChange()
    }

    /// Observers are UI code: always deliver on the main queue.
    private static func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    /// Removes a project file unless another item of the project still references it.
    func deleteFileIfUnreferenced(_ fileName: String, in project: BackgroundRemovalProject) {
        let referenced = project.items.contains {
            $0.originalFileName == fileName || $0.foregroundFileName == fileName || $0.background.customFileName == fileName
        }
        guard !referenced else { return }
        try? fileManager.removeItem(at: fileURL(fileName, projectID: project.id))
    }

    // MARK: - Images

    /// Stores the original once (JPEG 0.95 of the upright image ≤ maxDimension).
    func saveOriginal(_ image: UIImage, itemID: UUID, projectID: UUID, maxDimension: CGFloat) throws -> String {
        guard let cg = ImageUtilities.uprightCGImage(from: image, maxDimension: maxDimension),
              let data = ImageUtilities.jpegData(cg, quality: 0.95) else { throw ProjectStorageError.encodingFailed }
        let name = "original_\(itemID.uuidString).jpg"
        try write(data, name: name, projectID: projectID)
        return name
    }

    /// Stores the transparent foreground as PNG (alpha preserved).
    func saveForeground(_ image: UIImage, itemID: UUID, projectID: UUID) throws -> String {
        guard let cg = image.cgImage, let data = ImageUtilities.pngData(cg) else { throw ProjectStorageError.encodingFailed }
        let name = "foreground_\(itemID.uuidString).png"
        try write(data, name: name, projectID: projectID)
        return name
    }

    /// Stores a user-picked background (JPEG 0.92, ≤ maxDimension).
    func saveCustomBackground(_ image: UIImage, projectID: UUID, maxDimension: CGFloat) throws -> String {
        guard let cg = ImageUtilities.uprightCGImage(from: image, maxDimension: maxDimension),
              let data = ImageUtilities.jpegData(cg, quality: 0.92) else { throw ProjectStorageError.encodingFailed }
        let name = "background_\(UUID().uuidString).jpg"
        try write(data, name: name, projectID: projectID)
        return name
    }

    private func write(_ data: Data, name: String, projectID: UUID) throws {
        do {
            try data.write(to: fileURL(name, projectID: projectID), options: .atomic)
        } catch {
            throw ProjectStorageError.writeFailed(error.localizedDescription)
        }
    }

    /// Full-size image from the project folder.
    func loadImage(_ fileName: String?, projectID: UUID) -> UIImage? {
        guard let fileName else { return nil }
        let url = fileURL(fileName, projectID: projectID)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        return image
    }

    /// Memory-friendly downsampled image (thumbnails / previews).
    func loadImage(_ fileName: String?, projectID: UUID, maxPixel: CGFloat) -> UIImage? {
        guard let fileName else { return nil }
        return ImageUtilities.downsampledImage(at: fileURL(fileName, projectID: projectID), maxPixel: maxPixel)
    }
}
