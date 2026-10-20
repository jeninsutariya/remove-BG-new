//
//  ExportQuality.swift
//  Background Removal
//
//  Single place that defines what "Standard" (free) and "Full" (premium) export mean.
//  Every export path (Gallery and ZIP) asks ExportQuality.current.
//

import CoreGraphics
import Foundation

nonisolated enum ExportQuality: String, Codable {
    /// Quality every export path must use, based on the premium flag.
    static var current: ExportQuality { UserDefaults.isPremiumUser ? .full : .standard }

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

/// File format chosen on the Export screen.
nonisolated enum ExportFormat: Int, Codable, CaseIterable {
    case png, jpg

    var title: String { self == .png ? "PNG" : "JPG" }
    var fileExtension: String { self == .png ? "png" : "jpg" }
}

/// Export screen choices. Every value is applied on top of the central quality policy.
nonisolated struct ExportOptions: Equatable {
    /// nil = automatic (PNG when transparent, otherwise JPEG).
    var format: ExportFormat?
    /// Extra size limit (Large / Medium / Small); the quality limit still applies.
    var maxDimension: CGFloat?
    /// Replaces each item's own background (e.g. "Transparent" or "White").
    var backgroundOverride: BackgroundSelection?

    init(format: ExportFormat? = nil, maxDimension: CGFloat? = nil, backgroundOverride: BackgroundSelection? = nil) {
        self.format = format
        self.maxDimension = maxDimension
        self.backgroundOverride = backgroundOverride
    }

    /// Effective long-side limit for a quality.
    func maxDimension(for quality: ExportQuality) -> CGFloat? {
        switch (maxDimension, quality.maxPixelDimension) {
        case let (a?, b?): return min(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }

    /// Background actually rendered for an item (JPEG has no transparency → white).
    func background(for item: BackgroundRemovalItem) -> BackgroundSelection {
        let selection = backgroundOverride ?? item.background
        if format == .jpg, selection.isTransparent { return .color(hex: "FFFFFF") }
        return selection
    }

    /// Format actually written for an item.
    func format(for item: BackgroundRemovalItem) -> ExportFormat {
        format ?? (background(for: item).isTransparent ? .png : .jpg)
    }
}
