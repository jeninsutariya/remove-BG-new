//
//  PremiumManager.swift
//  Background Removal
//
//  Central premium entitlement + export-quality decision.
//
//  • Real entitlement comes only from StoreKit 2 verified transactions.
//  • DEBUG builds can force premium with `debugOverrideEnabled` (compiled out of Release).
//  • `exportQuality` is what every export path uses.
//

import Foundation
import StoreKit

final class PremiumManager {

    static let shared = PremiumManager()
    static let didChangeNotification = Notification.Name("PremiumManagerDidChange")

    /// App Store Connect product ids (auto-renewable subscriptions). Index 0 = yearly, 1 = monthly,
    /// matching the rows of ProUpgradeVC. Update these if your product ids differ.
    static let productIDs = [
        "com.demo.test.tech.pro.yearly",
        "com.demo.test.tech.pro.monthly"
    ]

    enum PurchaseError: LocalizedError {
        case productUnavailable
        case pending
        case unverified

        var errorDescription: String? {
            switch self {
            case .productUnavailable: return "This subscription isn't available right now. Please try again later."
            case .pending: return "Your purchase is waiting for approval."
            case .unverified: return "The purchase couldn't be verified by the App Store."
            }
        }
    }

    /// Verified StoreKit entitlement (never set by UI code).
    private(set) var hasActiveEntitlement = false
    private(set) var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?
    private var started = false

    private init() {}

    // MARK: - Effective state

    var isPremium: Bool {
        #if DEBUG
        return hasActiveEntitlement || debugOverrideEnabled
        #else
        return hasActiveEntitlement
        #endif
    }

    /// The quality every export (Gallery and ZIP) must use.
    var exportQuality: ExportQuality { isPremium ? .full : .standard }

    #if DEBUG
    private static let debugOverrideKey = "debug.premiumOverrideEnabled"

    /// Developer-only switch. Not present in Release builds.
    var debugOverrideEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.debugOverrideKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.debugOverrideKey)
            notify()
        }
    }
    #endif

    // MARK: - StoreKit

    func start() {
        guard !started else { return }
        started = true
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard let loaded = try? await Product.products(for: Self.productIDs) else { return }
        var map: [String: Product] = [:]
        for product in loaded { map[product.id] = product }
        products = map
        notify()
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }
            active = true
        }
        hasActiveEntitlement = active
        // Keep the app's existing flag in sync (read-only mirror of the verified state).
        UserDefaults.isPremiumUser = active
        notify()
    }

    /// Returns true only when the App Store confirmed the purchase.
    func purchase(productID: String) async throws -> Bool {
        if products[productID] == nil { await loadProducts() }
        guard let product = products[productID] else { throw PurchaseError.productUnavailable }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw PurchaseError.unverified }
            await transaction.finish()
            await refreshEntitlements()
            return hasActiveEntitlement
        case .pending:
            throw PurchaseError.pending
        case .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func displayPrice(for productID: String) -> String? {
        products[productID]?.displayPrice
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
