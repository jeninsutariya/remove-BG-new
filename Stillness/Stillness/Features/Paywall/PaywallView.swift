import SwiftUI
import StoreKit

/// S05. Shown at the end of onboarding and whenever a locked item is played.
/// App Review needs: the price, what renews and when, restore, a close button, terms and privacy links.
struct PaywallView: View {
    /// Onboarding passes this to move to the next step. Elsewhere the sheet dismisses itself.
    var onClose: (() -> Void)? = nil

    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?
    @State private var trialEligible: [String: Bool] = [:]
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedID }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    plans
                    purchaseButton
                    if let selectedProduct {
                        Text(finePrint(for: selectedProduct))
                            .font(.footnote)
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .multilineTextAlignment(.center)
                    }
                    footerLinks
                }
                .padding(24)
                .padding(.top, 36)
            }
            IconButton(symbol: "xmark", label: "Close", action: close)
                .padding(16)
        }
        .task {
            await store.loadProducts()
            if selectedID == nil {
                selectedID = store.products.first { $0.subscription?.subscriptionPeriod.unit == .year }?.id
                    ?? store.products.first?.id
            }
            for product in store.products {
                trialEligible[product.id] = await store.isEligibleForTrial(product)
            }
        }
        .onChange(of: store.isPremium) { _, premium in
            if premium { close() }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Unlock everything")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.text)
            VStack(alignment: .leading, spacing: 10) {
                Benefit(text: "Every sleep story, meditation and soundscape")
                Benefit(text: "New sessions added regularly")
                Benefit(text: "Download and listen offline")
                Benefit(text: "Every background scene")
            }
        }
    }

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            if store.loadFailed {
                Text("Plans couldn't load. Check your connection and try again.")
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView().padding()
            }
        } else {
            VStack(spacing: 12) {
                ForEach(store.products) { product in
                    PlanCard(
                        product: product,
                        isSelected: product.id == selectedID,
                        badge: trialBadge(for: product)
                    ) {
                        selectedID = product.id
                    }
                }
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            if isPurchasing {
                ProgressView().tint(Theme.onAccent)
            } else {
                Text(selectedProduct.map { trialBadge(for: $0) != nil } == true ? "Start free trial" : "Continue")
            }
        }
        .buttonStyle(.primary)
        .disabled(selectedProduct == nil || isPurchasing)
    }

    private var footerLinks: some View {
        HStack(spacing: 18) {
            Button("Restore") {
                Task { await store.restore() }
            }
            Link("Terms", destination: AppLinks.terms)
            Link("Privacy", destination: AppLinks.privacy)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Theme.textMuted)
    }

    private func trialBadge(for product: Product) -> String? {
        guard trialEligible[product.id] == true, let offer = product.subscription?.introductoryOffer else { return nil }
        return "\(offer.period.lengthLabel) free"
    }

    private func finePrint(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return "\(product.displayPrice), paid once. No subscription."
        }
        let renewal = "\(product.displayPrice) per \(period.perLabel)"
        if let offer = product.subscription?.introductoryOffer, trialBadge(for: product) != nil {
            return "Free for \(offer.period.lengthLabel), then \(renewal). Renews automatically. Cancel anytime in Settings at least a day before it renews."
        }
        return "\(renewal). Renews automatically. Cancel anytime in Settings at least a day before it renews."
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            if try await store.purchase(product) { close() }
        } catch {
            errorMessage = "The purchase didn't go through. You weren't charged. Please try again."
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}

private struct Benefit: View {
    let text: String

    var body: some View {
        Label {
            Text(text).foregroundStyle(Theme.text)
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
        }
    }
}

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent, in: Capsule())
                }
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var subtitle: String {
        if let period = product.subscription?.subscriptionPeriod {
            return "\(product.displayPrice) per \(period.perLabel)"
        }
        return "\(product.displayPrice) once"
    }
}
