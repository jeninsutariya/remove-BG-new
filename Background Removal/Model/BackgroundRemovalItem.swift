//
//  BackgroundRemovalItem.swift
//  Background Removal
//
//  One photo inside a project: its original, its transparent foreground,
//  its processing state and its own background selection.
//

import UIKit

nonisolated enum ItemProcessingStatus: String, Codable {
    case waiting
    case processing
    case completed
    case failed

    var displayName: String {
        switch self {
        case .waiting: return "Waiting"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

/// What is rendered behind the transparent foreground.
nonisolated enum BackgroundSelection: Codable, Equatable {
    /// Transparent (checkerboard in the UI only).
    case none
    /// Solid colour stored as `RRGGBB`.
    case color(hex: String)
    /// Image from `image_urls.json`, loaded with SDWebImage.
    case remoteImage(id: Int, url: URL)
    /// Image the user picked; the file lives in the project folder.
    case customImage(fileName: String)

    var isTransparent: Bool { self == .none }

    var customFileName: String? {
        if case .customImage(let fileName) = self { return fileName }
        return nil
    }
}

nonisolated struct BackgroundRemovalItem: Codable, Identifiable, Equatable {
    let id: UUID
    /// Human-readable name from the photo library (used for export file names).
    var sourceName: String?
    /// File in the project folder holding the original photo.
    var originalFileName: String
    /// File in the project folder holding the transparent PNG foreground.
    var foregroundFileName: String?
    var status: ItemProcessingStatus
    var errorMessage: String?
    var background: BackgroundSelection
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), sourceName: String?, originalFileName: String) {
        self.id = id
        self.sourceName = sourceName
        self.originalFileName = originalFileName
        self.foregroundFileName = nil
        self.status = .waiting
        self.errorMessage = nil
        self.background = .none
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    var isCompleted: Bool { status == .completed && foregroundFileName != nil }
}
