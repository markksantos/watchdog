import Foundation

class TrialManager {
    static let shared = TrialManager()

    private let trialDuration: Int // days
    private let firstLaunchKey = "watchdog.firstLaunchDate"
    private let defaults: UserDefaults
    private let now: () -> Date

    /// Designated initializer. Injectable for tests; the app uses `.shared`.
    init(
        defaults: UserDefaults = .standard,
        trialDuration: Int = 7,
        now: @escaping () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.trialDuration = trialDuration
        self.now = now

        // Record first launch date if not already set
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(now(), forKey: firstLaunchKey)
        }
    }

    var firstLaunchDate: Date {
        defaults.object(forKey: firstLaunchKey) as? Date ?? now()
    }

    var isTrialActive: Bool {
        daysRemaining > 0
    }

    var daysRemaining: Int {
        let elapsed = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: now()).day ?? 0
        return max(0, trialDuration - elapsed)
    }

    var hasTrialExpired: Bool {
        daysRemaining == 0
    }
}
