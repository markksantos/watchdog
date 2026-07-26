import Foundation

/// Canonical legal URLs.
///
/// App Review guideline 3.1.2 requires a functional Terms of Use link and a functional
/// Privacy Policy link on the subscription purchase screen itself, and 5.1.1 requires the
/// privacy policy to be reachable in-app. The same URLs must be filled in on the App Store
/// Connect app-information page. Keep all three in sync.
///
/// Reviewers click every one of these, and a 404 is an automatic rejection — so these must
/// stay pointed at pages that are actually deployed. The pages live in the NoSleepLab site
/// repo (`Web Apps/nosleeplab`) under `app/apps/watchdog/`.
enum LegalLinks {
    private static let host = "https://nosleeplab.com"
    private static let productPath = "\(host)/apps/watchdog"

    static let productPage = url(productPath)
    static let privacyPolicy = url("\(productPath)/privacy")
    static let termsOfUse = url("\(productPath)/terms")
    static let support = url("\(productPath)/support")

    /// Apple's standard EULA, which applies unless you supply your own.
    /// Linking your own Terms of Use (above) satisfies the requirement; this is the
    /// fallback reviewers also accept.
    static let appleStandardEULA = url("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    /// Deep link to the system's subscription management pane, for the "cancel anytime"
    /// affordance that 3.1.2 expects to be discoverable.
    static let manageSubscriptions = url("macappstore://apps.apple.com/account/subscriptions")

    /// These are compile-time constants, so a failure here is a typo in this file rather
    /// than anything a running app could recover from.
    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Malformed legal URL literal: \(string)")
        }
        return url
    }
}
