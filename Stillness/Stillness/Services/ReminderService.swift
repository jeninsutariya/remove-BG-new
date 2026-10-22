import Foundation
import Observation
import UserNotifications

enum ReminderKind: String, CaseIterable, Identifiable {
    case mindfulness
    case bedtime
    case mood
    case gratitude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mindfulness: return "Daily session"
        case .bedtime: return "Bedtime"
        case .mood: return "Mood check-in"
        case .gratitude: return "Gratitude"
        }
    }

    var message: String {
        switch self {
        case .mindfulness: return "A few quiet minutes are waiting for you."
        case .bedtime: return "Time to wind down. Pick a sleep story and get comfortable."
        case .mood: return "How are you feeling right now? Take a moment to check in."
        case .gratitude: return "What went well today? Write it down."
        }
    }

    var defaultHour: Int {
        switch self {
        case .mindfulness: return 8
        case .bedtime: return 22
        case .mood: return 13
        case .gratitude: return 20
        }
    }
}

struct ReminderSetting: Codable, Equatable {
    var enabled: Bool
    var hour: Int
    var minute: Int
}

/// Local, repeating daily notifications. No push server needed.
@Observable @MainActor
final class ReminderService {
    private(set) var settings: [String: ReminderSetting] = [:]
    private(set) var permissionDenied = false

    private let center = UNUserNotificationCenter.current()

    init() {
        if let data = UserDefaults.standard.data(forKey: Keys.reminders),
           let saved = try? JSONDecoder().decode([String: ReminderSetting].self, from: data) {
            settings = saved
        }
    }

    func setting(for kind: ReminderKind) -> ReminderSetting {
        settings[kind.rawValue] ?? ReminderSetting(enabled: false, hour: kind.defaultHour, minute: 0)
    }

    func time(for kind: ReminderKind) -> Date {
        let setting = setting(for: kind)
        return Calendar.current.date(bySettingHour: setting.hour, minute: setting.minute, second: 0, of: .now) ?? .now
    }

    func update(_ kind: ReminderKind, enabled: Bool? = nil, time: Date? = nil) async {
        var setting = setting(for: kind)
        if let enabled { setting.enabled = enabled }
        if let time {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            setting.hour = parts.hour ?? setting.hour
            setting.minute = parts.minute ?? setting.minute
        }
        if setting.enabled, !(await requestPermission()) {
            setting.enabled = false
        }
        settings[kind.rawValue] = setting
        save()
        schedule(kind, setting: setting)
    }

    func requestPermission() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        permissionDenied = !granted
        return granted
    }

    private func schedule(_ kind: ReminderKind, setting: ReminderSetting) {
        center.removePendingNotificationRequests(withIdentifiers: [kind.rawValue])
        guard setting.enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.message
        content.sound = .default

        var when = DateComponents()
        when.hour = setting.hour
        when.minute = setting.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: trigger), withCompletionHandler: nil)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Keys.reminders)
        }
    }
}
