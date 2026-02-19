import Foundation

enum AutoLockManager {
    private static var pendingLock: DispatchWorkItem?

    static func scheduleLock(afterDelay delay: Double) {
        cancelScheduledLock()

        let work = DispatchWorkItem {
            lock()
        }
        pendingLock = work

        if delay <= 0 {
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        } else {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + delay,
                execute: work
            )
        }
    }

    static func cancelScheduledLock() {
        pendingLock?.cancel()
        pendingLock = nil
    }

    private static func lock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        process.arguments = ["-suspend"]
        do {
            try process.run()
        } catch {
            print("[AutoLockManager] Failed to lock screen: \(error)")
        }
    }
}
