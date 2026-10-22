import Foundation
import Observation

/// Reads the content catalog. Today it is `catalog.json` in the app bundle;
/// later, fetch the same JSON from your CDN in `load()` so new content needs no app update.
@Observable @MainActor
final class CatalogService {
    private(set) var catalog: Catalog = .empty
    private(set) var loadError: String?

    init() {
        load()
    }

    func load() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            loadError = "catalog.json is missing from the app bundle."
            return
        }
        do {
            catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
            loadError = nil
        } catch {
            loadError = "catalog.json could not be read: \(error)"
        }
    }

    var topics: [Topic] { catalog.topics }
    var scenes: [SceneItem] { catalog.scenes }

    func item(id: String) -> ContentItem? {
        catalog.items.first { $0.id == id }
    }

    func items(kinds: Set<ContentKind>? = nil, topic: String? = nil) -> [ContentItem] {
        catalog.items.filter { item in
            (kinds?.contains(item.kind) ?? true) && (topic.map { item.topics.contains($0) } ?? true)
        }
    }

    func items(inSeries seriesID: String) -> [ContentItem] {
        catalog.items
            .filter { $0.seriesID == seriesID }
            .sorted { ($0.episode ?? 0) < ($1.episode ?? 0) }
    }

    func narrator(for item: ContentItem) -> Narrator? {
        guard let id = item.narratorID else { return nil }
        return catalog.narrators.first { $0.id == id }
    }

    func series(for item: ContentItem) -> Series? {
        guard let id = item.seriesID else { return nil }
        return catalog.series.first { $0.id == id }
    }

    func scene(id: String) -> SceneItem? {
        catalog.scenes.first { $0.id == id }
    }

    /// The same session for everyone on a given day, rotating through `dailyRotation`.
    func dailyItem(on date: Date = .now, calendar: Calendar = .current) -> ContentItem? {
        let rotation = catalog.dailyRotation
        guard !rotation.isEmpty, let day = calendar.ordinality(of: .day, in: .era, for: date) else { return nil }
        return item(id: rotation[day % rotation.count])
    }

    /// Turns `bundle:name.ext` or an https string into a URL the player can open.
    nonisolated static func resolve(_ location: String) -> URL? {
        let prefix = "bundle:"
        if location.hasPrefix(prefix) {
            let file = String(location.dropFirst(prefix.count)) as NSString
            return Bundle.main.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension)
        }
        return URL(string: location)
    }
}
