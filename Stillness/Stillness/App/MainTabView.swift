import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(PlayerController.self) private var player
    @Environment(ScenePlayer.self) private var scenes
    @Environment(CatalogService.self) private var catalog
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(HealthService.self) private var health
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Keys.healthEnabled) private var healthEnabled = false
    @AppStorage(Keys.sceneAfterMinutes) private var sceneAfterMinutes = 15
    @AppStorage(Keys.selectedSceneID) private var selectedSceneID = "dusk"

    var body: some View {
        @Bindable var router = router

        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
            NavigationStack { BrowseView(title: "Sleep", kinds: [.sleepStory, .soundscape]) }
                .tabItem { Label("Sleep", systemImage: "moon.stars") }
            NavigationStack { BrowseView(title: "Meditate", kinds: [.meditation, .breathing]) }
                .tabItem { Label("Meditate", systemImage: "leaf") }
            NavigationStack { BrowseView(title: "Music", kinds: [.music]) }
                .tabItem { Label("Music", systemImage: "music.note") }
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .fullScreenCover(isPresented: $router.isPlayerPresented) { PlayerView() }
        .fullScreenCover(isPresented: $router.isBreathePresented) { BreatheView() }
        .sheet(isPresented: $router.isPaywallPresented) { PaywallView() }
        .sheet(isPresented: $router.isScenePickerPresented) {
            ScenePickerView().presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $router.isCheckInPresented) { CheckInView() }
        .onAppear {
            player.onSessionEnded = { item, startedAt, seconds, completed in
                SessionLogger(context: context, health: health, healthEnabled: healthEnabled)
                    .log(contentID: item.id, kind: item.kind, startedAt: startedAt, seconds: seconds, completed: completed)
            }
            startSelectedScene()
        }
        .onChange(of: player.isPlaying) { _, playing in
            scenes.isDucked = playing
            if !playing && scenePhase == .background {
                scenes.stop(afterMinutes: sceneAfterMinutes)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if !player.isPlaying { scenes.stop(afterMinutes: sceneAfterMinutes) }
            case .active:
                scenes.cancelScheduledStop()
                startSelectedScene()
            default:
                break
            }
        }
    }

    private func startSelectedScene() {
        guard let scene = catalog.scene(id: selectedSceneID), scene.isFree || subscriptions.isPremium else { return }
        scenes.play(scene)
    }
}

/// Saves a finished or stopped session and, if the user turned it on, writes it to Apple Health.
@MainActor
struct SessionLogger {
    let context: ModelContext
    let health: HealthService
    let healthEnabled: Bool

    func log(contentID: String, kind: ContentKind, startedAt: Date, seconds: Double, completed: Bool) {
        guard completed || seconds >= 5 else { return }
        context.insert(SessionRecord(
            contentID: contentID,
            kind: kind,
            startedAt: startedAt,
            secondsListened: seconds,
            completed: completed
        ))
        try? context.save()

        guard healthEnabled, kind.countsAsMindful, seconds >= 1 else { return }
        let end = startedAt.addingTimeInterval(seconds)
        Task { await health.logMindfulSession(start: startedAt, end: end) }
    }
}
