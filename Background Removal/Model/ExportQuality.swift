//
//  ExportQuality.swift
//  Background Removal
//
//  Single place that defines what "Standard" (free) and "Full" (premium) export mean.
//  Every export path (Gallery and ZIP) asks PremiumManager.shared.exportQuality.
//

import CoreGraphics

nonisolated enum ExportQuality: String, Codable {
    /// Free: long side limited to 2048 px (only when the image is larger), JPEG 0.85.
    case standard
    /// Premium: the full resolution produced by the pipeline, JPEG 0.95.
    case full

    /// Standard-quality resolution limit, documented in the README and on the premium screen.
    static let standardMaxPixelDimension: CGFloat = 2048

    /// `nil` = keep the pipeline resolution (never upscaled).
    var maxPixelDimension: CGFloat? {
        switch self {
        case .standard: return Self.standardMaxPixelDimension
        case .full: return nil
        }
    }

    /// Used for opaque results (a background was applied). Transparent results are always PNG.
    var jpegQuality: CGFloat {
        switch self {
        case .standard: return 0.85
        case .full: return 0.95
        }
    }

    var displayName: String {
        switch self {
        case .standard: return "Standard quality (up to \(Int(Self.standardMaxPixelDimension)) px)"
        case .full: return "Full quality"
        }
    }
}
