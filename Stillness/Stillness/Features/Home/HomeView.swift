import SwiftUI
import SwiftData

/// S07. Today's session, quick actions, and rows picked from the user's goals.
struct HomeView: View {
    @Environment(CatalogService.self) private var catalog
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(AppRouter.self) private var router
    @AppStorage(Keys.goals) private var goalsRaw = ""
    @Query(sort: \SessionRecord.startedAt, order: .reverse) private var sessions: [SessionRecord]

    private var streak: StreakSummary {
        StreakCalculator.summary(activeDays: sessions.filter(\.countsTowardStreak).map(\.startedAt))
    }

    private var goalTopics: [Topic] {
        let ids = Set(goalsRaw.split(separator: ",").map(String.init))
        let chosen = catalog.topics.filter { ids.contains($0.id) }
        return chosen.isEmpty ? Array(catalog.topics.prefix(3)) : chosen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .firstTextBaseline) {
                    Text(greeting)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    StreakBadge(days: streak.current)
                }

                if let daily = catalog.dailyItem() {
                    NavigationLink(value: daily) {
                        DailyHeroCard(item: daily, isLocked: !daily.isFree && !subscriptions.isPremium)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    QuickActionCard(title: "Breathe", subtitle: "1 minute", symbol: "wind") {
                        router.isBreathePresented = true
                    }
                    QuickActionCard(title: "Check in", subtitle: "How are you?", symbol: "face.smiling") {
                        router.isCheckInPresented = true
                    }
                }

                ForEach(goalTopics) { topic in
                    let items = catalog.items(kinds: [.meditation, .sleepStory, .music, .soundscape], topic: topic.id)
                    if !items.isEmpty {
                        CarouselRow(title: "For \(topic.title.lowercased())", items: items)
                    }
                }

                CarouselRow(title: "Sleep stories", items: catalog.items(kinds: [.sleepStory]))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(SceneBackdrop())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.isScenePickerPresented = true
                } label: {
                    Image(systemName: "mountain.2")
                }
                .accessibilityLabel("Scenes")
            }
        }
        .rootScreen()
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

private struct DailyHeroCard: View {
    let item: ContentItem
    let isLocked: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(colors: item.colors, symbol: item.symbol, symbolSize: 72)
                .frame(height: 220)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(item.kind.label) · \(item.durationLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
        .overlay(alignment: .topTrailing) {
            if isLocked { LockBadge().padding(12) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's session: \(item.title), \(item.durationLabel)")
    }
}

private struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Theme.text)
                    Text(subtitle).font(.caption).foregroundStyle(Theme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
        .buttonStyle(.plain)
    }
}
