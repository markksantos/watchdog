import Foundation
import IOKit.pwr_mgt
import Combine

/// Manages IOKit power assertions to prevent system sleep and screen lock
/// based on user preferences in SettingsManager.
class PowerManager {
    static let shared = PowerManager()

    private var sleepAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let settings = SettingsManager.shared

        settings.$preventSleep
            .sink { [weak self] enabled in self?.updateSleepAssertion(enabled) }
            .store(in: &cancellables)

        settings.$preventScreenLock
            .sink { [weak self] enabled in self?.updateDisplayAssertion(enabled) }
            .store(in: &cancellables)
    }

    // MARK: - System Sleep

    private func updateSleepAssertion(_ enable: Bool) {
        if enable {
            guard sleepAssertionID == 0 else { return }
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Watchdog monitoring is active" as CFString,
                &sleepAssertionID
            )
            if result != kIOReturnSuccess {
                print("[PowerManager] Failed to create sleep assertion: \(result)")
                sleepAssertionID = 0
            }
        } else {
            releaseSleepAssertion()
        }
    }

    private func releaseSleepAssertion() {
        guard sleepAssertionID != 0 else { return }
        IOPMAssertionRelease(sleepAssertionID)
        sleepAssertionID = 0
    }

    // MARK: - Display Sleep / Screen Lock

    private func updateDisplayAssertion(_ enable: Bool) {
        if enable {
            guard displayAssertionID == 0 else { return }
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Watchdog monitoring is active" as CFString,
                &displayAssertionID
            )
            if result != kIOReturnSuccess {
                print("[PowerManager] Failed to create display assertion: \(result)")
                displayAssertionID = 0
            }
        } else {
            releaseDisplayAssertion()
        }
    }

    private func releaseDisplayAssertion() {
        guard displayAssertionID != 0 else { return }
        IOPMAssertionRelease(displayAssertionID)
        displayAssertionID = 0
    }

    // MARK: - Cleanup

    func releaseAll() {
        releaseSleepAssertion()
        releaseDisplayAssertion()
    }
}
