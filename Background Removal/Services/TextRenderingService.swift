//
//  TextRenderingService.swift
//  Background Removal
//
//  Lays out and draws one TextLayerModel: font face + bold/italic traits, alignment,
//  capitalization, letter/line spacing, underline/strikethrough, solid or gradient fill
//  (clipped to the glyphs), outline, highlight box, opacity, blend mode and shadow.
//  Sizes are relative to the canvas width, so text stays sharp at any output size.
//

import UIKit

/// Where a text layer sits on a canvas of a given size.
nonisolated struct TextLayout {
    /// Centre in canvas points.
    let center: CGPoint
    /// Unrotated size of the text block.
    let size: CGSize
    /// Radians, clockwise.
    let rotation: CGFloat
    let pointSize: CGFloat

    /// Text block corners (for selection handles), clockwise from top-left.
    var corners: [CGPoint] {
        let w = size.width / 2, h = size.height / 2
        return [CGPoint(x: -w, y: -h), CGPoint(x: w, y: -h), CGPoint(x: w, y: h), CGPoint(x: -w, y: h)].map {
            CGPoint(x: center.x + $0.x * cos(rotation) - $0.y * sin(rotation),
                    y: center.y + $0.x * sin(rotation) + $0.y * cos(rotation))
        }
    }

    /// True when `point` (canvas points) is inside the rotated block, with some slack.
    func contains(_ point: CGPoint, slack: CGFloat = 12) -> Bool {
        let dx = point.x - center.x, dy = point.y - center.y
        let x = dx * cos(-rotation) - dy * sin(-rotation)
        let y = dx * sin(-rotation) + dy * cos(-rotation)
        return abs(x) <= size.width / 2 + slack && abs(y) <= size.height / 2 + slack
    }
}

nonisolated enum TextRenderingService {

    static func pointSize(for layer: TextLayerModel, canvasWidth: CGFloat) -> CGFloat {
        max(1, CGFloat(layer.fontScale) * canvasWidth / 1000)
    }

    /// The layer's font face with optional bold / italic traits (kept as-is when the family
    /// has no such face).
    static func font(for layer: TextLayerModel, size: CGFloat) -> UIFont {
        let base = UIFont(name: layer.fontName, size: size) ?? .systemFont(ofSize: size, weight: .heavy)
        var traits = base.fontDescriptor.symbolicTraits
        if layer.bold { traits.insert(.traitBold) }
        if layer.italic { traits.insert(.traitItalic) }
        guard traits != base.fontDescriptor.symbolicTraits,
              let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func attributedString(for layer: TextLayerModel, pointSize: CGFloat, color: UIColor,
                                 strokeColor: UIColor? = nil, strokeWidth: CGFloat = 0) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = layer.alignment.nsAlignment
        paragraph.lineHeightMultiple = CGFloat(max(0.5, layer.lineSpacing))
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(for: layer, size: pointSize),
            .kern: CGFloat(layer.letterSpacing) * pointSize,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        if layer.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if layer.strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let strokeColor, strokeWidth > 0 {
            // Positive stroke width (percent of the font size) = outline only.
            attributes[.strokeColor] = strokeColor
            attributes[.strokeWidth] = strokeWidth / pointSize * 100
        }
        let text = layer.displayText.isEmpty ? " " : layer.displayText
        return NSAttributedString(string: text, attributes: attributes)
    }

    static func layout(for layer: TextLayerModel, canvasSize: CGSize) -> TextLayout {
        let size = pointSize(for: layer, canvasWidth: canvasSize.width)
        let string = attributedString(for: layer, pointSize: size, color: .white)
        let maxWidth = max(CGFloat(layer.widthFraction) * canvasSize.width, size)
        let bounds = string.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return TextLayout(center: CGPoint(x: CGFloat(layer.centerX) * canvasSize.width,
                                          y: CGFloat(layer.centerY) * canvasSize.height),
                          size: CGSize(width: ceil(bounds.width), height: ceil(bounds.height)),
                          rotation: CGFloat(layer.rotation) * .pi / 180,
                          pointSize: size)
    }

    /// Draws the layer into a UIKit-oriented context (top-left origin), e.g. from
    /// UIGraphicsImageRenderer. The context must be the current UIKit context.
    static func draw(_ layer: TextLayerModel, in ctx: CGContext, canvasSize: CGSize) {
        guard !layer.isHidden, !layer.displayText.isEmpty, layer.opacity > 0 else { return }
        let layout = layout(for: layer, canvasSize: canvasSize)
        let k = canvasSize.width / 1000
        let rect = CGRect(x: -layout.size.width / 2, y: -layout.size.height / 2,
                          width: layout.size.width, height: layout.size.height)

        ctx.saveGState()
        ctx.translateBy(x: layout.center.x, y: layout.center.y)
        ctx.rotate(by: layout.rotation)
        // Opacity, blend mode and shadow apply once to the whole text layer.
        ctx.setAlpha(CGFloat(layer.opacity))
        ctx.setBlendMode(layer.blendMode.cgBlendMode)
        if layer.shadow.isOn {
            ctx.setShadow(offset: CGSize(width: layer.shadow.offsetX * k, height: layer.shadow.offsetY * k),
                          blur: CGFloat(layer.shadow.blur) * k,
                          color: (UIColor(hexRGB: layer.shadow.hex) ?? .black).withAlphaComponent(CGFloat(layer.shadow.opacity)).cgColor)
        }
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)

        if layer.highlight.isOn {
            let pad = layout.pointSize * 0.15
            let color = (UIColor(hexRGB: layer.highlight.hex) ?? .yellow).withAlphaComponent(CGFloat(layer.highlight.opacity))
            ctx.setFillColor(color.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: rect.insetBy(dx: -pad, dy: -pad * 0.6), cornerRadius: pad).cgPath)
            ctx.fillPath()
        }

        switch layer.fill {
        case .solid(let hex):
            let string = attributedString(for: layer, pointSize: layout.pointSize, color: UIColor(hexRGB: hex) ?? .white)
            string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        case .gradient(let gradient):
            // Glyphs as an alpha mask, then the gradient composited "source in": the gradient
            // only exists inside the letters and the gaps stay transparent.
            ctx.saveGState()
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            let string = attributedString(for: layer, pointSize: layout.pointSize, color: .white)
            string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            ctx.setBlendMode(.sourceIn)
            BackgroundRenderingService.drawLinearGradient(gradient, in: rect.insetBy(dx: -2, dy: -2), context: ctx)
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        }

        if layer.stroke.isOn, layer.stroke.width > 0 {
            let outline = attributedString(for: layer, pointSize: layout.pointSize, color: .clear,
                                           strokeColor: UIColor(hexRGB: layer.stroke.hex) ?? .black,
                                           strokeWidth: CGFloat(layer.stroke.width) * k)
            outline.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }

        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
}
