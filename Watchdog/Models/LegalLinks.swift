import Foundation

/// Canonical legal URLs.
///
/// App Review guideline 3.1.2 requires a functional Terms of Use link and a functional
/// Privacy Policy link on the subscription purchase screen itself, and 5.1.1 requires the
/// privacy policy to be reachable in-app. The same URLs must be filled in on the App Store
/// Connect app-information page. Keep all three in sync.
enum LegalLinks {
    // TODO: The landing site has no domain attached yet — these point at a placeholder.
    // Set `host` to the real domain before submitting; App Review clicks these links and a
    // 404 is an automatic rejection. The pages themselves live in `landing/`.
    private static let host = "https://watchdogapp.io"

    static let privacyPolicy = "\(host)/privacy"
    static let termsOfUse = "\(host)/terms"
    static let support = "\(host)/support"

    /// Apple's standard EULA, which applies unless you supply your own.
    /// Linking your own Terms of Use (above) satisfies the requirement; this is the
    /// fallback reviewers also accept.
    static let appleStandardEULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    /// Deep link to the system's subscription management pane, for the "cancel anytime"
    /// affordance that 3.1.2 expects to be discoverable.
    static let manageSubscriptions = "macappstore://apps.apple.com/account/subscriptions"
}
