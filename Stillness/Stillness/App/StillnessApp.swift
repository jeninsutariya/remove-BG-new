import SwiftUI
import SwiftData

@main
struct StillnessApp: App {
    @State private var catalog = CatalogService()
    @State private var player = PlayerController()
    @State private var scenes = ScenePlayer()
    @State private var subscriptions = SubscriptionStore()
    @State private var router = AppRouter()
    @State private var reminders = ReminderService()
    @State private var downloads = DownloadService()
    @State private var health = HealthService()
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalog)
                .environment(player)
                .environment(scenes)
                .environment(subscriptions)
                .environment(router)
                .environment(reminders)
                .environment(downloads)
                .environment(health)
                .environment(auth)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    health.refreshStatus()
                    await subscriptions.start()
                    await auth.refreshCredentialState()
                }
        }
        .modelContainer(for: [
            SessionRecord.self,
            CheckInRecord.self,
            FavoriteRecord.self,
            PlaylistRecord.self,
            DownloadRecord.self,
        ])
    }
}
