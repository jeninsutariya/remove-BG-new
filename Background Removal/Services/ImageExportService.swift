//
//  ImageExportService.swift
//  Background Removal
//
//  Renders final images with the central export-quality policy and saves them to Photos.
//  • Automatic format: no background → PNG with the real alpha channel (never the checkerboard),
//    background applied → JPEG at the quality's compression. The Export screen can force PNG/JPG.
//  • Each item's Shadow / Resize edits are rendered by the same compositor as the preview.
//

import UIKit
import Photos

/// One rendered output file.
struct ExportedImage {
    let itemID: UUID
    let fileName: String
    let data: Data
    let isPNG: Bool
}

nonisolated enum ImageExportError: LocalizedError {
    case nothingToExport
    case photosAccessDenied
    case renderFailed(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .nothingToExport: return "There are no finished images to export yet."
        case .photosAccessDenied: return "Allow \"Add Photos Only\" access for this app in Settings to save images."
        case .renderFailed(let name): return "\(name) couldn't be rendered."
        case .saveFailed(let reason): return "Saving to Photos failed: \(reason)"
        }
    }
}

final class ImageExportService {

    static let shared = ImageExportService()

    /// Prevents duplicate saves from repeated taps.
    private(set) var isBusy = false

    /// Renders completed items one at a time (bounded memory), reporting progress 0…1.
    func renderOutputs(for items: [BackgroundRemovalItem], in viewModel: BackgroundRemovalViewModel,
                       quality: ExportQuality, options: ExportOptions = ExportOptions(),
                       progress: ((Double) -> Void)? = nil) async throws -> [ExportedImage] {
        let ready = items.filter(\.isCompleted)
        guard !ready.isEmpty else { throw ImageExportError.nothingToExport }
        var names = UniqueFileNamer()
        var outputs: [ExportedImage] = []
        for (index, item) in ready.enumerated() {
            try Task.checkCancellation()
            guard let foreground = await viewModel.fullForeground(for: item.id) else {
                throw ImageExportError.renderFailed(item.sourceName ?? "Image \(index + 1)")
            }
            let background = try await viewModel.resolveBackground(options.background(for: item))
            let maxDimension = options.maxDimension(for: quality)
            let jpegQuality = quality.jpegQuality
            let edits = item.edits
            let asPNG = options.format(for: item) == .png
            let rendered = await Task.detached(priority: .userInitiated) { () -> (Data, Bool)? in
                autoreleasepool { () -> (Data, Bool)? in
                    guard let cg = ImageCompositingService.shared.compose(foreground: foreground, background: background,
                                                                          edits: edits, maxDimension: maxDimension)
                    else { return nil }
                    if asPNG { return ImageUtilities.pngData(cg).map { ($0, true) } }
                    return ImageUtilities.jpegData(cg, quality: jpegQuality).map { ($0, false) }
                }
            }.value
            guard let rendered else {
                throw ImageExportError.renderFailed(item.sourceName ?? "Image \(index + 1)")
            }
            let (data, isPNG) = rendered
            let name = names.name(for: item.sourceName, index: index + 1, fileExtension: isPNG ? "png" : "jpg")
            outputs.append(ExportedImage(itemID: item.id, fileName: name, data: data, isPNG: isPNG))
            progress?(Double(index + 1) / Double(ready.count))
        }
        return outputs
    }

    /// Renders and saves the items to the photo library. Completes only after Photos confirms.
    func saveToPhotos(items: [BackgroundRemovalItem], in viewModel: BackgroundRemovalViewModel,
                      options: ExportOptions = ExportOptions(),
                      progress: ((Double) -> Void)? = nil) async throws -> Int {
        guard !isBusy else { return 0 }
        isBusy = true
        defer { isBusy = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw ImageExportError.photosAccessDenied }

        let quality = PremiumManager.shared.exportQuality
        let outputs = try await renderOutputs(for: items, in: viewModel, quality: quality, options: options) { value in
            progress?(value * 0.8)
        }
        for (index, output) in outputs.enumerated() {
            let data = output.data
            let fileName = output.fileName
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.originalFilename = fileName
                    request.addResource(with: .photo, data: data, options: options)
                }
            } catch {
                throw ImageExportError.saveFailed(error.localizedDescription)
            }
            progress?(0.8 + 0.2 * Double(index + 1) / Double(outputs.count))
        }
        viewModel.recordExport(quality: quality)
        return outputs.count
    }
}

/// Readable, unique export names: original name when available, otherwise Image_001…
struct UniqueFileNamer {
    private var used = Set<String>()

    mutating func name(for sourceName: String?, index: Int, fileExtension: String) -> String {
        var base = sourceName.map { ($0 as NSString).deletingPathExtension } ?? ""
        base = base.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = String(format: "Image_%03d", index) }
        var candidate = "\(base).\(fileExtension)"
        var counter = 2
        while used.contains(candidate.lowercased()) {
            candidate = "\(base)_\(counter).\(fileExtension)"
            counter += 1
        }
        used.insert(candidate.lowercased())
        return candidate
    }
}
