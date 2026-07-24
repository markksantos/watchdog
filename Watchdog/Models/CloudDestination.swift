import Foundation

/// Cloud services Watchdog intends to back captures up to.
///
/// **Nothing here is connected yet.** The Storage tab renders these as a preview of planned
/// functionality with its controls disabled, rather than as working switches. That is a
/// deliberate choice: a toggle that appears to enable cloud backup but silently does nothing
/// would be worse than no toggle at all, and shipping real third-party OAuth would pull in
/// network entitlements and a privacy-label change that the current App Store submission
/// doesn't claim.
enum CloudDestination: String, CaseIterable, Identifiable {
    case iCloudDrive
    case googlePhotos
    case googleDrive
    case dropbox
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iCloudDrive: return "iCloud Drive"
        case .googlePhotos: return "Google Photos"
        case .googleDrive: return "Google Drive"
        case .dropbox: return "Dropbox"
        case .custom: return "Custom Server"
        }
    }

    var icon: String {
        switch self {
        case .iCloudDrive: return "icloud.fill"
        case .googlePhotos: return "photo.on.rectangle.angled"
        case .googleDrive: return "externaldrive.fill.badge.icloud"
        case .dropbox: return "shippingbox.fill"
        case .custom: return "server.rack"
        }
    }

    var blurb: String {
        switch self {
        case .iCloudDrive: return "Mirror captures into your iCloud Drive folder"
        case .googlePhotos: return "Upload captures to your Google Photos library"
        case .googleDrive: return "Sync captures to a folder in Google Drive"
        case .dropbox: return "Sync captures to a folder in Dropbox"
        case .custom: return "Send captures to your own S3 or WebDAV endpoint"
        }
    }
}
