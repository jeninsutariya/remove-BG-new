//
//  ImageExportService.swift
//  Background Removal
//
//  Renders final images with the central export-quality policy and saves them to Photos.
//  • Automatic format: no background → PNG with the real alpha channel (never the checkerboard),
//    background applied → JPEG at the quality's compression. The Export screen can force PNG/JPG.
//  • Each item's Shadow / Resize edits are rendered by the same compositor as the preview.
//  • Free users: the ic_watermark asset is drawn once onto each final, fully composed image
//    right before it is encoded (ExportWatermark). Project files are never watermarked.
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
    case watermarkMissing

    var errorDescription: String? {
        switch self {
        case .nothingToExport: return "There are no finished images to export yet."
        case .photosAccessDenied: return "Allow \"Add Photos Only\" access for this app in Settings to save images."
        case .renderFailed(let name): return "\(name) couldn't be rendered."
        case .saveFailed(let reason): return "Saving to Photos failed: \(reason)"
        case .watermarkMissing: return "The watermark image (ic_watermark) is missing from the app."
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
        // Premium state read once when the export is rendered: every image of it is treated alike.
        let watermark = try ExportWatermark.forCurrentUser()
        for (index, item) in ready.enumerated() {
            try Task.checkCancellation()
            guard let foreground = await viewModel.fullForeground(for: item.id) else {
                throw ImageExportError.renderFailed(item.sourceName ?? "Image \(index + 1)")
            }
            let background = try await viewModel.resolveBackground(options.background(for: item))
            let maxDimension = options.maxDimension(for: quality)
            let jpegQuality = options.jpegQuality ?? quality.jpegQuality
            let edits = item.edits
            let asPNG = options.format(for: item) == .png
            let rendered = await Task.detached(priority: .userInitiated) { () -> (Data, Bool)? in
                autoreleasepool { () -> (Data, Bool)? in
                    guard let composed = ImageCompositingService.shared.compose(foreground: foreground, background: background,
                                                                                edits: edits, maxDimension: maxDimension),
                          let cg = ExportWatermark.applying(watermark, to: composed)
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

    /// Saves already-encoded image data to the photo library ("Add Photos Only" access).
    /// Returns only after Photos confirms the save.
    func savePhotoData(_ data: Data, fileName: String) async throws {
        // Never report success for a save that didn't happen.
        guard !isBusy else { throw ImageExportError.saveFailed("Another save is still in progress.") }
        isBusy = true
        defer { isBusy = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw ImageExportError.photosAccessDenied }
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

        let quality = ExportQuality.current
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

/// The free-user watermark: the `ic_watermark` asset, centred near the bottom of a final export
/// image. Sized from the image's own dimensions (aspect ratio and transparency of the asset kept).
nonisolated enum ExportWatermark {

    /// Watermark width as a share of the image width…
    static let widthRatio: CGFloat = 0.2
    /// …but never taller than this share of the image height (wide images).
    static let maxHeightRatio: CGFloat = 0.14
    /// Gap to the bottom edge as a share of the image's shorter side.
    static let bottomPaddingRatio: CGFloat = 0.03

    /// The watermark for the current user, nil for premium users (`UserDefaults.isPremiumUser`).
    /// Call when the export is rendered so a purchase made meanwhile is respected.
    /// Throws when the asset is missing instead of exporting without it.
    @MainActor static func forCurrentUser() throws -> CGImage? {
        guard !UserDefaults.isPremiumUser else { return nil }
        guard let asset = UIImage(named: "ic_watermark") else {
            assertionFailure("Missing ic_watermark asset")
            throw ImageExportError.watermarkMissing
        }
        // The default (light) variant, so exports don't depend on the device's Dark Mode.
        let image = asset.imageAsset?.image(with: UITraitCollection(userInterfaceStyle: .light)) ?? asset
        guard let cgImage = image.cgImage else { throw ImageExportError.watermarkMissing }
        return cgImage
    }

    /// Where the watermark goes in an image of `imageSize` (UIKit coordinates, top-left origin).
    static func frame(watermarkSize: CGSize, in imageSize: CGSize) -> CGRect {
        guard watermarkSize.width > 0, watermarkSize.height > 0 else { return .zero }
        let aspect = watermarkSize.height / watermarkSize.width
        var width = imageSize.width * widthRatio
        var height = width * aspect
        let maxHeight = imageSize.height * maxHeightRatio
        if height > maxHeight {
            height = maxHeight
            width = height / aspect
        }
        let padding = min(imageSize.width, imageSize.height) * bottomPaddingRatio
        return CGRect(x: ((imageSize.width - width) / 2).rounded(), y: (imageSize.height - padding - height).rounded(),
                      width: width.rounded(), height: height.rounded())
    }

    /// `image` with the watermark drawn on top (same size; alpha kept). Returns `image`
    /// unchanged when `watermark` is nil (premium), nil when drawing failed.
    static func applying(_ watermark: CGImage?, to image: CGImage) -> CGImage? {
        guard let watermark else { return image }
        let size = CGSize(width: image.width, height: image.height)
        // The image's own RGB colour space when possible (colours unchanged), otherwise sRGB.
        let spaces = [image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }, CGColorSpace(name: CGColorSpace.sRGB)]
        guard let context = spaces.compactMap({ $0 }).lazy.compactMap({ space in
            CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        }).first else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        // Core Graphics has a bottom-left origin.
        let frame = self.frame(watermarkSize: CGSize(width: watermark.width, height: watermark.height), in: size)
        context.draw(watermark, in: CGRect(x: frame.minX, y: size.height - frame.maxY,
                                           width: frame.width, height: frame.height))
        return context.makeImage()
    }

    /// UIImage version (Text Behind Subject and the Export preview). Drawn with the image's own
    /// renderer format, so scale, colour range and opacity stay as they are; orientation is applied.
    static func applying(_ watermark: CGImage?, to image: UIImage) -> UIImage? {
        guard let watermark else { return image }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let mark = UIImage(cgImage: watermark)
        let frame = self.frame(watermarkSize: mark.size, in: image.size)
        return UIGraphicsImageRenderer(size: image.size, format: image.imageRendererFormat).image { _ in
            image.draw(at: .zero)
            mark.draw(in: frame)
        }
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
