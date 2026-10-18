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
    /// Shadow / Resize edits (non-destructive).
    var edits: ItemEdits
    /// Text Behind Subject composition (only for Text Behind projects).
    var textBehind: TextBehindDocument?
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
        self.edits = .unedited
        self.textBehind = nil
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    nonisolated private enum CodingKeys: String, CodingKey {
        case id, sourceName, originalFileName, foregroundFileName, status, errorMessage, background, edits, textBehind, createdAt, modifiedAt
    }

    /// Tolerant decoding so projects saved by older versions still open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sourceName = try c.decodeIfPresent(String.self, forKey: .sourceName)
        originalFileName = try c.decode(String.self, forKey: .originalFileName)
        foregroundFileName = try c.decodeIfPresent(String.self, forKey: .foregroundFileName)
        status = (try? c.decode(ItemProcessingStatus.self, forKey: .status)) ?? .waiting
        errorMessage = try c.decodeIfPresent(String.self, forKey: .errorMessage)
        background = (try? c.decode(BackgroundSelection.self, forKey: .background)) ?? BackgroundSelection.none
        edits = (try? c.decode(ItemEdits.self, forKey: .edits)) ?? ItemEdits.unedited
        textBehind = try? c.decodeIfPresent(TextBehindDocument.self, forKey: .textBehind)
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        modifiedAt = (try? c.decode(Date.self, forKey: .modifiedAt)) ?? Date()
    }

    var isCompleted: Bool { status == .completed && foregroundFileName != nil }
}
