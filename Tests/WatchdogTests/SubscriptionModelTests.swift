import XCTest
@testable import Watchdog

final class SubscriptionModelTests: XCTestCase {

    func testProUserGating() {
        XCTAssertFalse(SubscriptionStatus.free.isProUser)
        XCTAssertFalse(SubscriptionStatus.expired.isProUser)
        XCTAssertTrue(SubscriptionStatus.trial(daysRemaining: 3).isProUser)
        XCTAssertTrue(SubscriptionStatus.subscribed(productID: "x", expiresDate: .distantFuture).isProUser)
    }

    func testDisplayNames() {
        XCTAssertEqual(SubscriptionStatus.free.displayName, "Free")
        XCTAssertEqual(SubscriptionStatus.expired.displayName, "Expired")
        XCTAssertEqual(SubscriptionStatus.subscribed(productID: "x", expiresDate: .distantFuture).displayName, "Pro")
        XCTAssertEqual(SubscriptionStatus.trial(daysRemaining: 1).displayName, "Trial (1 day left)")
        XCTAssertEqual(SubscriptionStatus.trial(daysRemaining: 5).displayName, "Trial (5 days left)")
    }

    func testEquatable() {
        XCTAssertEqual(SubscriptionStatus.free, SubscriptionStatus.free)
        XCTAssertNotEqual(SubscriptionStatus.free, SubscriptionStatus.expired)
        XCTAssertEqual(
            SubscriptionStatus.trial(daysRemaining: 2),
            SubscriptionStatus.trial(daysRemaining: 2)
        )
    }

    func testEveryProFeatureHasIconAndDescription() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.icon.isEmpty, "\(feature) missing icon")
            XCTAssertFalse(feature.description.isEmpty, "\(feature) missing description")
            XCTAssertFalse(feature.rawValue.isEmpty, "\(feature) missing display name")
        }
    }

    func testProFeatureCountMatchesMarketedTiers() {
        // Eight Pro capabilities. Webhook Alerts and Auto-Lock were removed for the Mac
        // App Store build (see tasks/app-store-compliance.md): the sandbox blocks both, so
        // shipping them would mean selling features that cannot work. Keep this in sync
        // with the paywall and the landing page.
        XCTAssertEqual(ProFeature.allCases.count, 8)
    }
}
