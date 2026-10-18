//
//  TextBehindSubjectRenderer.swift
//  Background Removal
//
//  Composes a Text Behind Subject image. Used for the live preview (smaller size) and the
//  export (selected canvas size), so both always match.
//
//  Layer order: 1 background → 2 texts behind the subject → 3 subject cutout (original photo
//  through the Vision mask, optional shadow) → 4 texts in front. The original photo itself
//  is never modified; the subject is a separate transparent cutout of it.
//

import UIKit

/// Images the renderer needs, at the resolution being rendered.
nonisolated struct TBRenderSources {
    /// Unchanged original photo (upright).
    let original: UIImage
    /// Subject extracted from the original (same size, transparent background). nil while loading.
    let cutout: UIImage?
    /// Decorative background image, when the background is an image.
    let backgroundImage: UIImage?
    /// Subject mask (white = subject), only for the mask preview.
    let mask: UIImage?
}

nonisolated enum TextBehindGeometry {

    /// Canvas size in pixels before any size limit.
    static func canvasPixelSize(photo: CGSize, canvas: CanvasSpec) -> CGSize {
        switch canvas.preset {
        case .original:
            return photo
        case .custom:
            return CGSize(width: CGFloat(min(max(canvas.customWidth, 64), 6000)),
                          height: CGFloat(min(max(canvas.customHeight, 64), 6000)))
        default:
            guard let ratio = canvas.preset.ratio.map({ CGFloat($0) }) else { return photo }
            // Grow the photo's canvas to the ratio (never crops the subject at zoom 1, Fit).
            let photoRatio = photo.width / max(photo.height, 1)
            if ratio > photoRatio {
                return CGSize(width: (photo.height * ratio).rounded(), height: photo.height)
            }
            return CGSize(width: photo.width, height: (photo.width / ratio).rounded())
        }
    }

    /// Output size with an optional long-side limit (never upscaled beyond the canvas).
    static func outputSize(photo: CGSize, canvas: CanvasSpec, maxDimension: CGFloat?) -> CGSize {
        let size = canvasPixelSize(photo: photo, canvas: canvas)
        let longest = max(size.width, size.height)
        guard let maxDimension, longest > maxDimension else { return size }
        let scale = maxDimension / longest
        return CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
    }

    /// Where the photo (and the subject on top of it) sits inside a canvas of `canvasSize`.
    static func photoRect(canvasSize: CGSize, photo: CGSize, canvas: CanvasSpec) -> CGRect {
        guard photo.width > 0, photo.height > 0 else { return CGRect(origin: .zero, size: canvasSize) }
        let fit = min(canvasSize.width / photo.width, canvasSize.height / photo.height)
        let fill = max(canvasSize.width / photo.width, canvasSize.height / photo.height)
        let scale = (canvas.contentMode == .fit ? fit : fill) * CGFloat(min(max(canvas.contentZoom, 0.5), 4))
        let size = CGSize(width: photo.width * scale, height: photo.height * scale)
        let shiftX = abs(size.width - canvasSize.width) / 2
        let shiftY = abs(size.height - canvasSize.height) / 2
        return CGRect(x: (canvasSize.width - size.width) / 2 + CGFloat(canvas.contentOffsetX) * shiftX,
                      y: (canvasSize.height - size.height) / 2 + CGFloat(canvas.contentOffsetY) * shiftY,
                      width: size.width, height: size.height)
    }
}

nonisolated enum TextBehindSubjectRenderer {

    /// Renders the composition at `size` (pixels, scale 1).
    /// - Parameters:
    ///   - opaque: true for JPEG – transparent areas become white.
    ///   - maskPreview: shows the subject mask (white = subject) instead of the photo layers.
    ///   - hiddenTextID: a text layer to leave out (while it is being typed in the editor).
    static func render(_ document: TextBehindDocument, sources: TBRenderSources, size: CGSize,
                       opaque: Bool = false, maskPreview: Bool = false, hiddenTextID: UUID? = nil) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        let canvas = CGRect(origin: .zero, size: size)
        let photoSize = sources.original.size
        let photoRect = TextBehindGeometry.photoRect(canvasSize: size, photo: photoSize, canvas: document.canvas)
        let texts = document.texts.filter { $0.id != hiddenTextID }

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext
            ctx.interpolationQuality = .high
            if opaque {
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(canvas)
            }

            if maskPreview {
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(canvas)
                sources.mask?.draw(in: photoRect)
                return
            }

            // 1. Background
            BackgroundRenderingService.draw(document.background, canvas: canvas, photoRect: photoRect,
                                            original: sources.original, backgroundImage: sources.backgroundImage,
                                            context: ctx)
            // 2. Text behind the subject
            for text in texts where text.isBehindSubject {
                TextRenderingService.draw(text, in: ctx, canvasSize: size)
            }
            // 3. Subject cutout over the text
            if document.subjectVisible, let cutout = sources.cutout {
                ctx.saveGState()
                let shadow = document.subjectShadow
                if shadow.isOn {
                    let k = size.width / 1000
                    ctx.setShadow(offset: CGSize(width: shadow.offsetX * k, height: shadow.offsetY * k),
                                  blur: CGFloat(shadow.blur) * k,
                                  color: (UIColor(hexRGB: shadow.hex) ?? .black)
                                    .withAlphaComponent(CGFloat(shadow.opacity)).cgColor)
                }
                cutout.draw(in: photoRect)
                ctx.restoreGState()
            }
            // 4. Text in front of the subject
            for text in texts where !text.isBehindSubject {
                TextRenderingService.draw(text, in: ctx, canvasSize: size)
            }
        }
    }

    /// Encoded export data.
    static func encode(_ image: UIImage, format: ExportFormat, jpegQuality: CGFloat) -> Data? {
        guard let cg = image.cgImage else { return nil }
        switch format {
        case .png: return ImageUtilities.pngData(cg)
        case .jpg: return ImageUtilities.jpegData(cg, quality: jpegQuality)
        }
    }
}
