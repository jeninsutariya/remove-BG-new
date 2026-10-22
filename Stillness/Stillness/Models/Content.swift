import Foundation

enum ContentKind: String, Codable, CaseIterable, Hashable {
    case meditation
    case sleepStory
    case music
    case soundscape
    case breathing

    var label: String {
        switch self {
        case .meditation: return "Meditation"
        case .sleepStory: return "Sleep story"
        case .music: return "Music"
        case .soundscape: return "Soundscape"
        case .breathing: return "Breathing"
        }
    }

    /// Guided sessions count as mindful minutes in Apple Health. Music and soundscapes do not.
    var countsAsMindful: Bool {
        self == .meditation || self == .sleepStory || self == .breathing
    }

    var allowsPlaylists: Bool {
        self == .meditation || self == .sleepStory || self == .music
    }

    /// Soundscapes loop until the user stops them or the sleep timer ends.
    var loops: Bool { self == .soundscape }
}

struct Topic: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
}

struct Narrator: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let bio: String
}

struct Series: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
}

struct ContentItem: Codable, Identifiable, Hashable {
    let id: String
    let kind: ContentKind
    let title: String
    let summary: String
    let narratorID: String?
    let seriesID: String?
    let episode: Int?
    let durationSeconds: Int
    /// `bundle:file.ext` for a file inside the app, or an https URL.
    let audio: String
    /// SF Symbol shown on the artwork until you have real cover art.
    let symbol: String
    /// Two or three hex colors for the artwork gradient.
    let colors: [String]
    let isFree: Bool
    let topics: [String]

    var durationLabel: String {
        if kind.loops { return "Loop" }
        if durationSeconds < 60 { return "\(durationSeconds) sec" }
        return "\(Int((Double(durationSeconds) / 60).rounded())) min"
    }
}

struct SceneItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let colors: [String]
    let loopAudio: String?
    let isFree: Bool
}

struct Catalog: Codable {
    let topics: [Topic]
    let narrators: [Narrator]
    let series: [Series]
    let items: [ContentItem]
    let scenes: [SceneItem]
    /// Content IDs for the daily session, one per day in order, repeating.
    let dailyRotation: [String]

    static let empty = Catalog(topics: [], narrators: [], series: [], items: [], scenes: [], dailyRotation: [])
}
