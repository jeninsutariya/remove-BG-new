//
//  TextBehindModels.swift
//  Background Removal
//
//  Non-destructive description of a "Text Behind Subject" composition. Rendered by
//  TextBehindSubjectRenderer for both the live preview and the export, so they always match.
//
//  Layer order (fixed): background → texts marked "behind" → subject cutout → texts "in front".
//  All positions and sizes are relative to the canvas, so the composition stays correct at
//  any preview or export resolution.
//

import UIKit

// MARK: - Colour helpers

/// Gradient with 2–3 colour stops and an angle (0° = left→right, 90° = top→bottom).
nonisolated struct GradientSpec: Codable, Equatable {
    nonisolated struct Stop: Codable, Equatable {
        var hex: String
        var location: Double
    }

    var stops: [Stop]
    var angle: Double

    init(_ hexes: [String], angle: Double = 0) {
        let count = max(hexes.count - 1, 1)
        stops = hexes.enumerated().map { Stop(hex: $0.element, location: Double($0.offset) / Double(count)) }
        self.angle = angle
    }

    static let presets: [GradientSpec] = [
        GradientSpec(["FF5F6D", "FFC371"], angle: 0),
        GradientSpec(["1677FF", "8B5CF6"], angle: 45),
        GradientSpec(["00C6FF", "0072FF"], angle: 90),
        GradientSpec(["F7971E", "FFD200"], angle: 0),
        GradientSpec(["11998E", "38EF7D"], angle: 135),
        GradientSpec(["FC466B", "3F5EFB"], angle: 0),
        GradientSpec(["FF9A9E", "FAD0C4", "FBC2EB"], angle: 90),
        GradientSpec(["0F2027", "203A43", "2C5364"], angle: 90),
        GradientSpec(["F12711", "F5AF19", "FFF200"], angle: 0),
        GradientSpec(["8E2DE2", "4A00E0", "00D2FF"], angle: 45),
        GradientSpec(["FFFFFF", "D1D5DB"], angle: 90),
        GradientSpec(["000000", "434343"], angle: 90)
    ]

    var colors: [UIColor] { stops.map { UIColor(hexRGB: $0.hex) ?? .white } }
}

nonisolated enum TBFill: Codable, Equatable {
    case solid(hex: String)
    case gradient(GradientSpec)
}

/// Drop shadow. Distances are in pixels per 1000 px of canvas width.
nonisolated struct ShadowStyle: Codable, Equatable {
    var isOn = false
    var hex = "000000"
    var opacity: Double = 0.35
    var blur: Double = 10
    var offsetX: Double = 0
    var offsetY: Double = 8

    static let presets: [(name: String, style: ShadowStyle)] = [
        ("Soft", ShadowStyle(isOn: true, hex: "000000", opacity: 0.30, blur: 18, offsetX: 0, offsetY: 8)),
        ("Hard", ShadowStyle(isOn: true, hex: "000000", opacity: 0.55, blur: 0, offsetX: 6, offsetY: 6)),
        ("Long", ShadowStyle(isOn: true, hex: "000000", opacity: 0.35, blur: 6, offsetX: 16, offsetY: 16)),
        ("Glow", ShadowStyle(isOn: true, hex: "FFFFFF", opacity: 0.80, blur: 24, offsetX: 0, offsetY: 0))
    ]
}

/// Outline around the glyphs. Width in pixels per 1000 px of canvas width.
nonisolated struct StrokeStyle: Codable, Equatable {
    var isOn = false
    var hex = "000000"
    var width: Double = 6
}

/// Box behind the text.
nonisolated struct HighlightStyle: Codable, Equatable {
    var isOn = false
    var hex = "FACC15"
    var opacity: Double = 1
}

nonisolated enum TBTextAlignment: String, Codable, CaseIterable {
    case left, center, right

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}

nonisolated enum TBCapitalization: String, Codable, CaseIterable {
    case none, upper, lower, title

    var title: String {
        switch self {
        case .none: return "Aa"
        case .upper: return "AA"
        case .lower: return "aa"
        case .title: return "Title"
        }
    }

    func apply(_ text: String) -> String {
        switch self {
        case .none: return text
        case .upper: return text.uppercased()
        case .lower: return text.lowercased()
        case .title: return text.capitalized
        }
    }
}

nonisolated enum TBBlendMode: String, Codable, CaseIterable {
    case normal, multiply, screen, overlay, softLight

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .overlay: return "Overlay"
        case .softLight: return "Soft light"
        }
    }

    var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .softLight: return .softLight
        }
    }
}

// MARK: - Text layer

