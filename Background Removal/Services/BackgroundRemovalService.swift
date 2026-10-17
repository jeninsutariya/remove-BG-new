//
//  BackgroundRemovalService.swift
//  Background Removal
//
//  Native, on-device background removal with Apple's Vision framework.
//
//  Pipeline
//  1. Normalise orientation and size (upright RGBA, ≤ maxProcessingDimension).
//  2. Validate dimensions / memory.
//  3. iOS 17+: VNGenerateForegroundInstanceMaskRequest → all foreground instances →
//     generateScaledMaskForImage (mask at the processed image's exact size, so it is aligned).
//     iOS 15–16: VNGeneratePersonSegmentationRequest (people only), upsampled with the photo as guide.
//  4. Composite with CIBlendWithMask over a clear image → real alpha channel.
//  5. Return an RGBA UIImage (orientation .up) suitable for PNG export.
//
//  No network, no third-party code. The caller keeps the original image untouched.
//

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated enum BackgroundRemovalError: LocalizedError, Equatable {
    case unsupportedOSVersion
    case invalidImage
    case visionRequestFailed(String)
    case noSubjectFound
    case maskGenerationFailed
    case compositingFailed
    case insufficientMemory
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedOSVersion:
            return "Removing backgrounds from objects and pets needs iOS 17 or later. On this iOS version only people can be detected."
        case .invalidImage:
            return "This image couldn't be read. Please choose another photo."
        case .visionRequestFailed(let reason):
            #if targetEnvironment(simulator)
            return "Apple's Vision segmentation isn't available in the iOS Simulator. Please run the app on an iPhone or iPad. (\(reason))"
            #else
            return "Apple Vision couldn't analyse this photo: \(reason)"
            #endif
        case .noSubjectFound:
            return "No clear subject was found. Try a photo where the person, pet or object stands out from the background."
        case .maskGenerationFailed:
            return "The cutout mask couldn't be created for this photo."
        case .compositingFailed:
            return "The transparent image couldn't be created."
        case .insufficientMemory:
            return "This photo is too large to process right now. Close other apps and try again."
        case .cancelled:
            return "Background removal was cancelled."
        }
    }
}

