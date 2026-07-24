# Watchdog — Mac App Store Compliance Audit

Reviewed: full source tree (`Watchdog/`, 4,660 LOC), `Info.plist`, `Watchdog.entitlements`,
`Package.swift`, `scripts/build-app.sh`, `Watchdog.storekit`, `landing/index.html`.

> **Status as of 23 July 2026.** The code and configuration fixes are landed (commits
> `e7169c6`, `e429ba0`). What remains is listed in §7 — the Xcode project restructure, the
> real domain for the legal pages, and App Store Connect setup. The audit below is kept as
> written, with each item marked ✅ done or ⬜ outstanding.

Verdict: **cannot be submitted today.** There are 7 hard blockers that will fail either the
App Store Connect *upload* or the *first review pass*, plus 9 issues that are likely-reject
or fix-before-ship. Nothing here is unfixable — this is a legitimate, well-behaved category
of app (local security camera) — but the current build is structured as a direct-download
app, not a sandboxed store app, and it has zero privacy/consent surface.

Legend: **[BLOCK]** = will be rejected. **[RISK]** = likely rejected / reviewer discretion.
**[FIX]** = won't block, should be fixed.

---

## 1. Hard blockers

### B1 — [BLOCK] No App Sandbox. `Watchdog/Watchdog.entitlements`

```xml
com.apple.security.device.camera            ✅
com.apple.security.personal-information.photos-library
com.apple.security.network.client           ✅
```

`com.apple.security.app-sandbox` is absent. **Every** Mac App Store app must be sandboxed
(App Review Guideline 2.4.5(i)). Upload is rejected outright.

Adding the sandbox is not a one-line change — it breaks B2, B3 and B4 below, which is why
they need to be solved together.

