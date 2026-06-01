<div align="center">

# 👁️ Watchdog

**macOS webcam monitoring app with face detection, motion detection, and scheduled capture**

[![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)](#)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-007AFF?style=for-the-badge&logo=apple&logoColor=white)](#)
[![Vision](https://img.shields.io/badge/Vision_Framework-34C759?style=for-the-badge&logo=apple&logoColor=white)](#)
[![macOS](https://img.shields.io/badge/macOS_13+-000000?style=for-the-badge&logo=apple&logoColor=white)](#)

[Features](#-features) · [Getting Started](#-getting-started) · [Tech Stack](#️-tech-stack)

</div>

---

## ✨ Features

- **Face Detection** — Vision framework-powered face detection triggers automatic capture
- **Motion Detection** — Frame-to-frame pixel comparison using Accelerate for efficient SIMD operations
- **Always-On Mode** — Capture at configurable intervals (5–60 seconds)
- **Video Recording** — Record short 5-second H.264 clips alongside screenshots (Pro)
- **Scheduled Monitoring** — Enable/disable monitoring during specific time windows (Pro)
- **Webhook Alerts** — Send capture notifications to custom HTTP endpoints (Pro)
- **Menu Bar App** — Runs in the menu bar with status indicator and quick-access popover
- **PDF Export** — Generate capture reports as PDF documents
- **Gallery View** — Browse captures in a grid grouped by date with full-screen detail view
- **Detection Debouncing** — 3-second cooldown prevents duplicate triggers

## 🚀 Getting Started

### Prerequisites

- macOS 13.0+
- Xcode 15+ (or the Swift 5.9+ toolchain)
- Camera access permission

### Run from source (Xcode)

```bash
git clone https://github.com/markksantos/watchdog.git
cd watchdog
open Package.swift
```

Build and run in Xcode (the `Watchdog` scheme). Grant camera permissions when prompted.

To exercise the paywall and subscription flow locally, point the run scheme at the
bundled StoreKit configuration: **Product → Scheme → Edit Scheme → Run → Options →
StoreKit Configuration → `Watchdog.storekit`**. This makes the two Pro products
(`com.watchdog.pro.monthly`, `com.watchdog.pro.annual`) and the 7-day annual free
trial purchasable in StoreKit Testing without an App Store Connect account.

### Build a distributable `.app`

```bash
swift build -c release
bash scripts/build-app.sh   # assembles build/Watchdog.app
```

`scripts/make_icon.py` regenerates the app icon into `Watchdog/Resources/AppIcon.icns`
(requires Pillow + the macOS `iconutil`).

### Test

```bash
swift test   # 26 unit tests: trial logic, schedule windowing, gating, persistence
```

CI (`.github/workflows/ci.yml`) runs debug + release builds, the full test suite, and
verifies the assembled `.app` bundle on every push and PR.

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| Language | Swift 5.9 |
| UI | SwiftUI + AppKit |
| Detection | Vision framework (face), Accelerate (motion) |
| Camera | AVFoundation |
| Video | CoreMedia, AVAssetWriter (H.264) |
| Subscriptions | StoreKit 2 |
| Notifications | UserNotifications |
| Build | Swift Package Manager |

## 📁 Project Structure

```
.
├── Package.swift                  # SwiftPM manifest (executable + test target)
├── Watchdog.storekit              # StoreKit Testing config (Pro products + trial)
├── Watchdog/
│   ├── WatchdogApp.swift          # Entry point & AppDelegate
│   ├── Detection/                 # DetectionEngine, Camera/Face/Motion, VideoRecorder
│   ├── Storage/CaptureStore.swift # JSON-based capture persistence + free-tier limit
│   ├── Models/                    # CaptureRecord, SettingsManager, ScheduleConfig, ProFeature
│   ├── Monetization/              # SubscriptionManager (StoreKit 2), TrialManager, PaywallView
│   ├── Notifications/             # NotificationManager, WebhookManager
│   ├── UI/                        # MenuBar, MainWindow (gallery/live/stats), Preferences
│   ├── Utilities/                 # Alarm, Flash, AutoLock, Stealth, Hotkey, Power, Wake, PDF
│   ├── Resources/AppIcon.icns     # App icon (bundled as an SPM resource)
│   ├── Info.plist
│   └── Watchdog.entitlements      # camera, network.client, photos-library
├── Tests/WatchdogTests/           # XCTest: trial, schedule, gating, persistence
├── scripts/                       # build-app.sh, make_icon.py
├── landing/                       # Marketing page (index.html) + vercel.json
└── .github/workflows/ci.yml       # Build + test + bundle verification
```

## 💳 Free vs. Pro

The free tier keeps 3 days of capture history and the three core detection modes.
A 7-day trial unlocks everything; afterward the 10 Pro capabilities
(unlimited history, scheduling, video recording, webhooks, advanced PDF, stats
dashboard, alarm, flash, stealth, auto-lock) are gated behind a StoreKit 2
subscription. Every Pro gate is enforced at runtime in both the UI and the
detection engine via `SubscriptionManager.hasAccess(to:)`.

## 📄 License

MIT License © 2025 Mark Santos