nonisolated struct TextLayerModel: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = "Text"
    var text = "HELLO"
    /// PostScript name; falls back to the system font when it isn't available.
    var fontName = "HelveticaNeue-CondensedBlack"
    /// Point size per 1000 px of canvas width.
    var fontScale: Double = 220
    /// Text centre, normalised 0…1 within the canvas.
    var centerX: Double = 0.5
    var centerY: Double = 0.3
    /// Degrees, clockwise.
    var rotation: Double = 0
    /// Maximum line width as a fraction of the canvas width (multiline wraps inside it).
    var widthFraction: Double = 0.95
    var alignment: TBTextAlignment = .center
    var capitalization: TBCapitalization = .none
    /// Extra spacing between letters, as a fraction of the font size.
    var letterSpacing: Double = 0
    /// Line height multiplier.
    var lineSpacing: Double = 1
    var bold = false
    var italic = false
    var underline = false
    var strikethrough = false
    var fill: TBFill = .solid(hex: "FFFFFF")
    var opacity: Double = 1
    var shadow = ShadowStyle()
    var stroke = StrokeStyle()
    var highlight = HighlightStyle()
    var blendMode: TBBlendMode = .normal
    var isHidden = false
    var isLocked = false
    /// True: drawn behind the subject (the text-behind effect). False: drawn in front.
    var isBehindSubject = true

    var displayText: String { capitalization.apply(text) }
}

// MARK: - Background

nonisolated enum ImageFitMode: String, Codable, CaseIterable {
    case fit, fill, crop

    var title: String {
        switch self {
        case .fit: return "Fit"
        case .fill: return "Fill"
        case .crop: return "Crop"
        }
    }
}

/// How a background image is placed. `crop` = fill plus zoom and position.
nonisolated struct ImagePlacement: Codable, Equatable {
    var mode: ImageFitMode = .fill
    var zoom: Double = 1
    var offsetX: Double = 0
    var offsetY: Double = 0
}

nonisolated enum TBBackground: Codable, Equatable {
    /// The unchanged original photo.
    case original
    /// Nothing (checkerboard in the editor only, transparent PNG on export).
    case transparent
    case color(hex: String)
    case gradient(GradientSpec)
    /// Decorative image (remote from image_urls.json or a photo the user added).
    case image(BackgroundSelection, ImagePlacement)

    var isTransparent: Bool { self == .transparent }
}

// MARK: - Canvas

nonisolated enum CanvasPreset: String, Codable, CaseIterable {
    case original, square, portrait45, portrait34, story, landscape, custom

    var title: String {
        switch self {
        case .original: return "Original"
        case .square: return "1:1"
        case .portrait45: return "4:5"
        case .portrait34: return "3:4"
        case .story: return "9:16"
        case .landscape: return "16:9"
        case .custom: return "Custom"
        }
    }

    var ratio: Double? {
        switch self {
        case .original, .custom: return nil
        case .square: return 1
        case .portrait45: return 4.0 / 5.0
        case .portrait34: return 3.0 / 4.0
        case .story: return 9.0 / 16.0
        case .landscape: return 16.0 / 9.0
        }
    }
}

nonisolated enum ContentFitMode: String, Codable, CaseIterable {
    case fit, fill

    var title: String { self == .fit ? "Fit content" : "Fill canvas" }
}

nonisolated struct CanvasSpec: Codable, Equatable {
    var preset: CanvasPreset = .original
    var customWidth = 1080
    var customHeight = 1350
    /// How the photo (and its subject) sits in the canvas.
    var contentMode: ContentFitMode = .fit
    var contentZoom: Double = 1
    var contentOffsetX: Double = 0
    var contentOffsetY: Double = 0
}

/// Non-destructive mask edits. The Vision mask itself is never modified.
nonisolated struct MaskSettings: Codable, Equatable {
    /// Gray PNG in the project folder painted with the Refine brush (nil = Vision mask).
    var refinedMaskFileName: String?
    /// Soft edge, pixels per 1000 px of photo width.
    var feather: Double = 0
    /// Shrinks the mask edge to remove halos, pixels per 1000 px of photo width.
    var edgeSmoothing: Double = 0
}

// MARK: - Document

nonisolated struct TextBehindDocument: Codable, Equatable {
    var background: TBBackground = .original
    var texts: [TextLayerModel] = []
    var canvas = CanvasSpec()
    var mask = MaskSettings()
    var subjectShadow = ShadowStyle()
    var subjectVisible = true
    var exportFormat: ExportFormat = .jpg
    var jpegQuality: Double = 0.92

    static func starter() -> TextBehindDocument {
        var document = TextBehindDocument()
        document.texts = [TextLayerModel(name: "Text 1")]
        return document
    }

    func text(_ id: UUID?) -> TextLayerModel? {
        guard let id else { return nil }
        return texts.first { $0.id == id }
    }

    /// Files in the project folder this document needs.
    var referencedFiles: [String] {
        var files: [String] = []
        if let mask = mask.refinedMaskFileName { files.append(mask) }
        if case .image(let selection, _) = background, let name = selection.customFileName { files.append(name) }
        return files
    }
}

// MARK: - Recents (per-user conveniences)

enum EditorRecents {
    private static let colorsKey = "textBehind.recentColors"
    private static let fontsKey = "textBehind.recentFonts"

    static var colors: [String] { UserDefaults.standard.stringArray(forKey: colorsKey) ?? [] }
    static var fonts: [String] { UserDefaults.standard.stringArray(forKey: fontsKey) ?? [] }

    static func add(color hex: String) {
        var list = colors.filter { $0 != hex }
        list.insert(hex, at: 0)
        UserDefaults.standard.set(Array(list.prefix(12)), forKey: colorsKey)
    }

    static func add(font name: String) {
        var list = fonts.filter { $0 != name }
        list.insert(name, at: 0)
        UserDefaults.standard.set(Array(list.prefix(8)), forKey: fontsKey)
    }
}
