import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: ProductID = .annual
    @State private var purchaseError: String?
    @State private var restoreMessage: String?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    featuresSection

                    switch subscriptionManager.loadState {
                    case .loading:
                        loadingPlans
                    case .failed(let message):
                        unavailablePlans(message)
                    case .loaded:
                        planCards
                        purchaseButton
                        subscriptionTerms
                    }

                    restoreLink
                    legalLinks
                }
                .padding(32)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .padding(12)
                }
                Spacer()
            }

            if subscriptionManager.isLoading {
                loadingOverlay
            }
        }
        .frame(width: 480, height: 680)
        .alert("Purchase Error", isPresented: .init(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
        .alert("Restore Purchases", isPresented: .init(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) {
            Button("OK") { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .alert("Purchase Pending", isPresented: .init(
            get: { subscriptionManager.pendingPurchaseMessage != nil },
            set: { if !$0 { subscriptionManager.pendingPurchaseMessage = nil } }
        )) {
            Button("OK") { subscriptionManager.pendingPurchaseMessage = nil }
        } message: {
            Text(subscriptionManager.pendingPurchaseMessage ?? "")
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Unlock Watchdog Pro")
                .font(.system(size: 28, weight: .bold))

            Text("Get the most out of your security monitoring")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 12) {
            ForEach(ProFeature.allCases, id: \.rawValue) { feature in
                featureRow(feature)
            }
        }
    }

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Text(feature.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Plan States

    private var loadingPlans: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Loading plans…")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    /// Shown instead of the plan cards when StoreKit hasn't returned products.
    ///
    /// Deliberately does *not* fall back to placeholder prices: a hardcoded "$29.99" is
    /// wrong in every storefront that isn't the US, and quoting a price the user won't be
    /// charged is a 2.3.1 rejection.
    private func unavailablePlans(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22))
                .foregroundColor(.secondary)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try Again") {
                Task { await subscriptionManager.loadProducts() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        HStack(spacing: 12) {
            planCard(for: .monthly)
            planCard(for: .annual)
        }
        .padding(.top, 4)
    }

    private func planCard(for id: ProductID) -> some View {
        let product = subscriptionManager.product(for: id)
        let isSelected = selectedPlan == id
        let isRecommended = id == .annual

        return VStack(spacing: 8) {
            if isRecommended {
                Text("RECOMMENDED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }

            Text(id == .monthly ? "Monthly" : "Annual")
                .font(.system(size: 15, weight: .semibold))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(product?.displayPrice ?? "—")
                    .font(.system(size: 22, weight: .bold))
                Text(id == .monthly ? "/month" : "/year")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            ForEach(badges(for: id), id: \.self) { badge in
                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isRecommended ? .accentColor : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPlan = id
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Both badges are derived from live StoreKit data. The trial badge appears only when
    /// App Store Connect actually has an introductory offer on the annual product *and*
    /// this Apple Account can still redeem it — advertising a trial the user has already
    /// used, or that was never configured, is false advertising under 2.3.1.
    private func badges(for id: ProductID) -> [String] {
        guard id == .annual else { return [] }

        var badges: [String] = []
        if let trial = subscriptionManager.redeemableAnnualIntroOffer?.freeTrialDescription {
            badges.append(trial)
        }
        if let percent = subscriptionManager.annualSavingsPercent {
            badges.append("Save \(percent)%")
        }
        return badges
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task {
                guard let product = subscriptionManager.product(for: selectedPlan) else { return }
                do {
                    try await subscriptionManager.purchase(product)
                    if subscriptionManager.isProUser {
                        dismiss()
                    }
                } catch {
                    purchaseError = error.localizedDescription
                }
            }
        } label: {
            Text(subscribeButtonTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.isLoading || subscriptionManager.product(for: selectedPlan) == nil)
    }

    private var subscribeButtonTitle: String {
        if selectedPlan == .annual, subscriptionManager.redeemableAnnualIntroOffer != nil {
            return "Start Free Trial"
        }
        return "Subscribe Now"
    }

    // MARK: - Required Disclosures

    /// App Review guideline 3.1.2 requires the purchase screen to state the subscription
    /// length, the price per period, the free-trial terms, and that it auto-renews —
    /// alongside functional Terms of Use and Privacy Policy links (below). Do not remove.
    private var subscriptionTerms: some View {
        Text(termsText)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    private var termsText: String {
        let renewalTerms = """
        Payment is charged to your Apple Account at confirmation of purchase. The \
        subscription renews automatically unless cancelled at least 24 hours before the end \
        of the current period, and your account is charged for renewal within 24 hours of \
        the period ending. Manage or cancel anytime in System Settings → Apple Account → \
        Media & Purchases → Subscriptions.
        """

        guard let product = subscriptionManager.product(for: selectedPlan) else {
            return renewalTerms
        }

        let period = product.subscription?.subscriptionPeriod.unit == .year ? "year" : "month"

        // Trial wording is emitted only when there is a redeemable offer, and it names the
        // price the trial converts to — 3.1.2 requires the conversion terms, not just the
        // word "free".
        if selectedPlan == .annual,
           let trial = subscriptionManager.redeemableAnnualIntroOffer?.freeTrialDescription {
            return "\(trial.prefix(1).capitalized + trial.dropFirst()), then \(product.displayPrice) per \(period). \(renewalTerms)"
        }

        return "\(product.displayPrice) per \(period). \(renewalTerms)"
    }

    private var legalLinks: some View {
        HStack(spacing: 6) {
            Link("Terms of Use", destination: LegalLinks.termsOfUse)
            Text("·").foregroundColor(.secondary)
            Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
        }
        .font(.system(size: 11))
    }

    // MARK: - Restore

    private var restoreLink: some View {
        Button {
            Task {
                await subscriptionManager.restorePurchases()
                if subscriptionManager.isProUser {
                    dismiss()
                } else {
                    restoreMessage = "No active subscription found for your Apple Account. If you believe this is an error, contact App Store support."
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Processing…")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
