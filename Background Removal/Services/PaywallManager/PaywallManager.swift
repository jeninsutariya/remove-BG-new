//
//  PaywallManager.swift
//  Live Football Score
//
//  Created by Jenin Sutariya on 17/01/26.
//
//  The one place that decides whether a free user may use a feature today.
//
//  • Every feature has its own daily counter (local calendar day, persisted).
//  • A use is recorded only when the operation succeeded / was committed – never when a
//    screen opens or a preview renders. Work that runs over time (background removal) first
//    reserves a use and confirms it on success, so nothing is counted twice or for a failure.
//  • Premium users (verified by PurchaseConnector) are never limited.
//

import Foundation
import UIKit

/// Features with a daily free limit.
enum PaywallFeature: String, CaseIterable {
    case singleBackgroundRemoval
    case bulkBackgroundRemoval
    case changeBackground
    case textBehindSubject

    /// The removal feature a project's processing counts against (nil: the removal is part
    /// of Change Background / Text Behind, which count their committed edits instead).
    static func backgroundRemoval(for mode: EditorMode, isBatch: Bool) -> PaywallFeature? {
        guard mode == .removeBackground else { return nil }
        return isBatch ? .bulkBackgroundRemoval : .singleBackgroundRemoval
    }
}

final class PaywallManager {

    static let shared = PaywallManager()
    private init() {}

    /// Free uses per day (change here to configure the limits).
    private static let defaultFreeLimit = 3
    private let freeLimits: [PaywallFeature: Int] = [
        .singleBackgroundRemoval: 3,
        .bulkBackgroundRemoval: 3,
        .changeBackground: 3,
        .textBehindSubject: 3
    ]
//    private let freeLimit = appData.opnePremiumCount ?? 2

    func freeLimit(for feature: PaywallFeature) -> Int {
        freeLimits[feature] ?? Self.defaultFreeLimit
    }

    /// Uses reserved by operations that are still running (not persisted: a reservation that
    /// never finished – e.g. the app was killed – must not cost the user a use).
    private var reserved: [PaywallFeature: Int] = [:]

    // MARK: - Premium

    /// Premium state from the last StoreKit receipt verification. A subscription whose verified
    /// expiry date has passed is treated as expired until the receipt is verified again.
    var isPremium: Bool {
        guard UserDefaults.isPremiumUser else { return false }
        if let expiry = PurchaseConnector.shared.verifiedExpiryDate, expiry <= Date() {
            UserDefaults.isPremiumUser = false
            // A renewal may exist: verify again (posts .refreshPremiumLog when done).
            PurchaseConnector.shared.checkPremiumStatus()
            return false
        }
        return true
    }

    // MARK: - Daily counters

    private func countKey(_ feature: PaywallFeature) -> String { "paywall_count_" + feature.rawValue }
    private func dayKey(_ feature: PaywallFeature) -> String { "paywall_day_" + feature.rawValue }

    /// Successful uses today (resets when the local calendar day changes).
    func usedToday(_ feature: PaywallFeature) -> Int {
        let defaults = UserDefaults.standard
        guard let day = defaults.object(forKey: dayKey(feature)) as? Date,
              Calendar.current.isDateInToday(day) else { return 0 }
        return defaults.integer(forKey: countKey(feature))
    }

    /// Free uses left today, minus running reservations (`Int.max` for premium users).
    func remainingFreeUses(_ feature: PaywallFeature) -> Int {
        if isPremium { return Int.max }
        return max(0, freeLimit(for: feature) - usedToday(feature) - (reserved[feature] ?? 0))
    }

    func canUse(_ feature: PaywallFeature, count: Int = 1) -> Bool {
        remainingFreeUses(feature) >= count
    }

    /// Records `count` successful uses (ignored for premium users).
    func recordUse(_ feature: PaywallFeature, count: Int = 1) {
        guard count > 0, !isPremium else { return }
        let defaults = UserDefaults.standard
        defaults.set(usedToday(feature) + count, forKey: countKey(feature))
        defaults.set(Date(), forKey: dayKey(feature))
    }

    // MARK: - Reservations (operations that finish later)

    /// Reserves one use before a long operation starts. false = no free use left.
    func reserve(_ feature: PaywallFeature) -> Bool {
        guard canUse(feature) else { return false }
        reserved[feature, default: 0] += 1
        return true
    }

    /// The reserved operation succeeded: the use is counted.
    func confirmReservation(_ feature: PaywallFeature) {
        releaseReservation(feature)
        recordUse(feature)
    }

    /// The reserved operation failed or was cancelled: nothing is counted.
    func releaseReservation(_ feature: PaywallFeature) {
        reserved[feature] = max(0, (reserved[feature] ?? 0) - 1)
    }

    // MARK: - Paywall

    static let limitReachedMessage = "You've used today's free background removals. Upgrade to Pro for unlimited removals."

