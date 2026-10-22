import SwiftUI
import SwiftData

/// Lists pushed from Profile. Rows link to content details through the Profile tab's navigation destination.

struct FavoritesView: View {
    @Environment(CatalogService.self) private var catalog
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(\.modelContext) private var context
    @Query(sort: \FavoriteRecord.createdAt, order: .reverse) private var favorites: [FavoriteRecord]

    var body: some View {
        Group {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No favorites yet",
                    systemImage: "heart",
                    description: Text("Tap the heart on any session to keep it here.")
                )
            } else {
                List {
                    ForEach(favorites) { favorite in
                        if let item = catalog.item(id: favorite.contentID) {
                            NavigationLink(value: item) {
                                ContentRow(item: item, isLocked: !item.isFree && !subscriptions.isPremium)
                            }
                            .listRowBackground(Theme.surface)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(favorites[index]) }
                        try? context.save()
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Favorites")
        .miniPlayer()
    }
}

struct PlaylistsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlaylistRecord.createdAt) private var playlists: [PlaylistRecord]

    var body: some View {
        Group {
            if playlists.isEmpty {
                ContentUnavailableView(
                    "No playlists yet",
                    systemImage: "music.note.list",
                    description: Text("Add meditations, stories or music to a playlist from the player.")
                )
            } else {
                List {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name).foregroundStyle(Theme.text)
                                Text(playlist.itemIDs.count == 1 ? "1 item" : "\(playlist.itemIDs.count) items")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(playlists[index]) }
                        try? context.save()
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Playlists")
        .miniPlayer()
    }
}

struct PlaylistDetailView: View {
    let playlist: PlaylistRecord

    @Environment(CatalogService.self) private var catalog
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            ForEach(Array(playlist.itemIDs.enumerated()), id: \.offset) { entry in
                if let item = catalog.item(id: entry.element) {
                    NavigationLink(value: item) {
                        ContentRow(item: item, isLocked: !item.isFree && !subscriptions.isPremium)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .onDelete { offsets in
                playlist.itemIDs.remove(atOffsets: offsets)
                try? context.save()
            }
            .onMove { from, to in
                playlist.itemIDs.move(fromOffsets: from, toOffset: to)
                try? context.save()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(playlist.name)
        .toolbar { EditButton() }
        .miniPlayer()
    }
}

struct DownloadsView: View {
    @Environment(CatalogService.self) private var catalog
    @Environment(DownloadService.self) private var downloadService
    @Environment(\.modelContext) private var context
    @Query(sort: \DownloadRecord.downloadedAt, order: .reverse) private var downloads: [DownloadRecord]

    var body: some View {
        Group {
            if downloads.isEmpty {
                ContentUnavailableView(
                    "No downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Download sessions to listen without a connection.")
                )
            } else {
                List {
                    ForEach(downloads) { record in
                        if let item = catalog.item(id: record.contentID) {
                            NavigationLink(value: item) {
                                ContentRow(item: item)
                            }
                            .listRowBackground(Theme.surface)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { downloadService.remove(downloads[index], context: context) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Downloads")
        .miniPlayer()
    }
}

struct HistoryView: View {
    @Environment(CatalogService.self) private var catalog
    @Query(sort: \SessionRecord.startedAt, order: .reverse) private var sessions: [SessionRecord]

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "Nothing yet",
                    systemImage: "clock",
                    description: Text("Your sessions will show up here.")
                )
            } else {
                List(sessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(for: session)).foregroundStyle(Theme.text)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        Text(PlayerView.format(session.secondsListened))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textMuted)
                        if session.completed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                                .accessibilityLabel("Completed")
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("History")
    }

    private func title(for session: SessionRecord) -> String {
        if let item = catalog.item(id: session.contentID) { return item.title }
        return session.kind == .breathing ? "Breathing" : "Session"
    }
}
