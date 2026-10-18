//
//  MaskRefineService.swift
//  Background Removal
//
//  Helpers for Refine Edges: read the matte (alpha) of a saved foreground, and rebuild the
//  foreground from the original photo and an edited matte. Runs off the main thread.
//

import UIKit
import CoreImage

/// 8-bit single-channel matte.
nonisolated struct MaskBuffer {
    let width: Int
    let height: Int
    var bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    /// Draws any image into an 8-bit gray buffer, at the image's own size or resized.
    init?(gray image: CGImage, width: Int? = nil, height: Int? = nil) {
        let w = width ?? image.width
        let h = height ?? image.height
        guard w > 0, h > 0 else { return nil }
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

nonisolated enum MaskRefineService {

    /// The alpha channel of `foreground` as a gray matte, resized to `size` when given.
    static func alphaMask(of foreground: CGImage, size: CGSize? = nil) -> CGImage? {
        let w = Int(size?.width ?? CGFloat(foreground.width))
        let h = Int(size?.height ?? CGFloat(foreground.height))
        // Draw into RGBA and keep the alpha byte of every pixel.
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let ok: Bool = rgba.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: ImageUtilities.sRGB,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(foreground, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        var alpha = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) { alpha[i] = rgba[i * 4 + 3] }
        return MaskBuffer(width: w, height: h, bytes: alpha).grayImage()
    }

    /// `mask` resized to `width` × `height` (8-bit gray).
    static func resized(_ mask: CGImage, width: Int, height: Int) -> CGImage? {
        if mask.width == width, mask.height == height, mask.bitsPerPixel == 8 { return mask }
        return MaskBuffer(gray: mask, width: width, height: height)?.grayImage()
    }

    /// Puts the Refine edits back into the full-resolution matte. `edited` and `coverage` are
    /// the smaller working copies; only painted pixels (coverage) take the edited value, so
    /// untouched edges keep their full-resolution detail.
    static func mergeEdits(full: CGImage, edited: CGImage, coverage: CGImage) -> CGImage? {
        let w = full.width, h = full.height
        guard let base = MaskBuffer(gray: full),
              let paint = MaskBuffer(gray: edited, width: w, height: h),
              let cover = MaskBuffer(gray: coverage, width: w, height: h) else { return nil }
        var out = base.bytes
        out.withUnsafeMutableBufferPointer { o in
            paint.bytes.withUnsafeBufferPointer { p in
                cover.bytes.withUnsafeBufferPointer { c in
                    for i in 0..<(w * h) {
                        let k = Int(c[i])
                        guard k > 0 else { continue }
                        o[i] = UInt8((Int(o[i]) * (255 - k) + Int(p[i]) * k + 127) / 255)
                    }
                }
            }
        }
        return MaskBuffer(width: w, height: h, bytes: out).grayImage()
    }

    /// Original photo with `mask` as its alpha channel (RGBA8, sRGB).
    static func cutout(original: CGImage, mask: CGImage) -> CGImage? {
        let source = CIImage(cgImage: original)
        // No colour management: the matte values are alpha, not gamma-encoded gray.
        var matte = CIImage(cgImage: mask, options: [.colorSpace: NSNull()])
        if matte.extent.size != source.extent.size {
            matte = matte.transformed(by: CGAffineTransform(scaleX: source.extent.width / matte.extent.width,
                                                            y: source.extent.height / matte.extent.height))
        }
        let output = source.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: matte
        ])
        return ImageUtilities.ciContext.createCGImage(output, from: source.extent, format: .RGBA8,
                                                     colorSpace: ImageUtilities.sRGB)
    }
}
