//
//  MaskBrushCanvas.swift
//  Background Removal
//
//  Editable matte for Refine Edges. Stored as premultiplied white RGBA whose alpha
//  is the matte, so its image can be used directly as a CALayer mask.
//

import UIKit
import Accelerate

final class MaskBrushCanvas {
    let width: Int
    let height: Int
    private let context: CGContext

    init?(mask: CGImage) {
        width = mask.width
        height = mask.height
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context = ctx
        context.interpolationQuality = .high
        guard load(mask) else { return nil }
    }

    /// Empty (fully transparent) canvas, used to record where the user painted.
    init?(width: Int, height: Int) {
        self.width = width
        self.height = height
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context = ctx
        context.interpolationQuality = .high
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    }

    /// Replaces the bitmap with a grayscale matte (initial state, undo, redo).
    @discardableResult
    func load(_ gray: CGImage) -> Bool {
        guard var buffer = MaskBuffer(gray: gray, width: width, height: height),
              let data = context.data else { return false }
        let w = vImagePixelCount(width), h = vImagePixelCount(height)
        let rowBytes = width, destRowBytes = context.bytesPerRow
        let error: vImage_Error = buffer.bytes.withUnsafeMutableBytes { raw in
            var r = vImage_Buffer(data: raw.baseAddress, height: h, width: w, rowBytes: rowBytes)
            var g = r, b = r, a = r
            var dest = vImage_Buffer(data: data, height: h, width: w, rowBytes: destRowBytes)
            return vImageConvert_Planar8toARGB8888(&r, &g, &b, &a, &dest, vImage_Flags(kvImageNoFlags))
        }
        return error == kvImageNoError
    }

    /// Image for `CALayer.mask` contents.
    func maskImage() -> CGImage? { context.makeImage() }

    /// Grayscale matte handed back to the editor.
    func grayImage() -> CGImage? {
        guard let data = context.data else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height)
        let w = vImagePixelCount(width), h = vImagePixelCount(height)
        let srcRowBytes = context.bytesPerRow, dstRowBytes = width
        let error: vImage_Error = bytes.withUnsafeMutableBytes { raw in
            var src = vImage_Buffer(data: data, height: h, width: w, rowBytes: srcRowBytes)
            var dst = vImage_Buffer(data: raw.baseAddress, height: h, width: w, rowBytes: dstRowBytes)
            return vImageExtractChannel_ARGB8888(&src, &dst, 3, vImage_Flags(kvImageNoFlags))
        }
        guard error == kvImageNoError else { return nil }
        return MaskBuffer(width: width, height: height, bytes: bytes).grayImage()
    }

    /// Stamps a soft round brush along a segment. Points are image pixels, top-left origin.
    func stroke(from a: CGPoint, to b: CGPoint, radius: CGFloat, stamp: CGImage, erase: Bool) {
        let distance = hypot(b.x - a.x, b.y - a.y)
        let spacing = max(1, radius * 0.2)
        let steps = max(1, Int(ceil(distance / spacing)))
        context.saveGState()
        context.setBlendMode(erase ? .destinationOut : .normal)
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            let rect = CGRect(x: p.x - radius, y: CGFloat(height) - p.y - radius, width: radius * 2, height: radius * 2)
            context.draw(stamp, in: rect)
        }
        context.restoreGState()
    }

    /// Radial brush tip: solid core, soft falloff controlled by `softness` (0…1).
    static func makeStamp(softness: CGFloat) -> CGImage? {
        let size = 128
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let hard = max(0, min(0.98, 1 - softness))
        let colors = [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                        locations: [0, hard, 1]) else { return nil }
        let c = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(size) / 2, options: [])
        return ctx.makeImage()
    }
}
