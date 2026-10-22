import Foundation
import SwiftData

@Model
final class SessionRecord {
    var id: UUID
    var contentID: String
    var kindRaw: String
    var startedAt: Date
    var secondsListened: Double
    var completed: Bool

    init(contentID: String, kind: ContentKind, startedAt: Date, secondsListened: Double, completed: Bool) {
        self.id = UUID()
        self.contentID = contentID
        self.kindRaw = kind.rawValue
        self.startedAt = startedAt
        self.secondsListened = secondsListened
        self.completed = completed
    }

    var kind: ContentKind { ContentKind(rawValue: kindRaw) ?? .meditation }

    /// A session keeps the streak alive if it finished or ran for at least a minute.
    var countsTowardStreak: Bool { completed || secondsListened >= 60 }
}

enum CheckInKind: String, CaseIterable, Identifiable {
    case mood
    case sleep
    case gratitude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood: return "Mood"
        case .sleep: return "Sleep"
        case .gratitude: return "Gratitude"
        }
    }

    var prompt: String {
        switch self {
        case .mood: return "How are you feeling?"
        case .sleep: return "How did you sleep?"
        case .gratitude: return "What are you grateful for today?"
        }
    }
}

@Model
final class CheckInRecord {
    var id: UUID
    var kindRaw: String
    /// 1 to 5 for mood and sleep, 0 for gratitude.
    var value: Int
    var tags: [String]
    var note: String
    var createdAt: Date

    init(kind: CheckInKind, value: Int, tags: [String], note: String, createdAt: Date = .now) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.value = value
        self.tags = tags
        self.note = note
        self.createdAt = createdAt
    }

    var kind: CheckInKind { CheckInKind(rawValue: kindRaw) ?? .mood }
}

@Model
final class FavoriteRecord {
    @Attribute(.unique) var contentID: String
    var createdAt: Date

    init(contentID: String, createdAt: Date = .now) {
        self.contentID = contentID
        self.createdAt = createdAt
    }
}

@Model
final class PlaylistRecord {
    var id: UUID
    var name: String
    var createdAt: Date
    var itemIDs: [String]

    init(name: String, itemIDs: [String] = [], createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.itemIDs = itemIDs
        self.createdAt = createdAt
    }
}

@Model
final class DownloadRecord {
    @Attribute(.unique) var contentID: String
    var fileName: String
    var downloadedAt: Date

    init(contentID: String, fileName: String, downloadedAt: Date = .now) {
        self.contentID = contentID
        self.fileName = fileName
        self.downloadedAt = downloadedAt
    }
}
