import StoreKit
import Observation

/// StoreKit 2. Premium comes from the user's current App Store entitlements on every launch.
@Observable @MainActor
final class SubscriptionStore {
    /// Must match the product IDs in App Store Connect and in Config/Products.storekit.
    static let productIDs = [
        "stillness.premium.yearly",
        "stillness.premium.monthly",
        "stillness.premium.lifetime",
    ]

    private(set) var products: [Product] = []
    private(set) var isPremium = false
    private(set) var loadFailed = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlements()
                }
            }
        }
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted {
                (Self.productIDs.firstIndex(of: $0.id) ?? 0) < (Self.productIDs.firstIndex(of: $1.id) ?? 0)
            }
            loadFailed = loaded.isEmpty
        } catch {
            loadFailed = true
        }
    }

    /// Returns true when the purchase went through. Cancelled and pending purchases return false.
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                premium = true
            }
        }
        isPremium = premium
    }

    func isEligibleForTrial(_ product: Product) async -> Bool {
        guard let subscription = product.subscription,
              subscription.introductoryOffer?.paymentMode == .freeTrial else { return false }
        return await subscription.isEligibleForIntroOffer
    }
}

extension Product.SubscriptionPeriod {
    /// "year", "month", or "3 months" for use after "per".
    var perLabel: String {
        value == 1 ? unitName(plural: false) : "\(value) \(unitName(plural: true))"
    }

    /// "1 week", "3 days".
    var lengthLabel: String {
        "\(value) \(unitName(plural: value != 1))"
    }

    private func unitName(plural: Bool) -> String {
        switch unit {
        case .day: return plural ? "days" : "day"
        case .week: return plural ? "weeks" : "week"
        case .month: return plural ? "months" : "month"
        case .year: return plural ? "years" : "year"
        @unknown default: return plural ? "periods" : "period"
        }
    }
}
