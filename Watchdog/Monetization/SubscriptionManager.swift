import Foundation
import StoreKit

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var status: SubscriptionStatus = .free
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false

    private let productIDs: Set<String> = [
        "com.watchdog.pro.monthly",
        "com.watchdog.pro.annual"
    ]

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
        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("[Watchdog] Failed to load products: \(error)")
        }
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
        case .userCancelled:
            break
        case .pending:
            break
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
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }

    // MARK: - Helper Properties

    var monthlyProduct: Product? {
        products.first { $0.id == "com.watchdog.pro.monthly" }
    }

    var annualProduct: Product? {
        products.first { $0.id == "com.watchdog.pro.annual" }
    }
}
