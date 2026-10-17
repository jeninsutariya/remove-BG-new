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
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), name: String, items: [BackgroundRemovalItem] = []) {
        self.id = id
        self.name = name
        self.items = items
        self.exportSettings = ProjectExportSettings()
        self.createdAt = Date()
        self.modifiedAt = Date()
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