Required entitlement set for this app:

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.device.camera</key><true/>
<key>com.apple.security.network.client</key><true/>          <!-- webhooks only -->
<key>com.apple.security.files.user-selected.read-write</key><true/>  <!-- Browse… + PDF export -->
<key>com.apple.security.assets.pictures.read-write</key><true/>      <!-- default ~/Pictures/Watchdog -->
<key>com.apple.security.files.bookmarks.app-scope</key><true/>       <!-- persist chosen folder -->
```

### B2 — [BLOCK] Unused, undeclared Photos entitlement

`com.apple.security.personal-information.photos-library` is requested but the app never
imports PhotoKit or touches the Photos library (verified: no `PHPhotoLibrary`, no
`Photos` import anywhere). Requesting an entitlement you don't use is a rejection under
2.5.1/5.1.1, and it also requires an `NSPhotoLibraryUsageDescription` string that doesn't
exist in `Info.plist` — which is itself a crash/reject condition if it were ever exercised.

**Delete this entitlement.**

### B3 — [BLOCK] Save location escapes the sandbox. `SettingsManager.swift:121`, `CameraManager.swift:117-137`

```swift
self.saveLocation = defaults.string(forKey: Keys.saveLocation) ?? "\(homeDir)/Pictures/Watchdog"
```

and captures are written by raw path:

```swift
try jpegData.write(to: URL(fileURLWithPath: filePath))
```

The folder chosen via `NSOpenPanel` (`PreferencesView.swift:116-126`) is stored as a **plain
path string**. Under the sandbox, a user-selected path grants access only for the lifetime of
that URL — on next launch the app has no access and every capture write fails silently
(`CameraManager.captureCurrentFrame` just `return nil`s). Same problem for `VideoRecorder`
(`VideoRecorder.swift:400-411`) and `CaptureStore.metadataURL`.

Fix: store a **security-scoped bookmark**, not a path; wrap all reads/writes in
`startAccessingSecurityScopedResource()` / `stopAccessing…`; default the save location to the
app container (`FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)` inside
the container, or `applicationSupportDirectory`) rather than the real `~/Pictures`.

### B4 — [BLOCK] Auto-Lock shells out to an external binary. `AutoLockManager.swift:26-36`

```swift
process.executableURL = URL(fileURLWithPath:
  "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
process.arguments = ["-suspend"]
```

The sandbox blocks `posix_spawn` of binaries outside the app bundle, so this feature is
dead-on-arrival in a store build — and shipping a paid Pro feature ("Auto-Lock", `$3.99/mo`)
that silently never works is a 2.2 / 3.1.2 rejection on its own.

There is **no sanctioned public API** to lock the screen from a sandboxed app.
`SACLockScreenImmediate()` lives in the private `login.framework` and is an automatic
rejection (2.5.1, private API).

Options, in order of preference:
1. Drop Auto-Lock from the App Store build (keep it in the direct-download build). Remove it
   from `ProFeature`, the paywall feature list, `PreferencesView`, and the landing page.
2. Replace with "Sleep display on detection" via `IOPMAssertionDeclareUserActivity` /
   display-sleep — combined with the user's existing "require password after sleep" setting
   this achieves the same outcome using public API.

Do **not** ship it as-is.

### B5 — [BLOCK] Stealth Mode traps the user. `StealthModeManager.swift:88-105`

```swift
override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.keyCode == 37 && … { manager?.disable(); return true }
    return true // Block all other Cmd shortcuts
}
```

A borderless, opaque, `screenSaverWindow`-level window is placed over **every** screen,
`NSApplication.shared.activate(ignoringOtherApps: true)` is called, and all key equivalents —
including ⌘Q, ⌘Tab, ⌘⇧Q — are swallowed. The only escape is ⌘⇧L, and only while that window
is first responder. If focus is lost, or the user forgets the shortcut, the machine is
effectively bricked until a hard power cycle.

This violates 2.4.5 ("apps must not… interfere with system functionality") and the
"users must always be able to quit" requirement. Reviewers test exactly this.

Fix: keep the black overlay as a *screen dimmer*, but (a) never block ⌘Q / ⌘Tab /
⌘⇧Escape, (b) add a visible, always-present "Exit Stealth Mode" button in addition to the
hotkey, (c) never call `activate(ignoringOtherApps:)`, (d) auto-exit after N minutes.

### B6 — [BLOCK] Paywall is missing every required subscription disclosure. `PaywallView.swift`

Guideline 3.1.2 + Schedule 2 §3.8(b) require, **on the purchase screen itself**:

| Required | Present |
|---|---|
| Subscription title | ✅ "Monthly" / "Annual" |
| Length of subscription period | ✅ "/month", "/year" |
| Price per period | ✅ `displayPrice` |
| Free-trial terms — duration, what it converts to, price, auto-renew, how to cancel | ❌ only a `"7-day free trial"` badge |
| Functional link to **Terms of Use (EULA)** | ❌ **absent** |
| Functional link to **Privacy Policy** | ❌ **absent** |
| Restore Purchases | ✅ `restoreLink` |

Missing EULA + Privacy Policy links on the paywall is the single most common macOS
subscription rejection. Both links are also required in App Store Connect metadata.

Required trial copy (adapt wording, keep the substance):

> 7-day free trial, then $29.99/year. Your subscription renews automatically unless
> cancelled at least 24 hours before the end of the current period. Manage or cancel
> anytime in System Settings → Apple Account → Subscriptions.

### B7 — [BLOCK] No privacy policy, anywhere

`grep -riE "privacy|terms|eula|policy|consent" Watchdog/ landing/` returns **two** hits, both
of which are the macOS camera-permission deep link. There is:

- no privacy policy URL in the app,
- no privacy policy page on the landing site (`landing/` is a single `index.html`),
- no Terms of Use / EULA.

Guideline 5.1.1 requires a privacy policy link in App Store Connect **and** in-app for any app
that accesses protected resources. This app records photos and video of **people**. A policy
is mandatory, not optional.

Minimum contents: what is captured (stills/clips + timestamp + detection type + confidence),
that it is stored locally only and never transmitted to the developer, the webhook exception
(user-configured third-party endpoint, user's responsibility), retention (3 days free /
unlimited Pro), how to delete, and a lawful-use clause.

---

## 2. High-risk (likely rejection / must resolve before submitting)

### R1 — [RISK] Covert-surveillance marketing. `landing/index.html:943,952-953`

```html
Perfect for overnight office monitoring or weekend surveillance.
Pair with stealth mode for invisible, hands-off operation.

