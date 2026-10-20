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

    private let freeLimit = 2
//    private let freeLimit = appData.opnePremiumCount ?? 2

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

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
