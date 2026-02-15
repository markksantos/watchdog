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
- Xcode 15+
- Camera access permission

### Installation

```bash
git clone https://github.com/markksantos/watchdog.git
cd watchdog
open Package.swift
```

Build and run in Xcode. Grant camera permissions when prompted.

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
Watchdog/
├── WatchdogApp.swift              # Entry point & AppDelegate
├── Detection/
│   ├── DetectionEngine.swift      # Core detection orchestrator
│   ├── CameraManager.swift        # Webcam input management
│   ├── FaceDetector.swift         # Vision-based face detection
│   ├── MotionDetector.swift       # Pixel-diff motion detection
│   └── VideoRecorder.swift        # H.264 video recording
├── Storage/
│   └── CaptureStore.swift         # JSON-based capture persistence
├── Models/
│   ├── CaptureRecord.swift        # Detection data model
│   ├── SettingsManager.swift      # User preferences
│   └── ScheduleConfig.swift       # Scheduled monitoring config
├── Monetization/
│   ├── SubscriptionManager.swift  # StoreKit 2 subscriptions
│   ├── TrialManager.swift         # Trial period logic
│   └── PaywallView.swift          # Upgrade UI
├── UI/
│   ├── MainWindow/
│   │   ├── MainWindowView.swift   # Grid gallery
│   │   └── CaptureDetailView.swift # Full-screen capture view
│   ├── MenuBar/
│   │   ├── StatusBarController.swift # Menu bar management
│   │   └── PopoverView.swift      # Quick-access popover
│   └── Preferences/
│       └── PreferencesView.swift  # Settings window
└── Utilities/
    ├── WakeDetector.swift         # Sleep/wake detection
    └── PDFExporter.swift          # PDF report generation
```

## 📄 License

MIT License © 2025 Mark Santos