<h3>Stealth Mode</h3>
<p>Hide the icon entirely. Run silent, run invisible. No visible trace.</p>
```

This is textbook 5.1.2(i) rejection language — "invisible", "no visible trace", "run silent",
"surveillance". Apple reviews your marketing site and App Store description, not just the
binary. Rewrite around *your own device, your own desk, you are the subject*.

It is also **factually false**: `StatusBarController.swift:27` unconditionally creates
`NSStatusBar.system.statusItem(…)` and there is no code path that hides it. Stealth Mode
blacks out the *display*, it does not hide the app. A false capability claim is a separate
2.3.1 (accurate metadata) rejection.

### R2 — [RISK] No third-party consent / notice surface

The app photographs whoever walks up to the Mac. Those people are not the purchaser and
cannot consent. Apple approves this category (it is framed as *your* device security), but
expects the developer to place responsibility clearly. Currently there is nothing: no
first-run screen, no lawful-use notice, no mention that recording others may be regulated.

Add a **one-time first-run consent screen** before the camera permission prompt, stating:
- Watchdog captures still images (and optional 5s clips) of people in front of this Mac.
- Captures stay on this Mac; nothing is sent to the developer.
- You are responsible for complying with local recording/notice laws, and for informing
  people who may be recorded.
- Link to the privacy policy.

Gate `DetectionEngine.startMonitoring()` on this having been acknowledged. Mention it in App
Review notes — reviewers specifically look for it on camera-monitoring apps.

### R3 — [RISK] Missing privacy manifest — `PrivacyInfo.xcprivacy`

No privacy manifest exists. Apps submitted to the App Store must declare required-reason API
usage. Watchdog uses `UserDefaults` extensively (`SettingsManager`, `TrialManager`), which is
category `NSPrivacyAccessedAPICategoryUserDefaults`, reason **`CA92.1`** (access limited to
the app itself).

Also declare `NSPrivacyTracking = false`, empty `NSPrivacyTrackingDomains`, and
`NSPrivacyCollectedDataTypes` consistent with whatever you file in the App Privacy label.

### R4 — [RISK] Global keyboard monitoring cannot work in a sandboxed app. `HotkeyManager.swift:26-42`

```swift
NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { … }   // ⌘⇧M
NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { … }   // ⌘⇧C
```

Global monitoring of **key** events requires Accessibility / Input Monitoring trust. Sandboxed
Mac App Store apps cannot obtain it, so both global hotkeys will silently do nothing in the
shipped build. Worse: registering a system-wide keystroke listener on a camera-surveillance app
is precisely the shape reviewers flag as keylogging, and there is no usage-description string
explaining it.

Fix: keep the **local** monitor (`addLocalMonitorForEvents`, line 44) and expose the actions as
real menu items with key equivalents. Delete the two global monitors, or move them to the
direct-download build only. Advertise hotkeys as in-app only.

### R5 — [RISK] Bundle is not built by Xcode — upload will be rejected

`scripts/build-app.sh` hand-assembles `Watchdog.app` from `swift build` output. The resulting
`Info.plist` lacks `CFBundleExecutable` and every Xcode build key (`DTXcode`, `DTXcodeBuild`,
`DTSDKName`, `DTPlatformVersion`, `BuildMachineOSBuild`). App Store Connect rejects such
bundles (`ITMS-90242` family), and the binary is unsigned with no hardened runtime and no
provisioning profile.

You need a real Xcode project/target (or `xcodebuild` against a generated `.xcodeproj`) with
automatic signing, the `3rd Party Mac Developer Application` / `Installer` identities, and a
Mac App Store provisioning profile. Keep the SPM package as a library target if you like, but
the shipping product must be an Xcode app target.

### R6 — [RISK] Webhook transmits capture data over an unvalidated, possibly cleartext URL. `WebhookManager.swift:8-12,66-74`

```swift
guard let url = URL(string: SettingsManager.shared.webhookURL) else { return }
```

No scheme validation. Two consequences:
1. `http://` endpoints are blocked by App Transport Security (no `NSAppExceptionDomains` in
   `Info.plist`), so the feature silently fails — another paid Pro feature that doesn't work.
