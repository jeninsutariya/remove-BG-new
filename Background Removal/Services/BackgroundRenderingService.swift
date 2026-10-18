//
//  BackgroundRenderingService.swift
//  Background Removal
//
//  Draws the Text Behind background: the original photo, nothing (transparent), a solid
//  colour, a linear gradient or a decorative image with Fit / Fill / Crop placement.
//  Background images are only drawn – background removal never runs on them.
//

import UIKit

nonisolated enum BackgroundRenderingService {

    /// Linear gradient across `rect` at the spec's angle (UIKit coordinates).
    static func drawLinearGradient(_ spec: GradientSpec, in rect: CGRect, context ctx: CGContext) {
        let colors = spec.colors.map(\.cgColor) as CFArray
        var locations = spec.stops.map { CGFloat($0.location) }
        guard spec.stops.count >= 2,
              let gradient = CGGradient(colorsSpace: ImageUtilities.sRGB, colors: colors, locations: &locations) else {
            ctx.setFillColor((spec.colors.first ?? .white).cgColor)
            ctx.fill(rect)
            return
        }
        let angle = CGFloat(spec.angle) * .pi / 180
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let half = (abs(rect.width * direction.x) + abs(rect.height * direction.y)) / 2
        let start = CGPoint(x: rect.midX - direction.x * half, y: rect.midY - direction.y * half)
        let end = CGPoint(x: rect.midX + direction.x * half, y: rect.midY + direction.y * half)
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.drawLinearGradient(gradient, start: start, end: end,
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    /// Rect for a background image of `imageSize` on a canvas.
    static func imageRect(imageSize: CGSize, canvas: CGRect, placement: ImagePlacement) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return canvas }
        let fit = min(canvas.width / imageSize.width, canvas.height / imageSize.height)
        let fill = max(canvas.width / imageSize.width, canvas.height / imageSize.height)
        var scale: CGFloat
        switch placement.mode {
        case .fit: scale = fit
        case .fill: scale = fill
        case .crop: scale = fill * CGFloat(min(max(placement.zoom, 1), 4))
        }
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        var origin = CGPoint(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2)
        if placement.mode == .crop {
            origin.x += CGFloat(placement.offsetX) * max(0, (size.width - canvas.width) / 2)
            origin.y += CGFloat(placement.offsetY) * max(0, (size.height - canvas.height) / 2)
        }
        return CGRect(origin: origin, size: size)
    }

    /// Draws the background into a UIKit-oriented context (the current UIKit context).
    static func draw(_ background: TBBackground, canvas: CGRect, photoRect: CGRect,
                     original: UIImage?, backgroundImage: UIImage?, context ctx: CGContext) {
        switch background {
        case .original:
            original?.draw(in: photoRect)
        case .transparent:
            break
        case .color(let hex):
            ctx.setFillColor((UIColor(hexRGB: hex) ?? .white).cgColor)
            ctx.fill(canvas)
        case .gradient(let spec):
            drawLinearGradient(spec, in: canvas, context: ctx)
        case .image(_, let placement):
            guard let backgroundImage else { return }
            ctx.saveGState()
            ctx.clip(to: canvas)
            backgroundImage.draw(in: imageRect(imageSize: backgroundImage.size, canvas: canvas, placement: placement))
            ctx.restoreGState()
        }
    }
}
