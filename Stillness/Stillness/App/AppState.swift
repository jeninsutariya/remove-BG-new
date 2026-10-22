import Foundation
import Observation

/// Which full-screen views and sheets are showing. Lives above the tab bar so any screen can open them.
@Observable @MainActor
final class AppRouter {
    var isPlayerPresented = false
    var isPaywallPresented = false
    var isScenePickerPresented = false
    var isBreathePresented = false
    var isCheckInPresented = false
}

/// UserDefaults keys, shared by `@AppStorage` in views and by services.
enum Keys {
    static let hasOnboarded = "hasOnboarded"
    static let goals = "goals"
    static let experience = "experience"
    static let selectedSceneID = "selectedSceneID"
    static let sceneAfterMinutes = "sceneAfterMinutes"
    static let healthEnabled = "healthEnabled"
    static let reminders = "reminders"
    static let appleUserID = "appleUserID"
    static let displayName = "displayName"
}

/// Replace these before you submit to the App Store. App Review checks that they work.
enum AppLinks {
    static let terms = URL(string: "https://example.com/terms")!
    static let privacy = URL(string: "https://example.com/privacy")!
    static let support = URL(string: "https://example.com/support")!
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
