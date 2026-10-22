import SwiftUI
import SwiftData

/// S12, with S13 (session complete) shown in place when a session plays to the end.
struct PlayerView: View {
    @Environment(PlayerController.self) private var player
    @Environment(CatalogService.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var favorites: [FavoriteRecord]
    @State private var scrubbing: Double?
    @State private var isPlaylistPickerPresented = false
    @State private var isScenePickerPresented = false

    var body: some View {
        ZStack {
            SceneBackdrop()
            if let item = player.current {
                if player.finishedItem?.id == item.id {
                    SessionCompleteView(item: item) {
                        player.stop()
                        dismiss()
                    }
                } else {
                    controls(for: item)
                }
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
    }

    private func controls(for item: ContentItem) -> some View {
        let isFavorite = favorites.contains { $0.contentID == item.id }
        let position = scrubbing ?? player.currentTime

        return VStack(spacing: 26) {
            HStack {
                IconButton(symbol: "chevron.down", label: "Minimize") { dismiss() }
                Spacer()
                sleepTimerMenu
            }

            Spacer(minLength: 0)

            ArtworkView(colors: item.colors, symbol: item.symbol, symbolSize: 72)
                .frame(width: 250, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
                .shadow(color: .black.opacity(0.4), radius: 30, y: 12)

            VStack(spacing: 6) {
                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                if let narrator = catalog.narrator(for: item) {
                    Text(narrator.name).foregroundStyle(Theme.textMuted)
                }
            }

            if !item.kind.loops {
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(get: { position }, set: { scrubbing = $0 }),
                        in: 0...max(player.duration, 1),
                        onEditingChanged: { editing in
                            if !editing, let target = scrubbing {
                                player.seek(to: target)
                                scrubbing = nil
                            }
                        }
                    )
                    .tint(Theme.accent)
                    .accessibilityLabel("Position")
                    HStack {
                        Text(Self.format(position))
                        Spacer()
                        Text("-" + Self.format(max(0, player.duration - position)))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textMuted)
                }
            }

            HStack(spacing: 44) {
                if !item.kind.loops {
                    Button { player.skip(by: -15) } label: {
                        Image(systemName: "gobackward.15").font(.title)
                    }
                    .accessibilityLabel("Back 15 seconds")
                }
                Button { player.togglePlayPause() } label: {
                    ZStack {
                        Circle().fill(Theme.accent).frame(width: 78, height: 78)
                        if player.isBuffering {
                            ProgressView().tint(Theme.onAccent)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(Theme.onAccent)
                        }
                    }
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                if !item.kind.loops {
                    Button { player.skip(by: 15) } label: {
                        Image(systemName: "goforward.15").font(.title)
                    }
                    .accessibilityLabel("Forward 15 seconds")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.text)

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                IconButton(
                    symbol: isFavorite ? "heart.fill" : "heart",
                    label: isFavorite ? "Remove from favorites" : "Add to favorites",
                    isActive: isFavorite
                ) {
                    toggleFavorite(item)
                }
                if item.kind.allowsPlaylists {
                    IconButton(symbol: "text.badge.plus", label: "Add to playlist") {
                        isPlaylistPickerPresented = true
                    }
                }
                IconButton(symbol: "mountain.2", label: "Scenes") {
                    isScenePickerPresented = true
                }
                ShareLink(item: "I'm listening to \(item.title).") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 44, height: 44)
                        .background(Theme.surface.opacity(0.8), in: Circle())
                }
                .accessibilityLabel("Share")
            }
        }
        .padding(24)
        .sheet(isPresented: $isPlaylistPickerPresented) {
            PlaylistPickerView(contentID: item.id)
        }
        .sheet(isPresented: $isScenePickerPresented) {
            ScenePickerView().presentationDetents([.medium, .large])
        }
    }

    private var sleepTimerMenu: some View {
        Menu {
            Button("Off") { player.setSleepTimer(minutes: nil) }
            ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                Button("\(minutes) minutes") { player.setSleepTimer(minutes: minutes) }
            }
        } label: {
            Label(
                player.sleepTimerEndsAt.map { "Stops \($0.formatted(date: .omitted, time: .shortened))" } ?? "Sleep timer",
                systemImage: "timer"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(player.sleepTimerEndsAt == nil ? Theme.text : Theme.accent)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Theme.surface.opacity(0.8), in: Capsule())
        }
    }

    private func toggleFavorite(_ item: ContentItem) {
        if let favorite = favorites.first(where: { $0.contentID == item.id }) {
            context.delete(favorite)
        } else {
            context.insert(FavoriteRecord(contentID: item.id))
        }
        try? context.save()
    }

    static func format(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}

/// S13. A small reward after each session, and a nudge to check in.
struct SessionCompleteView: View {
    let item: ContentItem
    let onDone: () -> Void

    @Environment(AppRouter.self) private var router
    @Query private var sessions: [SessionRecord]

    var body: some View {
        let streak = StreakCalculator.summary(activeDays: sessions.filter(\.countsTowardStreak).map(\.startedAt))
        let minutes = Int(sessions.filter { $0.kind.countsAsMindful }.reduce(0) { $0 + $1.secondsListened } / 60)

        VStack(spacing: 26) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Nicely done")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.text)
            Text(item.title)
                .foregroundStyle(Theme.textMuted)
            HStack(spacing: 12) {
                StatTile(value: "\(streak.current)", label: streak.current == 1 ? "day in a row" : "days in a row")
                StatTile(value: "\(minutes)", label: "mindful minutes")
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(.primary)
            Button("How do you feel now?") {
                onDone()
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    router.isCheckInPresented = true
                }
            }
            .foregroundStyle(Theme.textMuted)
            .padding(.vertical, 6)
        }
        .padding(24)
    }
}
