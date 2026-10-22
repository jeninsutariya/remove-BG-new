import HealthKit
import Observation

/// Writes guided sessions to Apple Health as mindful minutes. Reads nothing.
@Observable @MainActor
final class HealthService {
    private(set) var isAuthorized = false

    private let store = HKHealthStore()
    private let mindfulType = HKCategoryType(.mindfulSession)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func refreshStatus() {
        isAuthorized = isAvailable && store.authorizationStatus(for: mindfulType) == .sharingAuthorized
    }

    func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [mindfulType], read: [])
        } catch {
            print("HealthKit authorization error: \(error)")
        }
        refreshStatus()
        return isAuthorized
    }

    func logMindfulSession(start: Date, end: Date) async {
        guard isAuthorized, end > start else { return }
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )
        do {
            try await store.save(sample)
        } catch {
            print("HealthKit save error: \(error)")
        }
    }
}
