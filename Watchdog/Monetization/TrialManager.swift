import Foundation

class TrialManager {
    static let shared = TrialManager()

    private let trialDuration: Int = 7 // days
    private let firstLaunchKey = "watchdog.firstLaunchDate"

    private init() {
        // Record first launch date if not already set
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        }
    }

    var firstLaunchDate: Date {
        UserDefaults.standard.object(forKey: firstLaunchKey) as? Date ?? Date()
    }

    var isTrialActive: Bool {
        daysRemaining > 0
    }

    var daysRemaining: Int {
        let elapsed = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
        return max(0, trialDuration - elapsed)
    }

    var hasTrialExpired: Bool {
        daysRemaining == 0
    }
}
