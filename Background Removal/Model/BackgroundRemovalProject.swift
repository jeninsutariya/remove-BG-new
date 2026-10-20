//
//  BackgroundRemovalProject.swift
//  Background Removal
//

import Foundation

nonisolated struct ProjectExportSettings: Codable, Equatable {
    var lastExportQuality: ExportQuality?
    var lastExportDate: Date?
}

/// A saved editing session (one or many photos). Persisted as `project.json`
/// next to its image files by `ProjectStorageService`.
nonisolated struct BackgroundRemovalProject: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var items: [BackgroundRemovalItem]
    var exportSettings: ProjectExportSettings
    /// Flow that created the project (decides the editor tools).
    var mode: EditorMode
    /// Created with Bulk Background Removal (decides which daily free limit applies).
    var isBatch: Bool
    /// Small flattened preview of the edited result (Recents / Projects). Never replaces the
    /// original or the editable state; regenerated when the composition changes.
    var thumbnailFileName: String?
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), name: String, items: [BackgroundRemovalItem] = [], mode: EditorMode = .removeBackground,
         isBatch: Bool = false) {
        self.id = id
        self.name = name
        self.items = items
        self.exportSettings = ProjectExportSettings()
        self.mode = mode
        self.isBatch = isBatch
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    nonisolated private enum CodingKeys: String, CodingKey {
        case id, name, items, exportSettings, mode, isBatch, thumbnailFileName, createdAt, modifiedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Cutout"
        items = try c.decode([BackgroundRemovalItem].self, forKey: .items)
        exportSettings = (try? c.decode(ProjectExportSettings.self, forKey: .exportSettings)) ?? ProjectExportSettings()
        mode = (try? c.decode(EditorMode.self, forKey: .mode)) ?? .removeBackground
        // Projects saved before this flag existed: several photos = batch.
        isBatch = (try? c.decode(Bool.self, forKey: .isBatch)) ?? (items.count > 1)
        thumbnailFileName = try? c.decodeIfPresent(String.self, forKey: .thumbnailFileName)
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        modifiedAt = (try? c.decode(Date.self, forKey: .modifiedAt)) ?? Date()
    }

    var completedItems: [BackgroundRemovalItem] { items.filter(\.isCompleted) }

    /// Item used as the project thumbnail.
    var coverItem: BackgroundRemovalItem? { completedItems.first ?? items.first }

    func index(of itemID: UUID) -> Int? { items.firstIndex { $0.id == itemID } }

    /// "Today · 3 images", "Yesterday · PNG"…
    var subtitle: String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(modifiedAt) {
            day = "Today"
        } else if calendar.isDateInYesterday(modifiedAt) {
            day = "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            day = formatter.string(from: modifiedAt)
        }
        if items.count > 1 { return "\(day) · \(items.count) images" }
        let opaque = items.first.map { !$0.background.isTransparent } ?? false
        return "\(day) · \(opaque ? "JPG" : "PNG")"
    }
}
