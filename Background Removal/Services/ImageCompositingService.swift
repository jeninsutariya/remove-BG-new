//
//  ImageCompositingService.swift
//  Background Removal
//
//  Renders a background behind a transparent foreground. The same function is used for the
//  on-screen preview (smaller `maxDimension`) and for exports, so they always match.
//
//  Rules
//  • The canvas is the foreground's size grown to the Resize aspect ratio (scaled by
//    `maxDimension`, never upscaled), so the subject is never cropped.
//  • Shadow and subject size come from `ItemEdits`.
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

    /// Canvas size before any size limit: the foreground grown to the chosen aspect ratio
    /// (the subject is never cropped).
    func canvasPixelSize(for foreground: CGSize, aspect: CanvasAspect) -> CGSize {
        guard let ratio = aspect.ratio.map({ CGFloat($0) }) else { return foreground }
        let imageRatio = foreground.width / max(foreground.height, 1)
        if ratio > imageRatio {
            return CGSize(width: (foreground.height * ratio).rounded(), height: foreground.height)
        }
        return CGSize(width: foreground.width, height: (foreground.width / ratio).rounded())
    }

    /// Pixel size of the composed output for a foreground, its edits and an optional size limit.
    func outputSize(for foreground: CGSize, edits: ItemEdits = .unedited, maxDimension: CGFloat?) -> CGSize {
        let canvas = canvasPixelSize(for: foreground, aspect: edits.aspect)
        let longest = max(canvas.width, canvas.height)
        guard let maxDimension, longest > maxDimension else { return canvas }
        let scale = maxDimension / longest
        return CGSize(width: max(1, (canvas.width * scale).rounded()), height: max(1, (canvas.height * scale).rounded()))
    }

    /// Composes `background` behind `foreground` with the Shadow / Resize edits.
    /// Returns a CGImage with alpha when the background is `.none`, otherwise an opaque image.
    func compose(foreground: UIImage, background: ResolvedBackground, edits: ItemEdits = .unedited,
                 maxDimension: CGFloat? = nil) -> CGImage? {
        guard let fg = ImageUtilities.uprightCGImage(from: foreground) else { return nil }
        let fgSize = CGSize(width: fg.width, height: fg.height)
        let fullCanvas = canvasPixelSize(for: fgSize, aspect: edits.aspect)
        let size = outputSize(for: fgSize, edits: edits, maxDimension: maxDimension)
        let scale = size.width / max(fullCanvas.width, 1)
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

        // Subject: centred horizontally; when shrunk it keeps resting on the photo's bottom edge.
        let subjectScale = CGFloat(min(1, max(0.5, edits.subjectScale)))
        let photoHeight = fgSize.height * scale
        let subject = CGSize(width: fgSize.width * scale * subjectScale, height: photoHeight * subjectScale)
        let photoBottomFromTop = (size.height + photoHeight) / 2
        // Core Graphics has a bottom-left origin.
        let subjectRect = CGRect(x: (size.width - subject.width) / 2, y: size.height - photoBottomFromTop,
                                 width: subject.width, height: subject.height)

        ctx.saveGState()
        if edits.shadow.isOn {
            let unit = max(size.width, size.height) / 400
            let offset = CGFloat(edits.shadow.distance) * unit * 0.6
            let blur = CGFloat(edits.shadow.softness) * unit * 0.5
            ctx.setShadow(offset: CGSize(width: 0, height: -offset), blur: blur,
                          color: UIColor.black.withAlphaComponent(CGFloat(edits.shadow.opacity) / 100).cgColor)
        }
        ctx.draw(fg, in: subjectRect)
        ctx.restoreGState()
        return ctx.makeImage()
    }

    /// Convenience returning a UIImage (orientation .up, scale 1).
    func composeImage(foreground: UIImage, background: ResolvedBackground, edits: ItemEdits = .unedited,
                      maxDimension: CGFloat? = nil) -> UIImage? {
        compose(foreground: foreground, background: background, edits: edits, maxDimension: maxDimension).map {
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
