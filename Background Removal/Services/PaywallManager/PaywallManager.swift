//
//  PaywallManager.swift
//  Live Football Score
//
//  Created by Jenin Sutariya on 17/01/26.
//

import Foundation
import UIKit

final class PaywallManager {

    static let shared = PaywallManager()
    private init() {}
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
    private let freeLimit = 2

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
        if count > freeLimit {

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

    // MARK: - Bulk Remove daily limit

    /// Free users can export this many different Bulk Remove images per day.
    static let bulkDailyLimit = 3
    private let bulkIDsKey = "bulk_export_ids"
    private let bulkDateKey = "bulk_export_date"

    /// Image IDs already exported today (the list resets on a new day).
    private func bulkExportedIDsToday() -> Set<String> {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: bulkDateKey) == todayString() else { return [] }
        return Set(defaults.stringArray(forKey: bulkIDsKey) ?? [])
    }

    /// Returns true = the export may run. Does not count anything: call `recordBulkExport`
    /// once the export actually succeeded. Re-exporting an image already counted today is free,
    /// so saving and then sharing the same images is never counted twice.
    /// Returns false = blocked, and the Premium screen is shown.
    func shouldAllowBulkExport(from vc: UIViewController, itemIDs: [UUID]) -> Bool {
        if UserDefaults.isPremiumUser { return true }
        let used = bulkExportedIDsToday()
        let total = used.union(itemIDs.map(\.uuidString)).count
        if total <= Self.bulkDailyLimit { return true }
        if vc.presentedViewController == nil {
            let paywallVC = ProUpgradeVC.fatchInstance()
            paywallVC.modalPresentationStyle = .fullScreen
            vc.present(paywallVC, animated: true)
        }
        return false
    }

    /// Counts the images of a successful Bulk Remove export (once per image per day).
    func recordBulkExport(itemIDs: [UUID]) {
        guard !UserDefaults.isPremiumUser else { return }
        let defaults = UserDefaults.standard
        let ids = bulkExportedIDsToday().union(itemIDs.map(\.uuidString))
        defaults.set(todayString(), forKey: bulkDateKey)
        defaults.set(Array(ids), forKey: bulkIDsKey)
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