nonisolated final class BackgroundRemovalService: Sendable {

    static let shared = BackgroundRemovalService()

    /// Longest side the segmentation and the transparent result are produced at (≈16 MP).
    /// The original photo is stored separately and never replaced.
    static let maxProcessingDimension: CGFloat = 4096

    /// True when the full foreground-instance segmentation (people, pets, objects) is available.
    static var supportsForegroundInstanceMask: Bool {
        if #available(iOS 17.0, *) { return true }
        return false
    }

    private var context: CIContext { ImageUtilities.ciContext }

    /// Removes the background and returns an RGBA image with real transparency.
    /// Runs the expensive work on a background thread; honours task cancellation.
    func removeBackground(from image: UIImage) async throws -> UIImage {
        try Task.checkCancellation()
        let task = Task.detached(priority: .userInitiated) { [self] () throws -> UIImage in
            try autoreleasepool { try self.process(image) }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    // MARK: - Pipeline

    private func process(_ image: UIImage) throws -> UIImage {
        // 1–2. Normalise + validate.
        let sourceSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard sourceSize.width >= 16, sourceSize.height >= 16 else { throw BackgroundRemovalError.invalidImage }
        try checkMemory(for: sourceSize)
        guard let upright = ImageUtilities.uprightCGImage(from: image, maxDimension: Self.maxProcessingDimension) else {
            throw BackgroundRemovalError.invalidImage
        }
        if Task.isCancelled { throw BackgroundRemovalError.cancelled }

        // 3. Vision mask, aligned to `upright`.
        let mask: CIImage
        if #available(iOS 17.0, *) {
            mask = try foregroundInstanceMask(for: upright)
        } else {
            mask = try personMask(for: upright)
        }
        if Task.isCancelled { throw BackgroundRemovalError.cancelled }

        // 4. Composite: foreground keeps its pixels, background becomes alpha 0.
        let extent = CGRect(x: 0, y: 0, width: upright.width, height: upright.height)
        let source = CIImage(cgImage: upright)
        let alignedMask = align(mask, to: extent)
        guard coverage(of: alignedMask) > 0.002 else { throw BackgroundRemovalError.noSubjectFound }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = source
        blend.backgroundImage = CIImage(color: .clear).cropped(to: extent)
        blend.maskImage = alignedMask
        guard let output = blend.outputImage?.cropped(to: extent),
              let result = context.createCGImage(output, from: extent, format: .RGBA8, colorSpace: ImageUtilities.sRGB),
              ImageUtilities.hasAlphaChannel(result) else {
            throw BackgroundRemovalError.compositingFailed
        }
        return UIImage(cgImage: result, scale: 1, orientation: .up)
    }

    @available(iOS 17.0, *)
    private func foregroundInstanceMask(for image: CGImage) throws -> CIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw BackgroundRemovalError.visionRequestFailed(error.localizedDescription)
        }
        guard let observation = request.results?.first else { throw BackgroundRemovalError.noSubjectFound }
        // Keep every detected subject (e.g. two people in one photo).
        let instances = observation.allInstances
        guard !instances.isEmpty else { throw BackgroundRemovalError.noSubjectFound }
        do {
            // Soft mask scaled to the exact size of the image given to the handler.
            let buffer = try observation.generateScaledMaskForImage(forInstances: instances, from: handler)
            return CIImage(cvPixelBuffer: buffer)
        } catch {
            throw BackgroundRemovalError.maskGenerationFailed
        }
    }

    /// iOS 15–16 fallback: native Vision person segmentation (people only).
    private func personMask(for image: CGImage) throws -> CIImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw BackgroundRemovalError.visionRequestFailed(error.localizedDescription)
        }
        guard let observation = request.results?.first else { throw BackgroundRemovalError.unsupportedOSVersion }
        let small = CIImage(cvPixelBuffer: observation.pixelBuffer)
        if coverage(of: small) < 0.002 {
            // No person found and no object segmentation on this iOS version.
            throw BackgroundRemovalError.unsupportedOSVersion
        }
        // The person mask is low resolution: upsample it using the photo as an edge guide.
        let guide = CIImage(cgImage: image)
        let upsample = CIFilter.edgePreserveUpsample()
        upsample.inputImage = guide
        upsample.smallImage = small
        upsample.spatialSigma = 3
        upsample.lumaSigma = 0.15
        guard let refined = upsample.outputImage?.cropped(to: guide.extent) else {
            throw BackgroundRemovalError.maskGenerationFailed
        }
        return refined
    }

    // MARK: - Helpers

    /// Scales/translates the mask so it covers exactly `extent` (no stretching of the subject:
    /// Vision masks share the image's aspect ratio, only the resolution may differ).
    private func align(_ mask: CIImage, to extent: CGRect) -> CIImage {
        var aligned = mask.transformed(by: CGAffineTransform(translationX: -mask.extent.minX, y: -mask.extent.minY))
        if aligned.extent.size != extent.size {
            aligned = aligned.transformed(by: CGAffineTransform(scaleX: extent.width / aligned.extent.width,
                                                                y: extent.height / aligned.extent.height))
        }
        return aligned.clampedToExtent().cropped(to: extent)
    }

    /// Mean mask value 0…1, used to detect "nothing found".
    private func coverage(of mask: CIImage) -> Float {
        let filter = CIFilter.areaAverage()
        filter.inputImage = mask
        filter.extent = mask.extent
        guard let output = filter.outputImage else { return 1 }
        var pixel = [Float](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 16,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        return pixel[0]
    }

    /// Rough check so a huge photo fails gracefully instead of being killed by the OS.
    private func checkMemory(for size: CGSize) throws {
        let scale = min(1, Self.maxProcessingDimension / max(size.width, size.height))
        let pixels = Double(size.width * scale) * Double(size.height * scale)
        // Source + upright copy + mask + result, 4 bytes each, plus Core Image working buffers.
        let estimate = pixels * 4 * 6
        let budget = Double(ProcessInfo.processInfo.physicalMemory) * 0.35
        if estimate > budget { throw BackgroundRemovalError.insufficientMemory }
    }
}
