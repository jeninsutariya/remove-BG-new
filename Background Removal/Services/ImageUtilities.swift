//
//  ImageUtilities.swift
//  Background Removal
//
//  Thread-safe image helpers (ImageIO / Core Image / Core Graphics only).
//

import UIKit
import ImageIO
import CoreImage
import UniformTypeIdentifiers

nonisolated enum ImageUtilities {

    /// Shared Core Image context (thread-safe).
    nonisolated(unsafe) static let ciContext = CIContext(options: [.cacheIntermediates: false])

    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    // MARK: - Orientation / size

    static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// Upright 8-bit RGBA sRGB copy of `image` (orientation applied), optionally scaled down so the
    /// longest side is at most `maxDimension`. Never upscales.
    static func uprightCGImage(from image: UIImage, maxDimension: CGFloat? = nil) -> CGImage? {
        var ciImage: CIImage
        if let cg = image.cgImage {
            ciImage = CIImage(cgImage: cg)
        } else if let ci = image.ciImage {
            ciImage = ci
        } else {
            return nil
        }
        ciImage = ciImage.oriented(cgOrientation(image.imageOrientation))
        ciImage = ciImage.transformed(by: CGAffineTransform(translationX: -ciImage.extent.minX, y: -ciImage.extent.minY))

        let longest = max(ciImage.extent.width, ciImage.extent.height)
        if let maxDimension, longest > maxDimension {
            let scale = maxDimension / longest
            let filter = CIFilter(name: "CILanczosScaleTransform")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            filter?.setValue(scale, forKey: kCIInputScaleKey)
            filter?.setValue(1.0, forKey: kCIInputAspectRatioKey)
            if let output = filter?.outputImage { ciImage = output }
        }
        let rect = CGRect(x: 0, y: 0, width: ciImage.extent.width.rounded(.down), height: ciImage.extent.height.rounded(.down))
        guard rect.width >= 1, rect.height >= 1 else { return nil }
        return ciContext.createCGImage(ciImage, from: rect, format: .RGBA8, colorSpace: sRGB)
    }

    /// Decodes an image file without loading the full-size bitmap: the result is upright and its
    /// longest side is at most `maxPixel`.
    static func downsampledImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        return downsampledImage(from: source, maxPixel: maxPixel)
    }

    static func downsampledImage(from data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        return downsampledImage(from: source, maxPixel: maxPixel)
    }

    private static func downsampledImage(from source: CGImageSource, maxPixel: CGFloat) -> UIImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixel))
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    /// Pixel size of an image file without decoding it (orientation applied).
    static func pixelSize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        let orientation = props[kCGImagePropertyOrientation] as? UInt32 ?? 1
        return orientation >= 5 ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
    }

    // MARK: - Encoding

    /// PNG (keeps the alpha channel).
    static func pngData(_ image: CGImage) -> Data? {
        encode(image, type: UTType.png, properties: [:])
    }

    /// JPEG for opaque images.
    static func jpegData(_ image: CGImage, quality: CGFloat) -> Data? {
        encode(image, type: UTType.jpeg, properties: [kCGImageDestinationLossyCompressionQuality: quality])
    }

    private static func encode(_ image: CGImage, type: UTType, properties: [CFString: Any]) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Alpha

    /// True when the image has an alpha channel (it may still be fully opaque).
    static func hasAlphaChannel(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }

    /// Small thumbnail (Core Graphics, thread-safe).
    static func thumbnail(of image: CGImage, maxPixel: CGFloat) -> CGImage? {
        let longest = CGFloat(max(image.width, image.height))
        let scale = min(1, maxPixel / max(longest, 1))
        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
