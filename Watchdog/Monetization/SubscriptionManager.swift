import Foundation
import StoreKit
import os

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// Whether the App Store has handed us the products yet.
    ///
    /// The paywall keys off this rather than falling back to hardcoded prices. Showing a
    /// baked-in "$29.99" is wrong in every non-US storefront — the price and the currency
    /// both differ — and quoting a price the user will not actually be charged is a 2.3.1
    /// (accurate metadata) rejection. If the load fails the paywall says so and offers a
    /// retry instead of inventing a number.
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Published var status: SubscriptionStatus = .free

    /// Whether `status` reflects a real answer from StoreKit yet.
    ///
    /// `status` starts at `.free` because it needs *some* value, but that default is a
    /// placeholder, not a finding — StoreKit is queried asynchronously and cannot have
    /// replied before the app finishes launching. Anything destructive keyed off
    /// entitlement must wait for this, or it acts on a guess that is wrong for every
    /// paying user.
    @Published private(set) var hasResolvedStatus = false

    @Published var products: [Product] = []
    @Published var loadState: LoadState = .loading
    @Published var isLoading: Bool = false

    /// True when the Apple Account has never redeemed an introductory offer in this
    /// subscription group. The paywall must not advertise the free trial otherwise.
    @Published var isEligibleForIntroOffer: Bool = false

    /// Set when a purchase is deferred (Ask to Buy / parental approval) so the UI can
    /// explain the wait instead of looking like nothing happened.
    @Published var pendingPurchaseMessage: String?

    private let log = Logger(subsystem: "com.markstudios.watchdog", category: "subscription")
    private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = listenForTransactions()
        Task { @MainActor in
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    @MainActor
    func loadProducts() async {
        loadState = .loading
        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }

            guard !products.isEmpty else {
                // StoreKit returns an empty array (not an error) for identifiers it does not
                // recognise — the usual cause is the products not existing in App Store
                // Connect yet, or not being in the "Ready to Submit" state.
                loadState = .failed("Subscriptions aren’t available right now. Please try again later.")
                log.error("Product.products returned no products for \(ProductID.all.sorted().joined(separator: ", "), privacy: .public)")
                return
            }

            await refreshIntroOfferEligibility()
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn’t reach the App Store. Check your connection and try again.")
            log.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func refreshIntroOfferEligibility() async {
        guard let subscription = annualProduct?.subscription else {
            isEligibleForIntroOffer = false
            return
        }
        isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
    }

    // MARK: - Purchase

    @MainActor
    func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            await refreshIntroOfferEligibility()
        case .userCancelled:
            break
        case .pending:
            // Ask to Buy, or a payment method that needs out-of-band approval. The purchase
            // may complete minutes or days later via the transaction listener.
            pendingPurchaseMessage = "Your purchase is waiting for approval. Watchdog Pro unlocks automatically once it goes through."
        @unknown default:
            break
        }
    }

    // MARK: - Restore

    @MainActor
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Access Check

    /// Every paid capability is bundled into a single Pro tier, so access is the same for
    /// all of them. The parameter is kept so call sites read as intent (`hasAccess(to:
    /// .videoRecording)`) and so introducing a narrower tier later is a change to this one
    /// method rather than to every gate in the app.
    func hasAccess(to feature: ProFeature) -> Bool {
        return isProUser
    }

    var isProUser: Bool {
        status.isProUser
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await transaction.finish()
                    await self?.updateSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Status Update

    @MainActor
    func updateSubscriptionStatus() async {
        var foundActive = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if transaction.revocationDate == nil,
               let expirationDate = transaction.expirationDate,
               expirationDate > Date() {
                status = .subscribed(
                    productID: transaction.productID,
                    expiresDate: expirationDate
                )
                foundActive = true
                break
            }
        }

        if !foundActive {
            if TrialManager.shared.isTrialActive {
                status = .trial(daysRemaining: TrialManager.shared.daysRemaining)
            } else if TrialManager.shared.hasTrialExpired {
                status = .expired
            } else {
                status = .free
            }
        }

        // Set last, and unconditionally: every path above has now produced a real answer,
        // including the ones that land back on `.free`. Retention waits on this flag.
        hasResolvedStatus = true
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "This purchase could not be verified with the App Store. You have not been charged."
            }
        }
    }

    // MARK: - Helper Properties

    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthly.rawValue }
    }

    var annualProduct: Product? {
        products.first { $0.id == ProductID.annual.rawValue }
    }

    func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    /// The introductory offer actually attached to the annual plan in App Store Connect,
    /// but only when this Apple Account can still redeem it. Everything the paywall says
    /// about a free trial is derived from this — never from a hardcoded string — so the app
    /// cannot advertise a trial that App Store Connect isn't configured to grant, or that
    /// this particular user already used up.
    var redeemableAnnualIntroOffer: Product.SubscriptionOffer? {
        guard isEligibleForIntroOffer else { return nil }
        return annualProduct?.subscription?.introductoryOffer
    }

    /// Percentage saved by paying annually instead of twelve monthly renewals, computed
    /// from the live storefront prices rather than assumed from the US ones.
    var annualSavingsPercent: Int? {
        guard let monthly = monthlyProduct?.price,
              let annual = annualProduct?.price,
              monthly > 0 else { return nil }

        let yearOfMonthly = monthly * 12
        guard annual < yearOfMonthly else { return nil }

        let saved = (yearOfMonthly - annual) / yearOfMonthly * 100
        return Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
    }
}

extension Product.SubscriptionOffer {
    /// "7-day free trial", "1-month free trial" — built from the offer StoreKit actually
    /// returns so the wording tracks whatever is configured in App Store Connect.
    var freeTrialDescription: String? {
        guard paymentMode == .freeTrial else { return nil }
        return "\(period.displayDescription) free trial"
    }
}

extension Product.SubscriptionPeriod {
    /// "7-day", "1-month" — the attributive form Apple uses in subscription copy, so it
    /// reads correctly in "7-day free trial" and "then $29.99 per year".
    var displayDescription: String {
        // A "P1W" trial reads better as "7-day" than "1-week".
        if unit == .week {
            return "\(value * 7)-day"
        }

        let unitName: String
        switch unit {
        case .day: unitName = "day"
        case .month: unitName = "month"
        case .year: unitName = "year"
        case .week: unitName = "week"
        @unknown default: unitName = "period"
        }
        return "\(value)-\(unitName)"
    }
}
