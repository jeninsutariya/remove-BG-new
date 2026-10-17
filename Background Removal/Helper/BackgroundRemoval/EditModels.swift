//
//  EditModels.swift
//  Background Removal
//
//  Non-destructive edit description + the layout/render maths shared by the
//  live preview (EditorCanvasView) and the exporter (EditRenderer).
//

import UIKit

// MARK: - Background

enum BackgroundSpec: Equatable {
    case transparent
    case color(UIColor)
    case photo(id: String)

    var isTransparent: Bool {
        if case .transparent = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case .transparent: return "Transparent"
        case .color: return "Color"
        case .photo: return "Photo"
        }
    }

    static func == (lhs: BackgroundSpec, rhs: BackgroundSpec) -> Bool {
        switch (lhs, rhs) {
        case (.transparent, .transparent): return true
        case let (.color(a), .color(b)): return a.isEqual(b)
        case let (.photo(a), .photo(b)): return a == b
        default: return false
        }
    }
}

// MARK: - Text behind

enum TextFontStyle: Int, CaseIterable {
    case bold, serif, light, wide

    var title: String {
        switch self {
        case .bold: return "Bold"
        case .serif: return "Serif"
        case .light: return "Light"
        case .wide: return "WIDE"
        }
    }

    func font(size: CGFloat) -> UIFont {
        switch self {
        case .bold: return UIFont(name: "Figtree-ExtraBold", size: size) ?? .systemFont(ofSize: size, weight: .heavy)
        case .serif: return UIFont(name: "InstrumentSerif-Italic", size: size * 1.15) ?? .italicSystemFont(ofSize: size)
        case .light: return UIFont(name: "Figtree-Regular", size: size) ?? .systemFont(ofSize: size)
        case .wide: return UIFont(name: "Figtree-Bold", size: size * 0.85) ?? .systemFont(ofSize: size, weight: .bold)
        }
    }

    func kern(size: CGFloat) -> CGFloat {
        switch self {
        case .bold: return -size * 0.02
        case .serif: return -size * 0.01
        case .light: return 0
        case .wide: return size * 0.12
        }
    }
}

struct TextSpec: Equatable {
    var text: String = "HELLO"
    var style: TextFontStyle = .bold
    var color: UIColor = .white
    /// Font size relative to a 270 pt wide canvas (matches the Figma "Size 76").
    var size: CGFloat = 76
    /// Text centre, normalised 0…1 in the canvas.
    var center = CGPoint(x: 0.5, y: 0.2)

    var displayText: String { style == .wide ? text.uppercased() : text }

    static func == (lhs: TextSpec, rhs: TextSpec) -> Bool {
        lhs.text == rhs.text && lhs.style == rhs.style && lhs.color.isEqual(rhs.color)
            && lhs.size == rhs.size && lhs.center == rhs.center
    }
}

// MARK: - Shadow / resize

struct ShadowSpec: Equatable {
    var isOn = false
    var opacity: CGFloat = 35      // 0…100
    var softness: CGFloat = 30     // 0…100
    var distance: CGFloat = 20     // 0…100
}

enum AspectSpec: Int, CaseIterable {
    case original, square, portrait45, portrait34, story, landscape

    var title: String {
        switch self {
        case .original: return "Original"
        case .square: return "1:1"
        case .portrait45: return "4:5"
        case .portrait34: return "3:4"
        case .story: return "9:16"
        case .landscape: return "16:9"
        }
    }

    var ratio: CGFloat? {
        switch self {
        case .original: return nil
        case .square: return 1
        case .portrait45: return 4.0 / 5.0
        case .portrait34: return 3.0 / 4.0
        case .story: return 9.0 / 16.0
        case .landscape: return 16.0 / 9.0
        }
    }
}

struct EditSpec: Equatable {
    var background: BackgroundSpec = .transparent
    var text: TextSpec?
    var shadow = ShadowSpec()
    var aspect: AspectSpec = .original
    /// 0.5…1 – subject size inside the canvas.
    var subjectScale: CGFloat = 1
}

// MARK: - Layout shared by preview and export

struct CanvasLayout {
    let canvasSize: CGSize
    let subjectRect: CGRect

    static func canvasPixelSize(imageSize: CGSize, aspect: AspectSpec) -> CGSize {
        guard let ratio = aspect.ratio else { return imageSize }
        let imageRatio = imageSize.width / max(imageSize.height, 1)
        if ratio > imageRatio {
            return CGSize(width: (imageSize.height * ratio).rounded(), height: imageSize.height)
        }
        return CGSize(width: imageSize.width, height: (imageSize.width / ratio).rounded())
    }

