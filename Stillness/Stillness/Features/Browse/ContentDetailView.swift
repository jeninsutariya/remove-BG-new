import SwiftUI
import SwiftData

/// S11. Locked items open here too, so people can see what they would get. Play opens the paywall.
struct ContentDetailView: View {
    let item: ContentItem

    @Environment(CatalogService.self) private var catalog
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(PlayerController.self) private var player
    @Environment(DownloadService.self) private var downloads
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query private var favorites: [FavoriteRecord]
    @Query private var downloaded: [DownloadRecord]
    @State private var isPlaylistPickerPresented = false

    init(item: ContentItem) {
        self.item = item
        let id = item.id
        _favorites = Query(filter: #Predicate<FavoriteRecord> { $0.contentID == id })
        _downloaded = Query(filter: #Predicate<DownloadRecord> { $0.contentID == id })
    }

    private var isLocked: Bool { !item.isFree && !subscriptions.isPremium }
    private var download: DownloadRecord? { downloaded.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ArtworkView(colors: item.colors, symbol: item.symbol, symbolSize: 64)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.kind.label.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Text(item.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.text)
                    HStack(spacing: 6) {
                        Text(item.durationLabel)
                        if let narrator = catalog.narrator(for: item) {
                            Text("·")
                            Text(narrator.name)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                }

                Button(action: start) {
                    Label(primaryTitle, systemImage: isLocked ? "lock.fill" : "play.fill")
                }
                .buttonStyle(.primary)

                actions

                if let error = downloads.lastError {
                    Text(error).font(.footnote).foregroundStyle(Theme.danger)
                }

                Text(item.summary)
                    .foregroundStyle(Theme.textMuted)

                if let series = catalog.series(for: item) {
                    episodes(of: series)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .miniPlayer()
        .sheet(isPresented: $isPlaylistPickerPresented) {
            PlaylistPickerView(contentID: item.id)
        }
    }

    private var primaryTitle: String {
        if isLocked { return "Unlock with Premium" }
        return item.kind == .breathing ? "Start" : "Play"
    }

    private var actions: some View {
        HStack(spacing: 12) {
            IconButton(
                symbol: favorites.isEmpty ? "heart" : "heart.fill",
                label: favorites.isEmpty ? "Add to favorites" : "Remove from favorites",
                isActive: !favorites.isEmpty,
                action: toggleFavorite
            )
            if item.kind != .breathing {
                if downloads.inProgress.contains(item.id) {
                    ProgressView().frame(width: 44, height: 44)
                } else {
                    IconButton(
                        symbol: download == nil ? "arrow.down.circle" : "checkmark.circle.fill",
                        label: download == nil ? "Download" : "Downloaded. Remove download",
                        isActive: download != nil
                    ) {
                        toggleDownload()
                    }
                    .disabled(isLocked)
                }
            }
            if item.kind.allowsPlaylists {
                IconButton(symbol: "text.badge.plus", label: "Add to playlist") {
                    isPlaylistPickerPresented = true
                }
            }
            Spacer()
        }
    }

    private func episodes(of series: Series) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(series.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.text)
            ForEach(catalog.items(inSeries: series.id)) { episode in
                NavigationLink(value: episode) {
                    ContentRow(
                        item: episode,
                        detail: "Episode \(episode.episode ?? 0) · \(episode.durationLabel)",
                        isLocked: !episode.isFree && !subscriptions.isPremium
                    )
                }
                .buttonStyle(.plain)
                .disabled(episode.id == item.id)
            }
        }
        .padding(.top, 8)
    }

    private func start() {
        if isLocked {
            router.isPaywallPresented = true
            return
        }
        if item.kind == .breathing {
            router.isBreathePresented = true
            return
        }
        guard let url = download.flatMap(DownloadService.localURL(for:)) ?? CatalogService.resolve(item.audio) else { return }
        player.play(item, from: url)
        router.isPlayerPresented = true
    }

    private func toggleFavorite() {
        if let favorite = favorites.first {
            context.delete(favorite)
        } else {
            context.insert(FavoriteRecord(contentID: item.id))
        }
        try? context.save()
    }

    private func toggleDownload() {
        if let download {
            downloads.remove(download, context: context)
        } else {
            Task { await downloads.download(item, context: context) }
        }
    }
}

struct PlaylistPickerView: View {
    let contentID: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlaylistRecord.createdAt) private var playlists: [PlaylistRecord]
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New playlist", text: $newName)
                            .submitLabel(.done)
                            .onSubmit(create)
                        Button("Add", action: create)
                            .disabled(trimmedName.isEmpty)
                    }
                }
                .listRowBackground(Theme.surface)

                if !playlists.isEmpty {
                    Section("Your playlists") {
                        ForEach(playlists) { playlist in
                            Button {
                                toggle(playlist)
                            } label: {
                                HStack {
                                    Text(playlist.name).foregroundStyle(Theme.text)
                                    Spacer()
                                    if playlist.itemIDs.contains(contentID) {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Add to playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        context.insert(PlaylistRecord(name: trimmedName, itemIDs: [contentID]))
        try? context.save()
        newName = ""
    }

    private func toggle(_ playlist: PlaylistRecord) {
        if playlist.itemIDs.contains(contentID) {
            playlist.itemIDs.removeAll { $0 == contentID }
        } else {
            playlist.itemIDs.append(contentID)
        }
        try? context.save()
    }
}
