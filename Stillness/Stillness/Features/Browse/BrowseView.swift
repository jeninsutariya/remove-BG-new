import SwiftUI

/// S08, S09, S10. One screen for the Sleep, Meditate and Music tabs: topic chips, search and a grid.
struct BrowseView: View {
    let title: String
    let kinds: Set<ContentKind>

    @Environment(CatalogService.self) private var catalog
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var topic: String?
    @State private var query = ""

    private var items: [ContentItem] {
        catalog.items(kinds: kinds, topic: topic).filter { item in
            query.isEmpty
                || item.title.localizedCaseInsensitiveContains(query)
                || item.summary.localizedCaseInsensitiveContains(query)
        }
    }

    private var topics: [Topic] {
        let used = Set(catalog.items(kinds: kinds).flatMap(\.topics))
        return catalog.topics.filter { used.contains($0.id) }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "All", isSelected: topic == nil) { topic = nil }
                        ForEach(topics) { item in
                            Chip(title: item.title, symbol: item.symbol, isSelected: topic == item.id) {
                                topic = item.id
                            }
                        }
                    }
                }
                .scrollClipDisabled()

                if items.isEmpty {
                    if query.isEmpty {
                        ContentUnavailableView("Nothing here yet", systemImage: "tray", description: Text("New sessions are on the way."))
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                ContentCard(item: item, isLocked: !item.isFree && !subscriptions.isPremium)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
        .searchable(text: $query, prompt: "Search \(title.lowercased())")
        .rootScreen()
    }
}
