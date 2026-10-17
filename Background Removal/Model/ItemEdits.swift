//
//  ItemEdits.swift
//  Background Removal
//
//  Non-destructive edits for one image (Shadow and Resize tools), plus the editor mode that
//  decides which tools a project shows. Rendered by ImageCompositingService for both the
//  preview and the export.
//

import Foundation

/// Drop shadow under the subject. Values are 0…100 like the sliders.
nonisolated struct ShadowSettings: Codable, Equatable {
    var isOn = false
    var opacity: Double = 35
    var softness: Double = 30
    var distance: Double = 20
}

/// Canvas aspect ratio (Resize tool).
nonisolated enum CanvasAspect: String, Codable, CaseIterable {
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

    /// Width / height, nil keeps the photo's own ratio.
    var ratio: Double? {
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

nonisolated struct ItemEdits: Codable, Equatable {
    var shadow = ShadowSettings()
    var aspect: CanvasAspect = .original
    /// Subject size inside the canvas, 0.5…1.
    var subjectScale: Double = 1

    static let unedited = ItemEdits()
}

/// Which flow created the project; decides the editor tools.
nonisolated enum EditorMode: String, Codable {
    /// Remove Background / Batch Remove → Refine, Shadow, Resize.
    case removeBackground
    /// Change Background → Background, Refine, Shadow, Resize.
    case changeBackground

    var tools: [EditorTool] {
        switch self {
        case .removeBackground: return [.refine, .shadow, .resize]
        case .changeBackground: return [.background, .refine, .shadow, .resize]
        }
    }
}

nonisolated enum EditorTool: String, CaseIterable {
    case background, refine, shadow, resize

    var title: String {
        switch self {
        case .background: return "Background"
        case .refine: return "Refine"
        case .shadow: return "Shadow"
        case .resize: return "Resize"
        }
    }

    var symbol: String {
        switch self {
        case .background: return "square.stack.3d.up"
        case .refine: return "eraser"
        case .shadow: return "person.crop.circle.badge"
        case .resize: return "crop"
        }
    }
}
