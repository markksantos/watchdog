# watchdog — Overnight Worklog

## What it is

Watchdog is a native macOS menu-bar security-camera app. It watches the webcam for
faces (Vision) or motion (Accelerate/vDSP pixel-diff), or captures on a timer, saves
JPEG snapshots (optionally 5-second H.264 clips), and surfaces them in a gallery /
live-preview / stats UI plus a menu-bar popover. Security responses (alarm siren via
synthesized audio, full-screen flash, stealth black-out, auto-lock), webhook alerts,
scheduled monitoring, and PDF reports are gated behind a StoreKit 2 subscription
(monthly/annual) with a 7-day trial. Pure Swift Package Manager, no third-party deps.

Stack: Swift 5.9, SwiftUI + AppKit, AVFoundation, Vision, Accelerate, StoreKit 2,
UserNotifications, IOKit power assertions. SwiftPM `executableTarget`.

## Starting state

Honest starting completeness: ~80%. This is a real, mature Mark-authored project with
8 prior commits of genuine feature work. Every core system was already implemented and
the package already built cleanly (`swift build` → 0 errors). What it lacked was the
production/distribution scaffolding around the code:

- No test target and no tests at all (despite finishTasks asking for them).
- No StoreKit configuration file, so the paywall could never load products or exercise
  a purchase in a dev/test build — the monetization core was untestable end-to-end.
- No CI.
- Build emitted SPM resource warnings; an empty `AppIcon.appiconset` and an empty
  `Preview Content` directory were dead weight.
- **3,400+ build-artifact files plus committed `.DS_Store` and Xcode user-state were
  tracked in git** — on a public remote. Major hygiene problem despite a correct
  `.gitignore` (the files were committed before the ignore rules applied).
- Landing page was wired for Netlify; Mark's policy is Vercel-only.
- README's project structure was stale and didn't mention tests/StoreKit/build script.

The detection engine, capture store, subscription/trial logic, all 10 Pro-feature gates,
PDF export, webhooks, alarm/flash/stealth/auto-lock, and the full UI were already done
and correct. I verified this by reading every source file — I did **not** rewrite it.

## What I changed, fixed, added, built

### Tests (new)
- Added a `WatchdogTests` SwiftPM test target (`Tests/WatchdogTests/`) with **26 passing
  unit tests**:
  - `TrialManagerTests` — fresh-install full trial, persisted first-launch date,
    day-by-day countdown, expiry, never-negative.
  - `ScheduleConfigTests` — same-day windows, overnight windows spanning midnight,
    morning-after-belongs-to-previous-weekday logic, weekday gating, empty-weekday,
    encode/decode parity, formatted ranges. Pinned to a fixed UTC calendar for
    determinism.
  - `SubscriptionModelTests` — `isProUser` gating across all 4 statuses, display names,
    Equatable, every `ProFeature` has icon/description, 10-feature count guard.
  - `CaptureRecordTests` — Codable round-trip, `hasVideo`/`videoURL`, unique IDs,
    interval/quality enum invariants.
- To make this logic deterministically testable **without changing app behavior**, I
  made two minimal seams injectable (production call sites unchanged via defaults):
  - `TrialManager` now takes `defaults`/`trialDuration`/`now` in its init.
  - `ScheduleConfig.isCurrentlyActive(now:calendar:)` now accepts an injectable clock
    and calendar (defaulting to `Date()` / `.current`).

### StoreKit (new)
- Added `Watchdog.storekit` — a StoreKit Testing configuration defining the two products
  the code already references (`com.watchdog.pro.monthly` $3.99, `com.watchdog.pro.annual`
  $29.99) in one "Watchdog Pro" subscription group, with the annual 7-day free-trial
  intro offer that the paywall advertises. This makes the paywall load real prices and
  makes purchases testable locally with no App Store Connect account. (Wiring it into the
  run scheme is a one-time Xcode UI step — documented in the README.)

### Build cleanliness
- `Package.swift`: excluded `Info.plist` + `Watchdog.entitlements`; moved the app icon to
  `Watchdog/Resources/AppIcon.icns` and copy it from there; added the test target. Result:
  **zero build warnings** in both debug and release (previously 2 warnings).
- `StatsView.swift`: removed a redundant `#available(macOS 14, *)` check nested inside an
  already-`@available(macOS 14, *)` type.
- Removed dead `Watchdog/Assets.xcassets` (empty `AppIcon.appiconset` + duplicate icns)
  and the empty `Watchdog/Preview Content` directory.
- `scripts/build-app.sh` and `scripts/make_icon.py` updated to the new `Resources/` icon path.

### Git hygiene (public repo)
- Untracked `.build/` (3,400+ files), `build/`, all `.DS_Store`, and Xcode user state
  (`xcuserstate`, per-user scheme management) — kept on disk, already covered by
  `.gitignore`. Tracked file count dropped from ~3,486 to 45 source files.

### CI (new)
- `.github/workflows/ci.yml` — on push/PR to main, runs `swift build`, `swift build -c
  release`, `swift test`, assembles the `.app` via `scripts/build-app.sh`, and verifies the
  bundle (binary + Info.plist + icon). SwiftPM cache + concurrency cancellation.

### Landing page → Vercel
- Replaced `landing/netlify.toml` with `landing/vercel.json` (same security headers + HSTS,
  `cleanUrls`). Pointed the dead hero "Download for macOS" `href="#"` at the GitHub
  releases page (sensible interim until a notarized DMG exists).