2. If ATS were relaxed, detection events (timestamp, detection type, **absolute file path**,
   which contains the macOS username) would go out in plaintext.

Fix: reject non-`https` URLs in the UI with a clear message, and stop sending `imagePath` /
`videoPath` — a local absolute path is useless to the receiver and leaks the username. Send an
opaque capture ID instead.

Also: this feature means the app **does** transmit data to a third party. Your App Privacy
label must reflect it (see §4) and the privacy policy must describe it.

### R7 — [RISK] Free-tier retention deletes records but not the files. `CaptureStore.swift:64-69`

```swift
if !SettingsManager.shared.isPaid {
    let threeDaysAgo = …
    decoded = decoded.filter { $0.timestamp > threeDaysAgo }
}
```

Records older than 3 days are dropped from the in-memory list, then `saveCaptureMetadata()`
persists the truncated list — but the underlying `.jpg` / `.mov` files are **never deleted**.
Result: photographs of people accumulate forever on disk, invisible to the user, with no UI to
find or delete them. That directly contradicts the retention promise implied by
`ProFeature.unlimitedHistory` ("Keep captures forever with no 3-day limit").

This is a genuine data-minimization failure and it contradicts whatever your privacy policy
will say about retention. Fix: on expiry, actually `removeItem` the media, and add a
"Delete all captures" affordance (`deleteAllCaptures()` exists — surface it in Preferences).

Related: when a Pro subscription lapses, >3-day-old captures vanish from the UI with no
warning and no export prompt. Warn the user before that happens.

### R8 — [RISK] Notification attachments leak captures into `/tmp` forever. `NotificationManager.swift:80-95`

```swift
let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
try fileManager.copyItem(at: imageURL, to: tempFile)
```

Every detection copies a photo of a person into the temp directory under a random name and
never removes it. Clean up after the notification is delivered/dismissed.

### R9 — [RISK] `Info.plist` is missing required store keys

Missing: `CFBundleExecutable`, `LSApplicationCategoryType`
(`public.app-category.utilities`), `ITSAppUsesNonExemptEncryption` (`false` — the app uses
only HTTPS via URLSession, which is exempt; setting it avoids the export-compliance
questionnaire on every upload), `NSHumanReadableCopyright`.

`NSUserNotificationAlertStyle` is deprecated (that key belongs to the removed
`NSUserNotification` API); `UNUserNotificationCenter` ignores it. Harmless, but remove it.

---

## 3. Fix-before-ship (non-blocking)

- **F1** — `CFBundleIdentifier` is `com.watchdog.security-camera`. Not a domain you control;
  use a reverse-DNS ID under a domain you own and that matches the App ID on your team.
- **F2** — Strengthen `NSCameraUsageDescription`. Current text is acceptable; better:
  *"Watchdog uses your camera to detect motion or faces in front of this Mac and save
  captures locally to your device. Captures are never sent to the developer."*
- **F3** — `print()` statements log absolute file paths (which embed the username) and
  subscription state to `stdout`. Move to `os.Logger` with `privacy: .private` on paths.
  Affected: `CaptureStore.swift:86,97`, `WebhookManager.swift:70`, `CameraManager`,
  `NotificationManager.swift:57,92`, `WakeDetector.swift:36`, `PreferencesView.swift:241`.