    /// Calls `completion` with how many of `count` uses may run now. When the free uses
    /// don't cover `count`, the paywall is shown first; after a verified purchase all of
    /// them are allowed, otherwise only what is left of today's free uses (possibly 0).
    func requestAccess(_ feature: PaywallFeature, count: Int = 1, from vc: UIViewController,
                       completion: @escaping (_ allowed: Int) -> Void) {
        guard count > 0 else { return completion(0) }
        if canUse(feature, count: count) { return completion(count) }
        presentPaywall(from: vc) { [weak self] unlocked in
            guard let self else { return }
            completion(unlocked ? count : min(count, self.remainingFreeUses(feature)))
        }
    }

    // MARK: - Exports (Change Background / Text Behind Subject)

    /// Exporting an item of a Change Background / Text Behind project whose use was never
    /// counted (nothing committed) costs one use, so the result can't be taken without one.
    /// `completion(true)` = the export may run; call `recordExport` after it succeeded.
    func requestExportAccess(for ids: [UUID], in viewModel: BackgroundRemovalViewModel, from vc: UIViewController,
                             completion: @escaping (_ allowed: Bool) -> Void) {
        let uncounted = ids.filter { viewModel.item($0)?.usageCounted == false }
        guard let feature = viewModel.editFeature, !uncounted.isEmpty else { return completion(true) }
        requestAccess(feature, count: uncounted.count, from: vc) { allowed in
            completion(allowed == uncounted.count)
        }
    }

    func recordExport(of ids: [UUID], in viewModel: BackgroundRemovalViewModel) {
        let uncounted = ids.filter { viewModel.item($0)?.usageCounted == false }
        guard let feature = viewModel.editFeature, !uncounted.isEmpty else { return }
        recordUse(feature, count: uncounted.count)
        viewModel.markUsageCounted(uncounted)
    }

    /// Shows the In-App Purchase screen. `completion(true)` only when premium was verified
    /// (purchase or restore) by the time the screen closed.
    func presentPaywall(from vc: UIViewController, completion: ((_ unlocked: Bool) -> Void)? = nil) {
        var top = vc
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        if top.presentedViewController != nil {
            // A sheet is still closing (e.g. the photo picker): present once it is gone.
            let retry = { [weak self] in
                DispatchQueue.main.async { self?.presentPaywall(from: top, completion: completion) }
            }
            if let coordinator = top.presentedViewController?.transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { _ in retry() }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { retry() }
            }
            return
        }
        if let open = top as? ProUpgradeVC {
            // Already showing: report when that one closes.
            let previous = open.onClose
            open.onClose = { unlocked in
                previous?(unlocked)
                completion?(unlocked)
            }
            return
        }
        let paywallVC = ProUpgradeVC.fatchInstance()
        paywallVC.modalPresentationStyle = .fullScreen
        paywallVC.onClose = completion
        top.present(paywallVC, animated: true)
    }

    /// Returns true = allow action
    /// Returns false = block action (show paywall)
    func shouldAllowAction(
        from vc: UIViewController,
        key: String
    ) -> Bool {

        let defaults = UserDefaults.standard

        // Premium users always allowed
        if UserDefaults.isPremiumUser { return true }

        let countKey = "paywall_count_" + key
        let dateKey  = "paywall_date_" + key

        let today = todayString()

        // Reset if new day
        if defaults.string(forKey: dateKey) != today {
            defaults.set(0, forKey: countKey)
            defaults.set(today, forKey: dateKey)
        }

        // Increase count
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        print("KEY:", key, "COUNT:", count)

        // 🚫 Block from 4th click onwards
        if count > Self.defaultFreeLimit {

            // Show paywall once per tap
            if vc.presentedViewController == nil {
                let paywallVC = ProUpgradeVC.fatchInstance()
                paywallVC.modalPresentationStyle = .fullScreen
                vc.present(paywallVC, animated: true)
            }

            return false   // ❌ DO NOT perform action
        }

        return true        // ✅ Perform action
    }
    func shouldOnwTimeAllowAction(
        from vc: UIViewController,
        key: String
    ) -> Bool {

        let defaults = UserDefaults.standard

        // Premium users always allowed
        if UserDefaults.isPremiumUser { return true }

        let countKey = "paywall_count_" + key
        let dateKey  = "paywall_date_" + key

        let today = todayString()

        // Reset if new day
        if defaults.string(forKey: dateKey) != today {
            defaults.set(0, forKey: countKey)
            defaults.set(today, forKey: dateKey)
        }

        // Increase count
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        print("KEY:", key, "COUNT:", count)

        // 🚫 Block from 4th click onwards
        if count > 1 {

            // Show paywall once per tap
            if vc.presentedViewController == nil {
                let paywallVC = ProUpgradeVC.fatchInstance()
                paywallVC.modalPresentationStyle = .fullScreen
                vc.present(paywallVC, animated: true)
            }

            return false   // ❌ DO NOT perform action
        }

        return true        // ✅ Perform action
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
