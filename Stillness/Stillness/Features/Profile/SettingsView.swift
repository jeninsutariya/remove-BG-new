import SwiftUI
import SwiftData
import StoreKit
import AuthenticationServices
import UIKit

/// S19. Reminders, Apple Health, subscription, account and legal links.
struct SettingsView: View {
    @Environment(ReminderService.self) private var reminders
    @Environment(HealthService.self) private var health
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(AuthService.self) private var auth
    @Environment(DownloadService.self) private var downloads
    @Environment(PlayerController.self) private var player
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @AppStorage(Keys.healthEnabled) private var healthEnabled = false
    @AppStorage(Keys.hasOnboarded) private var hasOnboarded = true
    @State private var isManagingSubscription = false
    @State private var isConfirmingDelete = false

    var body: some View {
        Form {
            Section("Reminders") {
                ForEach(ReminderKind.allCases) { kind in
                    ReminderRow(kind: kind)
                }
                if reminders.permissionDenied {
                    Text("Notifications are turned off for this app.")
                        .foregroundStyle(Theme.textMuted)
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Save to Apple Health", isOn: Binding(
                    get: { healthEnabled && health.isAuthorized },
                    set: { newValue in
                        if newValue {
                            Task { healthEnabled = await health.requestAccess() }
                        } else {
                            healthEnabled = false
                        }
                    }
                ))
                .disabled(!health.isAvailable)
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Meditations, sleep stories and breathing are saved as mindful minutes. Music and scenes are not.")
            }
            .listRowBackground(Theme.surface)

            Section("Subscription") {
                LabeledContent("Plan", value: subscriptions.isPremium ? "Premium" : "Free")
                if subscriptions.isPremium {
                    Button("Manage subscription") { isManagingSubscription = true }
                } else {
                    Button("Go Premium") { router.isPaywallPresented = true }
                }
                Button("Restore purchases") {
                    Task { await subscriptions.restore() }
                }
            }
            .listRowBackground(Theme.surface)

            Section("Account") {
                if auth.isSignedIn {
                    LabeledContent("Signed in with Apple", value: auth.displayName ?? "")
                    Button("Sign out") { auth.signOut() }
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        auth.handle(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 44)
                }
                Button("Delete account and data", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
            .listRowBackground(Theme.surface)

            Section("About") {
                Link("Terms of use", destination: AppLinks.terms)
                Link("Privacy policy", destination: AppLinks.privacy)
                Link("Help and support", destination: AppLinks.support)
                LabeledContent("Version", value: Bundle.main.appVersion)
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        .confirmationDialog("Delete your account?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive, action: deleteEverything)
        } message: {
            Text("This removes your history, check-ins, favorites, playlists and downloads, and signs you out. It doesn't cancel a subscription. Do that in iPhone Settings, under your name, then Subscriptions.")
        }
        .onAppear { health.refreshStatus() }
    }

    /// Apple requires in-app account deletion. With no server, everything lives on the phone, so this clears it.
    /// When you add a backend, also delete the server account and revoke the Sign in with Apple token.
    private func deleteEverything() {
        player.stop()
        try? context.delete(model: SessionRecord.self)
        try? context.delete(model: CheckInRecord.self)
        try? context.delete(model: FavoriteRecord.self)
        try? context.delete(model: PlaylistRecord.self)
        try? context.delete(model: DownloadRecord.self)
        try? context.save()
        downloads.removeAll()
        auth.signOut()
        for kind in ReminderKind.allCases {
            Task { await reminders.update(kind, enabled: false) }
        }
        healthEnabled = false
        UserDefaults.standard.removeObject(forKey: Keys.goals)
        UserDefaults.standard.removeObject(forKey: Keys.experience)
        hasOnboarded = false
    }
}

private struct ReminderRow: View {
    let kind: ReminderKind
    @Environment(ReminderService.self) private var reminders

    var body: some View {
        let setting = reminders.setting(for: kind)
        VStack(alignment: .leading) {
            Toggle(kind.title, isOn: Binding(
                get: { setting.enabled },
                set: { enabled in Task { await reminders.update(kind, enabled: enabled) } }
            ))
            if setting.enabled {
                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { reminders.time(for: kind) },
                        set: { time in Task { await reminders.update(kind, time: time) } }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .foregroundStyle(Theme.textMuted)
            }
        }
    }
}
