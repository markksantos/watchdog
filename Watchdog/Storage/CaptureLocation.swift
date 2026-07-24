import Foundation
import os

/// Resolves the folder captures are written to, in a way that survives the App Sandbox.
///
/// Under the sandbox a path string grants nothing. The default location
/// (`~/Pictures/Watchdog`) is reachable via the `assets.pictures.read-write`
/// entitlement, but any folder the user picks in Preferences is only reachable through a
/// security-scoped bookmark that we store and re-resolve on every launch.
///
/// Access to a custom folder is opened once at launch and held for the lifetime of the
/// process, which is what `files.bookmarks.app-scope` exists for. `releaseAccess()` is
/// called on termination.
enum CaptureLocation {
    private static let log = Logger(subsystem: "com.markstudios.watchdog", category: "storage")
    private static let bookmarkKey = "saveLocationBookmark"

    /// The custom folder currently held open, if any.
    private static var scopedURL: URL?

    // MARK: - Resolution

    /// `~/Pictures/Watchdog` — reachable without a bookmark thanks to the
    /// `com.apple.security.assets.pictures.read-write` entitlement.
    static var defaultDirectory: URL {
        let pictures = FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("Watchdog", isDirectory: true)
    }

    /// The directory captures are written to right now.
    static var currentDirectory: URL {
        scopedURL ?? defaultDirectory
    }

    /// Resolves the stored bookmark (if any) and opens scoped access. Call once at launch.
    @discardableResult
    static func resolveAtLaunch() -> URL {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return defaultDirectory
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard url.startAccessingSecurityScopedResource() else {
                log.error("Could not open security-scoped access to the saved capture folder; falling back to the default location")
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return defaultDirectory
            }

            scopedURL = url

            // The folder moved or was renamed — refresh the bookmark so it keeps working.
            if isStale {
                storeBookmark(for: url)
            }

            return url
        } catch {
            log.error("Failed to resolve capture folder bookmark: \(error.localizedDescription, privacy: .public)")
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return defaultDirectory
        }
    }

    // MARK: - Changing the location

    /// Adopts a folder the user picked in an `NSOpenPanel`, persisting access across launches.
    /// Returns the directory now in effect.
    @discardableResult
    static func setCustomDirectory(_ url: URL) -> URL {
        releaseAccess()

        guard url.startAccessingSecurityScopedResource() else {
            log.error("User-selected capture folder did not grant security-scoped access")
            return defaultDirectory
        }

        scopedURL = url
        storeBookmark(for: url)
        return url
    }

    /// Reverts to `~/Pictures/Watchdog`.
    static func resetToDefault() {
        releaseAccess()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    /// Closes scoped access. Call on app termination.
    static func releaseAccess() {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    // MARK: - Helpers

    /// Creates the capture directory if it does not exist. Returns false if it can't be made,
    /// which under the sandbox means we have no business writing there.
    @discardableResult
    static func ensureDirectoryExists() -> Bool {
        let url = currentDirectory
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            log.error("Could not create capture directory: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func storeBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            log.error("Failed to create capture folder bookmark: \(error.localizedDescription, privacy: .public)")
        }
    }
}
