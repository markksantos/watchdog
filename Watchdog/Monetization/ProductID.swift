import Foundation

/// The StoreKit product identifiers, in one place.
///
/// These must match the products created in App Store Connect **exactly**, and a product
/// identifier is permanent once created — it can never be reused or renamed. They are
/// namespaced under the bundle identifier because identifiers are globally unique across
/// the entire App Store, not per-developer: a short generic id like `com.watchdog.pro.monthly`
/// may already be taken by someone else, and App Store Connect will simply refuse to create it.
enum ProductID: String, CaseIterable {
    case monthly = "com.markstudios.watchdog.pro.monthly"
    case annual = "com.markstudios.watchdog.pro.annual"

    static var all: Set<String> { Set(allCases.map(\.rawValue)) }
}