    init(imageSize: CGSize, spec: EditSpec, drawWidth: CGFloat) {
        let pixelCanvas = Self.canvasPixelSize(imageSize: imageSize, aspect: spec.aspect)
        let k = drawWidth / max(pixelCanvas.width, 1)
        canvasSize = CGSize(width: drawWidth, height: pixelCanvas.height * k)
        let subject = CGSize(width: imageSize.width * k * spec.subjectScale, height: imageSize.height * k * spec.subjectScale)
        // Centred; when shrunk the subject keeps resting on the photo's bottom edge.
        let photoBottom = (canvasSize.height + imageSize.height * k) / 2
        subjectRect = CGRect(x: (canvasSize.width - subject.width) / 2, y: photoBottom - subject.height,
                             width: subject.width, height: subject.height)
    }

    func fontSize(for text: TextSpec) -> CGFloat {
        text.size * canvasSize.width / 270
    }

    func shadow(_ shadow: ShadowSpec) -> (offset: CGSize, blur: CGFloat) {
        let unit = canvasSize.width / 334
        return (CGSize(width: 0, height: shadow.distance * unit * 0.6), shadow.softness * unit * 0.5)
    }
}

// MARK: - Export renderer

enum EditRenderer {
    struct Options {
        var maxDimension: CGFloat?
        var backgroundOverride: BackgroundSpec?
    }

    static func attributedText(_ text: TextSpec, fontSize: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineHeightMultiple = 0.88
        return NSAttributedString(string: text.displayText, attributes: [
            .font: text.style.font(size: fontSize),
            .kern: text.style.kern(size: fontSize),
            .foregroundColor: text.color,
            .paragraphStyle: paragraph
        ])
    }

    static func outputPixelSize(imageSize: CGSize, spec: EditSpec, maxDimension: CGFloat?) -> CGSize {
        var canvas = CanvasLayout.canvasPixelSize(imageSize: imageSize, aspect: spec.aspect)
        if let maxDimension, max(canvas.width, canvas.height) > maxDimension {
            let r = maxDimension / max(canvas.width, canvas.height)
            canvas = CGSize(width: (canvas.width * r).rounded(), height: (canvas.height * r).rounded())
        }
        return canvas
    }

    static func render(session: EditSession, options: Options = Options()) -> UIImage {
        let imageSize = session.pixelSize
        let spec = session.spec
        let canvas = outputPixelSize(imageSize: imageSize, spec: spec, maxDimension: options.maxDimension)
        let layout = CanvasLayout(imageSize: imageSize, spec: spec, drawWidth: canvas.width)
        let background = options.backgroundOverride ?? spec.background

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: layout.canvasSize, format: format).image { ctx in
            let rect = CGRect(origin: .zero, size: layout.canvasSize)
            switch background {
            case .transparent:
                break
            case .color(let color):
                color.setFill()
                ctx.fill(rect)
            case .photo(let id):
                if let photo = session.photos[id] { drawAspectFill(photo, in: rect) }
            }

            if let text = spec.text, !text.text.isEmpty {
                let string = attributedText(text, fontSize: layout.fontSize(for: text))
                let bounds = string.boundingRect(with: CGSize(width: rect.width * 2, height: .greatestFiniteMagnitude),
                                                 options: [.usesLineFragmentOrigin], context: nil)
                let center = CGPoint(x: rect.width * text.center.x, y: rect.height * text.center.y)
                string.draw(with: CGRect(x: center.x - bounds.width / 2, y: center.y - bounds.height / 2,
                                         width: bounds.width, height: bounds.height),
                            options: [.usesLineFragmentOrigin], context: nil)
            }

            let cg = ctx.cgContext
            cg.saveGState()
            if spec.shadow.isOn {
                let params = layout.shadow(spec.shadow)
                cg.setShadow(offset: params.offset, blur: params.blur,
                             color: UIColor.black.withAlphaComponent(spec.shadow.opacity / 100).cgColor)
            }
            session.cutout.draw(in: layout.subjectRect)
            cg.restoreGState()
        }
    }

    static func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        let s = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * s, height: image.size.height * s)
        image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                              width: size.width, height: size.height))
    }
}

enum ExportFormat: Int, CaseIterable {
    case png, jpg

    var title: String { self == .png ? "PNG" : "JPG" }
    var fileExtension: String { self == .png ? "png" : "jpg" }
}

/// Swatches from the Figma "Change Background" / "Text Behind" sheets.
enum EditorSwatches {
    static func hex(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    static let background: [UIColor] = [
        .white, hex(0x121212), hex(0xD6E6FF), hex(0xFBDCC4), hex(0xFFD84A),
        hex(0xF6B3C0), hex(0xBFE8D0), hex(0xF26B43), hex(0x2F7D4F), hex(0x1E2A4A)
    ]

    static let text: [UIColor] = [
        .white, hex(0xFFD84A), hex(0x121212), hex(0xF26B43), hex(0xBFE8D0), hex(0xD6E6FF)
    ]

    static let brandBlue = hex(0x1677FF)
}
