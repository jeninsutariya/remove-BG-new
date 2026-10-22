import SwiftUI
import SwiftData

/// S17. Stats and the library.
struct ProfileView: View {
    @Environment(AuthService.self) private var auth
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(AppRouter.self) private var router
    @Query private var sessions: [SessionRecord]
    @Query private var favorites: [FavoriteRecord]
    @Query private var playlists: [PlaylistRecord]
    @Query private var downloads: [DownloadRecord]
    @Query private var checkIns: [CheckInRecord]

    private var streak: StreakSummary {
        StreakCalculator.summary(activeDays: sessions.filter(\.countsTowardStreak).map(\.startedAt))
    }

    private var mindfulMinutes: Int {
        Int(sessions.filter { $0.kind.countsAsMindful }.reduce(0) { $0 + $1.secondsListened } / 60)
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.displayName.map { "Hi, \($0)" } ?? "Your progress")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Theme.text)
                        Text(subscriptions.isPremium ? "Premium" : "Free plan")
                            .font(.subheadline)
                            .foregroundStyle(subscriptions.isPremium ? Theme.accent : Theme.textMuted)
                    }
                    Spacer()
                }

                if !subscriptions.isPremium {
                    Button("Go Premium") { router.isPaywallPresented = true }
                        .buttonStyle(.primary)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    StatTile(value: "\(streak.current)", label: "current streak")
                    StatTile(value: "\(streak.longest)", label: "longest streak")
                    StatTile(value: "\(sessions.count)", label: "sessions")
                    StatTile(value: "\(mindfulMinutes)", label: "mindful minutes")
                }

                VStack(spacing: 0) {
                    LibraryLink(title: "Favorites", symbol: "heart", count: favorites.count) { FavoritesView() }
                    Divider().overlay(Theme.border)
                    LibraryLink(title: "Playlists", symbol: "music.note.list", count: playlists.count) { PlaylistsView() }
                    Divider().overlay(Theme.border)
                    LibraryLink(title: "Downloads", symbol: "arrow.down.circle", count: downloads.count) { DownloadsView() }
                    Divider().overlay(Theme.border)
                    LibraryLink(title: "History", symbol: "clock", count: sessions.count) { HistoryView() }
                    Divider().overlay(Theme.border)
                    LibraryLink(title: "Check-ins", symbol: "face.smiling", count: checkIns.count) { CheckInHistoryView() }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .rootScreen()
    }
}

private struct LibraryLink<Destination: View>: View {
    let title: String
    let symbol: String
    let count: Int
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                Text(title).foregroundStyle(Theme.text)
                Spacer()
                Text("\(count)").foregroundStyle(Theme.textMuted).monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
