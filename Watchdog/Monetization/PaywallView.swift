import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: String = "com.watchdog.pro.annual"
    @State private var purchaseError: String?
    @State private var restoreMessage: String?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    featuresSection
                    planCards
                    purchaseButton
                    restoreLink
                }
                .padding(32)
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

    // MARK: - Plan Cards

    private var planCards: some View {
        HStack(spacing: 12) {
            planCard(
                title: "Monthly",
                price: subscriptionManager.monthlyProduct?.displayPrice ?? "$3.99",
                period: "/month",
                productID: "com.watchdog.pro.monthly",
                badges: []
            )

            planCard(
                title: "Annual",
                price: subscriptionManager.annualProduct?.displayPrice ?? "$29.99",
                period: "/year",
                productID: "com.watchdog.pro.annual",
                badges: ["7-day free trial", "Save 37%"]
            )
        }
        .padding(.top, 4)
    }

    private func planCard(
        title: String,
        price: String,
        period: String,
        productID: String,
        badges: [String]
    ) -> some View {
        let isSelected = selectedPlan == productID
        let isRecommended = productID == "com.watchdog.pro.annual"

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

            Text(title)
                .font(.system(size: 15, weight: .semibold))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(price)
                    .font(.system(size: 22, weight: .bold))
                Text(period)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            ForEach(badges, id: \.self) { badge in
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
            selectedPlan = productID
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task {
                guard let product = subscriptionManager.products.first(where: { $0.id == selectedPlan }) else { return }
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
            Text("Subscribe Now")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.isLoading)
    }

    // MARK: - Restore

    private var restoreLink: some View {
        Button {
            Task {
                await subscriptionManager.restorePurchases()
                if subscriptionManager.isProUser {
                    dismiss()
                } else {
                    restoreMessage = "No active subscription found for your Apple ID. If you believe this is an error, contact App Store support."
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
                Text("Processing...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