- **F4** — `SubscriptionManager.hasAccess(to:)` ignores its `feature` argument and returns
  `isProUser` for everything. Harmless today, but it means a future per-feature tier silently
  grants everything. Either use the parameter or drop it.
- **F5** — `TrialManager` grants a 7-day Pro trial keyed on a `UserDefaults` date
  (`watchdog.firstLaunchDate`). Deleting the prefs plist resets it indefinitely. Not a review
  issue, but note this is *separate* from the StoreKit introductory offer advertised on the
  annual plan — make sure the ASC introductory offer actually exists, or the "7-day free
  trial" badge is false advertising (2.3.1).
- **F6** — Captures are stored unencrypted. Not required by Apple, but for an app whose whole
  premise is images of people, consider `NSFileProtection`-equivalent placement inside the
  container and say plainly in the policy that they are unencrypted on disk.
- **F7** — Landing page has no privacy policy or support URL in the footer. Both are required
  App Store Connect metadata fields; host them at `/privacy` and `/support`.

---

## 4. App Privacy label (App Store Connect)

Do **not** file "Data Not Collected". Correct answers for this build:

| Data type | Collected? | Notes |
|---|---|---|
| Photos or Videos | **Yes**, if webhooks are enabled | Not linked to identity, not used for tracking. Purpose: App Functionality. Stored on-device; metadata optionally sent to a **user-configured** third-party endpoint. |
| Identifiers | No | |
| Usage Data | No | |
| Diagnostics | No | |
| Purchases | Handled by Apple (StoreKit) — not collected by you | |

If you remove the webhook feature (or strip all capture metadata from the payload), you can
truthfully answer "Data Not Collected", which materially simplifies review. Worth considering.

---

## 5. Recommended order of work

1. **Restructure the build** — Xcode app target, signing, hardened runtime, MAS provisioning
   profile. (R5) Nothing else can be validated until this exists.
2. **Sandbox + storage** — add `app-sandbox`, drop the Photos entitlement, migrate
   `saveLocation` to security-scoped bookmarks, default into the container. (B1, B2, B3)
3. **Amputate the features that cannot ship sandboxed** — Auto-Lock (B4), global hotkeys (R4).
   Remove them from `ProFeature`, the paywall, Preferences, and the landing page in the same
   commit so metadata stays truthful.
4. **De-fang Stealth Mode** — never block ⌘Q/⌘Tab, visible exit control, no
   `activate(ignoringOtherApps:)`. (B5)
5. **Write the legal surface** — privacy policy + EULA pages, hosted; link them from the
   paywall, Preferences, and the landing footer. (B7, F7)
6. **Paywall disclosures** — trial terms, EULA/Privacy links. (B6)
7. **First-run consent screen** gating `startMonitoring()`. (R2)
8. **Privacy manifest** `PrivacyInfo.xcprivacy` with `CA92.1`. (R3)
9. **Data hygiene** — actually delete expired media (R7), clean up notification temp files
   (R8), https-only + no-path webhook payloads (R6).
10. **Rewrite the landing copy** away from "invisible / no visible trace / surveillance". (R1)
11. `Info.plist` keys (R9), bundle ID (F1), usage string (F2), logging (F3).

---

## 7. What is done, and what is left

**Landed** (`e7169c6`, `e429ba0`) — all verified against `swift build` + 26 passing tests:

