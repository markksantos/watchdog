import XCTest
@testable import Watchdog

final class TrialManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "WatchdogTests.TrialManager"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testFreshInstallStartsFullTrial() {
        let manager = TrialManager(defaults: defaults, trialDuration: 7, now: { Date() })
        XCTAssertTrue(manager.isTrialActive)
        XCTAssertEqual(manager.daysRemaining, 7)
        XCTAssertFalse(manager.hasTrialExpired)
    }

    func testFirstLaunchDateIsPersistedAndStable() {
        let installDate = Date(timeIntervalSince1970: 1_700_000_000)
        let first = TrialManager(defaults: defaults, trialDuration: 7, now: { installDate })
        let stored = first.firstLaunchDate

        // A second manager (later "now") must reuse the persisted first-launch date.
        let later = installDate.addingTimeInterval(3 * 86_400)
        let second = TrialManager(defaults: defaults, trialDuration: 7, now: { later })
        XCTAssertEqual(second.firstLaunchDate.timeIntervalSince1970, stored.timeIntervalSince1970, accuracy: 1.0)
    }

    func testTrialCountsDownByElapsedDays() {
        let installDate = Date(timeIntervalSince1970: 1_700_000_000)
        // Seed the install date.
        _ = TrialManager(defaults: defaults, trialDuration: 7, now: { installDate })

        let threeDaysLater = installDate.addingTimeInterval(3 * 86_400 + 60)
        let manager = TrialManager(defaults: defaults, trialDuration: 7, now: { threeDaysLater })
        XCTAssertEqual(manager.daysRemaining, 4)
        XCTAssertTrue(manager.isTrialActive)
    }

    func testTrialExpiresAfterDuration() {
        let installDate = Date(timeIntervalSince1970: 1_700_000_000)
        _ = TrialManager(defaults: defaults, trialDuration: 7, now: { installDate })

        let eightDaysLater = installDate.addingTimeInterval(8 * 86_400)
        let manager = TrialManager(defaults: defaults, trialDuration: 7, now: { eightDaysLater })
        XCTAssertEqual(manager.daysRemaining, 0)
        XCTAssertFalse(manager.isTrialActive)
        XCTAssertTrue(manager.hasTrialExpired)
    }

    func testTrialNeverGoesNegative() {
        let installDate = Date(timeIntervalSince1970: 1_700_000_000)
        _ = TrialManager(defaults: defaults, trialDuration: 7, now: { installDate })

        let wayLater = installDate.addingTimeInterval(365 * 86_400)
        let manager = TrialManager(defaults: defaults, trialDuration: 7, now: { wayLater })
        XCTAssertEqual(manager.daysRemaining, 0)
    }
}
