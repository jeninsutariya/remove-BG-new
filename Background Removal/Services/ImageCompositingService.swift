//
//  ImageCompositingService.swift
//  Background Removal
//
//  Renders a background behind a transparent foreground. The same function is used for the
//  on-screen preview (smaller `maxDimension`) and for exports, so they always match.
//
//  Rules
//  • The canvas is the foreground's size (scaled by `maxDimension`, never upscaled), so the
//    subject is never cropped.
//  • No background → transparent RGBA result.
//  • Colour → solid fill behind the subject.
//  • Image → aspect-fill, centre-cropped to the canvas, behind the subject.
//  • The foreground's alpha is never modified.
//

import UIKit
import CoreImage

/// A background ready to draw (already downloaded / loaded from disk).
nonisolated enum ResolvedBackground {
    case none
    case color(UIColor)
    case image(UIImage)

    var isOpaque: Bool {
        if case .none = self { return false }
        return true
    }
}

nonisolated final class ImageCompositingService: Sendable {

    static let shared = ImageCompositingService()

    /// Pixel size of the composed output for a foreground and an optional size limit.
    func outputSize(for foreground: CGSize, maxDimension: CGFloat?) -> CGSize {
        let longest = max(foreground.width, foreground.height)
        guard let maxDimension, longest > maxDimension else { return foreground }
        let scale = maxDimension / longest
        return CGSize(width: max(1, (foreground.width * scale).rounded()), height: max(1, (foreground.height * scale).rounded()))
    }

    /// Composes `background` behind `foreground`. Returns a CGImage with alpha when the background
    /// is `.none`, otherwise an opaque image.
    func compose(foreground: UIImage, background: ResolvedBackground, maxDimension: CGFloat? = nil) -> CGImage? {
        guard let fg = ImageUtilities.uprightCGImage(from: foreground) else { return nil }
        let size = outputSize(for: CGSize(width: fg.width, height: fg.height), maxDimension: maxDimension)
        let width = Int(size.width), height = Int(size.height)
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: ImageUtilities.sRGB,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)

        switch background {
        case .none:
            ctx.clear(canvas)
        case .color(let color):
            ctx.setFillColor(color.cgColor)
            ctx.fill(canvas)
        case .image(let image):
            guard let bg = ImageUtilities.uprightCGImage(from: image) else { return nil }
            ctx.draw(bg, in: aspectFillRect(for: CGSize(width: bg.width, height: bg.height), in: canvas))
        }
        ctx.draw(fg, in: canvas)
        return ctx.makeImage()
    }

    /// Convenience returning a UIImage (orientation .up, scale 1).
    func composeImage(foreground: UIImage, background: ResolvedBackground, maxDimension: CGFloat? = nil) -> UIImage? {
        compose(foreground: foreground, background: background, maxDimension: maxDimension).map {
            UIImage(cgImage: $0, scale: 1, orientation: .up)
        }
    }

    /// Centre-crop policy used for every image background.
    private func aspectFillRect(for imageSize: CGSize, in canvas: CGRect) -> CGRect {
        let scale = max(canvas.width / imageSize.width, canvas.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2, width: size.width, height: size.height)
    }
}

nonisolated extension UIColor {
    /// `RRGGBB` (sRGB) – used to persist colour selections.
    var hexRGB: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((max(0, min(1, v)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", c(r), c(g), c(b))
    }

    convenience init?(hexRGB: String) {
        var value = hexRGB.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let hex = UInt32(value, radix: 16) else { return nil }
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
