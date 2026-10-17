//
//  BGRemovalEngine.swift
//  Background Removal
//
//  On-device background removal with Apple's Vision framework.
//  • iOS 17+: VNGenerateForegroundInstanceMaskRequest (people, pets, objects)
//  • iOS 15/16 (or fallback): VNGeneratePersonSegmentationRequest (people)
//

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated enum BGRemovalError: LocalizedError {
    case noSubject
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .noSubject:
            return "We couldn't find a clear subject in this photo. Try a photo with a person, pet or object in focus."
        case .unavailable(let reason):
            return "Background removal isn't available: \(reason)"
        }
    }
}

/// Runs off the main thread (the target uses MainActor as its default isolation).
nonisolated enum BGRemovalEngine {

    nonisolated(unsafe) static let context = CIContext(options: [.cacheIntermediates: false])

    /// Longest side used while editing – sharp exports, fast processing.
    static let workingMaxDimension: CGFloat = 2048

    // MARK: - Public

    /// Soft 8-bit grayscale matte (white = keep) with the exact pixel size of `image`.
    static func makeMask(for image: CGImage) throws -> CGImage {
        let size = CGSize(width: image.width, height: image.height)
        var matte: CIImage?
        var lastError: Error?

        if #available(iOS 17.0, *) {
            do { matte = try foregroundMask(for: image) } catch { lastError = error }
        }
        if matte == nil {
            do { matte = try personMask(for: image) } catch { lastError = lastError ?? error }
        }
        guard var result = matte else {
            if let removalError = lastError as? BGRemovalError { throw removalError }
            #if targetEnvironment(simulator)
            throw BGRemovalError.unavailable("the iOS Simulator can't run Apple's segmentation models. Please run on a real iPhone.")
            #else
            throw BGRemovalError.unavailable(lastError?.localizedDescription ?? "unknown error")
            #endif
        }

        if result.extent.size != size {
            result = result
                .transformed(by: CGAffineTransform(translationX: -result.extent.minX, y: -result.extent.minY))
                .transformed(by: CGAffineTransform(scaleX: size.width / result.extent.width,
                                                   y: size.height / result.extent.height))
        }
        result = result.clampedToExtent().cropped(to: CGRect(origin: .zero, size: size))

        guard coverage(of: result) > 0.002 else { throw BGRemovalError.noSubject }
        guard let gray = context.createCGImage(result, from: CGRect(origin: .zero, size: size),
                                               format: .L8, colorSpace: CGColorSpaceCreateDeviceGray()) else {
            throw BGRemovalError.unavailable("the mask could not be rendered")
        }
        return gray
    }

    /// Original photo with the matte applied as alpha (soft edges keep partial transparency).
    static func cutout(original: CGImage, mask: CGImage) -> CGImage? {
        let source = CIImage(cgImage: original)
        var matte = CIImage(cgImage: mask)
        if matte.extent.size != source.extent.size {
            matte = matte.transformed(by: CGAffineTransform(scaleX: source.extent.width / matte.extent.width,
                                                            y: source.extent.height / matte.extent.height))
        }
        let output = source.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: matte
        ])
        return context.createCGImage(output, from: source.extent, format: .RGBA8,
                                     colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    }

    /// Redraws a photo upright (orientation .up), scale 1, capped to `maxDimension` pixels.
    @MainActor
    static func normalized(_ image: UIImage, maxDimension: CGFloat = workingMaxDimension) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let ratio = min(1, maxDimension / max(pixelSize.width, pixelSize.height, 1))
        let target = CGSize(width: max(1, (pixelSize.width * ratio).rounded()),
                            height: max(1, (pixelSize.height * ratio).rounded()))
        if ratio == 1, image.imageOrientation == .up, image.scale == 1, image.cgImage != nil { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    // MARK: - Vision

    @available(iOS 17.0, *)
    private static func foregroundMask(for image: CGImage) throws -> CIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw BGRemovalError.noSubject
        }
        let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        return CIImage(cvPixelBuffer: buffer)
    }

    private static func personMask(for image: CGImage) throws -> CIImage {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first else { throw BGRemovalError.noSubject }
        let small = CIImage(cvPixelBuffer: observation.pixelBuffer)
        let guide = CIImage(cgImage: image)
        // Upscale the low-resolution person matte using the photo as an edge guide.
        let upsample = CIFilter.edgePreserveUpsample()
        upsample.inputImage = guide
        upsample.smallImage = small
        upsample.spatialSigma = 3
        upsample.lumaSigma = 0.15
        if let refined = upsample.outputImage?.cropped(to: guide.extent) {
            return refined
        }
        return small.transformed(by: CGAffineTransform(scaleX: guide.extent.width / small.extent.width,
                                                       y: guide.extent.height / small.extent.height))
    }

    private static func coverage(of matte: CIImage) -> Float {
        let filter = CIFilter.areaAverage()
        filter.inputImage = matte
        filter.extent = matte.extent
        guard let output = filter.outputImage else { return 1 }
        var pixel = [Float](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 16,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBAf, colorSpace: nil)
        return pixel[0]
    }
}

/// 8-bit matte bytes (row 0 = top), convertible to a grayscale CGImage.
nonisolated struct MaskBuffer {
    let width: Int
    let height: Int
    var bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init?(gray image: CGImage) {
        let w = image.width
        let h = image.height
        var data = [UInt8](repeating: 0, count: w * h)
        let ok: Bool = data.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        self.init(width: w, height: h, bytes: data)
    }

    func grayImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