| Item | What changed |
|---|---|
| ✅ B1 | `com.apple.security.app-sandbox` added, plus pictures / user-selected / bookmark entitlements |
| ✅ B2 | Unused `photos-library` entitlement removed; `network.client` dropped too |
| ✅ B3 | New `CaptureLocation` resolves the folder via security-scoped bookmark |
| ✅ B4 | Auto-Lock removed (`AutoLockManager.swift` deleted) |
| ✅ B5 | `StealthModeManager` → `ScreenDimManager`: no key blocking, visible exit, 15-min timeout, below menu bar |
| ✅ B6 | Paywall states trial terms + auto-renewal, links Terms of Use and Privacy Policy |
| ✅ B7 | `landing/privacy.html` + `landing/terms.html` written; linked in-app and in the footer |
| ✅ R1 | Covert framing and fabricated testimonials removed from the landing page |
| ✅ R2 | `RecordingNoticeView` gates `startMonitoring()` |
| ✅ R3 | `PrivacyInfo.xcprivacy` added (CA92.1 + C617.1) and wired into the bundle |
| ✅ R4 | Global `NSEvent` keyDown monitors removed; local shortcuts retained |
| ✅ R6 | Webhooks removed entirely → truthful "Data Not Collected" |
| ✅ R7 | Retention now deletes the media instead of orphaning it |
| ✅ R8 | Notification attachments cleaned up on termination |
| ✅ R9, F1–F3 | Info.plist keys, bundle ID, camera string, `os.Logger` |

**Outstanding — these block submission and need you:**

1. ⬜ **R5, the Xcode project.** Still the biggest one. `scripts/build-app.sh` hand-assembles
   the bundle from `swift build`; App Store Connect will reject it for missing `DTXcode*`
   keys, and it is unsigned with no provisioning profile. Needs a real Xcode app target with
   automatic signing and a Mac App Store profile. Everything else is untestable against the
   actual sandbox until this exists — the sandbox entitlements above are *correct* but have
   not been exercised, because an unsigned SPM binary isn't sandboxed at runtime.
2. ⬜ **The domain.** `LegalLinks.host` is a placeholder (`watchdogapp.io`) and the landing
   site has no domain attached in `landing/vercel.json`. Reviewers click those links; a 404
   is an automatic rejection. Pick the domain, point it at Vercel, update `LegalLinks`.
3. ⬜ **Bundle ID.** Set to `com.markstudios.watchdog`, which assumes you own the matching
   App ID on your team. Register it, or change it to whatever you register.
4. ⬜ **App Store Connect.** Create the two subscription products in a subscription group,
   attach the 7-day introductory offer to the annual plan (the paywall advertises it — if it
   isn't configured there, the badge is false advertising under 2.3.1), and fill in the
   privacy policy URL, support URL, App Privacy label ("Data Not Collected"), and age rating.
5. ⬜ **Legal review.** `privacy.html` and `terms.html` are a solid, honest starting point,
   not legal advice. Have someone qualified read them before you rely on them — the
   limitation-of-liability and acceptable-use sections especially.
6. ⬜ **Free-tier data loss on lapse.** When a Pro subscription ends, captures older than
   3 days are now genuinely deleted. That is the honest reading of the tier, but a lapsed
   subscriber losing months of footage without warning will generate refund complaints.
   Consider a warning + export prompt before the first post-lapse prune.
7. ⬜ **F5, trial reset.** `TrialManager` keys the 7-day trial on a `UserDefaults` date, so
   deleting the prefs plist grants a fresh trial indefinitely. Not a review issue; your call
   whether to care.

---

## 6. Notes for App Review (draft)

Include these in the App Review notes field — camera-monitoring apps get manual scrutiny:

> Watchdog is a local security-monitoring utility for the user's own Mac. It uses the
> built-in camera to detect motion or faces in front of the machine and saves captures
> **locally on the device**. No capture data is transmitted to the developer or to any
> Watchdog-operated server; there is no account system and no analytics.
>
> The menu bar icon is always visible while the app is running, and macOS's green camera
> indicator is active whenever monitoring is on — the app cannot and does not conceal that
> the camera is in use. Monitoring never starts automatically; the user must explicitly
> enable it, after acknowledging a first-run notice about their responsibility to comply
> with local recording laws.
>
> Watchdog is not distributed with the network client entitlement, so it cannot make
> network requests at all. In-app purchases are brokered by StoreKit out of process.
>
> Test the Pro paywall with [sandbox account]. Free trial: 7 days on the annual plan.