### Docs
- Rewrote the README getting-started (Xcode run, StoreKit scheme step, release `.app`
  build, `swift test`, CI), the project structure (now accurate: Resources/, Tests/,
  Notifications/, Utilities/, storekit), and added a Free-vs-Pro section.

## Current state

- **Builds?** Yes. `swift build` and `swift build -c release` both succeed with **zero
  warnings, zero errors** (Swift 6.3.2 toolchain / Apple Swift 5.9-compatible manifest).
- **Runs?** Yes. `bash scripts/build-app.sh` assembles `build/Watchdog.app`; launching it
  starts the menu-bar process (stable ~88 MB RSS) and it quits cleanly with no crash report.
  Full live detection requires camera permission (granted interactively at runtime).
- **Tests?** Yes — 26 unit tests, all passing (`swift test`).

## How to run it locally

```bash
cd /Users/markksantos/Developer/watchdog

# From source in Xcode (recommended for the paywall):
open Package.swift
#   then run the Watchdog scheme; grant camera permission when prompted.
#   To test subscriptions: Product > Scheme > Edit Scheme > Run > Options >
#   StoreKit Configuration > Watchdog.storekit

# Or build a standalone .app from the CLI:
swift build -c release
bash scripts/build-app.sh
open build/Watchdog.app

# Tests:
swift test
```

## How to deploy (when ready)

**App (the product) — needs Mark's Apple Developer account:**
1. Create the two auto-renewable subscriptions in App Store Connect with the exact IDs
   `com.watchdog.pro.monthly` and `com.watchdog.pro.annual` in one subscription group,
   annual carrying the 7-day free-trial intro offer (mirrors `Watchdog.storekit`).
2. Decide distribution: **Mac App Store** (then the StoreKit IDs go live as-is) **or
   notarized DMG** (then in-app StoreKit still works via App Store, and you ship the DMG).
3. For a DMG: create a proper signed/archived build (an `.xcodeproj` or `xcodebuild
   -create-xcframework`/`xcarchive` flow), code-sign with a Developer ID, `notarytool`
   submit + staple, package the DMG, and attach it to a GitHub release (the landing page
   download button already points at `/releases`).

**Landing page — Vercel (ready now):**
```bash
cd landing
vercel            # preview
vercel --prod     # production  (do NOT run unattended; Mark promotes)
```

## NEEDS FROM MARK

- **Apple Developer Program membership** — required to sign, notarize, and ship the app
  and to create live StoreKit products. Nothing here can be invented.
- **App Store Connect: create the two subscription products** with the exact IDs above
  (the code and `Watchdog.storekit` already assume them).
- **Distribution decision: Mac App Store vs. notarized DMG.** This changes the final
  packaging/signing pipeline (and whether an `.xcodeproj` archive flow is needed).
- (Optional) A real DMG artifact to attach to a GitHub release so the landing "Download"
  button resolves to a binary instead of the releases listing.

## Honest completeness % now and what remains

**~90%.** The app is feature-complete, builds clean, runs, and is fully tested at the unit
level; the paywall is now exercisable end-to-end under StoreKit Testing; CI, Vercel config,
and accurate docs are in place. The remaining ~10% is **entirely gated on Mark's Apple
Developer account** and an irreversible product decision (MAS vs DMG): real StoreKit
product creation, code-signing, notarization, and producing the shippable artifact. None of
that can be done autonomously or without paid Apple enrollment. No mock data or stubbed
features remain in the codebase.

## QA Verification

Reviewed by independent QA agent on 2026-06-01.

### Commands run

```
swift build              # debug
swift build -c release   # release
swift test               # all 26 tests
bash scripts/build-app.sh
```

### Real results

- `swift build` (debug): Build complete, 0 errors, 0 warnings. Confirmed.
- `swift build -c release`: Build complete, 0 errors, 0 warnings. Confirmed.
- `swift test`: All 26 tests passed (CaptureRecordTests 6, ScheduleConfigTests 10, SubscriptionModelTests 5, TrialManagerTests 5). Confirmed.
- `bash scripts/build-app.sh`: Assembled `build/Watchdog.app` successfully. Binary, Info.plist, and AppIcon.icns all present in the bundle. Confirmed.

### Claims verified

- 3 overnight commits present (local only, not pushed): confirmed.
- Zero build warnings in both debug and release: confirmed.
- 26 passing unit tests: confirmed.
- `Watchdog.storekit` present with two subscription products (`com.watchdog.pro.monthly` at $3.99 and `com.watchdog.pro.annual` at $29.99 with 7-day free-trial intro offer) in one "Watchdog Pro" group: confirmed.
- `landing/vercel.json` present with security headers and HSTS; `netlify.toml` absent: confirmed.
- Landing hero "Download for macOS" CTA now points to GitHub releases (not `#`): confirmed.
- `.build/` and other artifact directories untracked (git status clean): confirmed.

### Discrepancies

None. All build-agent claims checked out against actual command output.

### Fixes applied

None required.

### Remaining issues

No blocking issues. Non-blocking items already documented in NEEDS FROM MARK:
- Apple Developer Program account required for code-signing, notarization, and live StoreKit products.
- App Store Connect subscription products must be created manually with the exact IDs in Watchdog.storekit.
- Distribution format decision (MAS vs notarized DMG) still open.
