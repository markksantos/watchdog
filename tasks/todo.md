# Watchdog - Build Progress

## Phase 1: Core Build (Complete)
- [x] Shared models (CaptureRecord, SettingsManager, DetectionMode)
- [x] App entry point (WatchdogApp.swift, AppDelegate)
- [x] Info.plist (camera permission, LSUIElement)
- [x] Package.swift with LaunchAtLogin dependency
- [x] Detection engine (CameraManager, FaceDetector, MotionDetector, DetectionEngine)
- [x] Menu bar UI (StatusBarController, PopoverView)
- [x] Main window (MainWindowView, CaptureDetailView)
- [x] Preferences (PreferencesView)
- [x] Storage (CaptureStore)
- [x] Notifications (NotificationManager)
- [x] Wake detection (WakeDetector)
- [x] PDF export (PDFExporter)
- [x] Integration fixes (method name mismatches, onCapture wiring)

## Phase 2: Monetization Implementation (Complete)

### Phase 2.0: Shared Contracts
- [x] Create `ProFeature` enum and `SubscriptionStatus` enum
- [x] Create `ScheduleConfig` model
- [x] Add `videoPath: String?` to `CaptureRecord`

### Phase 2.1: Agent 1 — Monetization (Subscription + Paywall)
- [x] Create `SubscriptionManager.swift`
- [x] Create `TrialManager.swift`
- [x] Create `PaywallView.swift`
- [x] Modify `SettingsManager.swift` (computed isPaid, new settings)
- [x] Modify `WatchdogApp.swift` (init SubscriptionManager)
- [x] Modify `Watchdog.entitlements` (network.client)
- [x] Modify `Package.swift` (StoreKit, AVKit)

### Phase 2.2: Agent 2 — Pro Features (Detection + Recording + Stats)
- [x] Create `VideoRecorder.swift`
- [x] Create `WebhookManager.swift`
- [x] Create `StatsView.swift`
- [x] Modify `DetectionEngine.swift` (video, schedule)
- [x] Modify `CameraManager.swift` (videoDimensions)
- [x] Modify `CaptureStore.swift` (updateCapture, video cleanup, webhook)
- [x] Modify `PDFExporter.swift` (advanced PDF)

### Phase 2.3: Agent 3 — UI Integration
- [x] Modify `PreferencesView.swift` (full rewrite subscription section)
- [x] Modify `MainWindowView.swift` (tabs, video badge, paywall)
- [x] Modify `CaptureDetailView.swift` (video player)
- [x] Modify `PopoverView.swift` (badges, schedule, upgrade)
- [x] Modify `StatusBarController.swift` (subscriptionManager)

### Verification
- [x] `swift build` succeeds (zero errors)
- [ ] App launches with subscription badge
- [ ] Free tier gates all 6 features
- [ ] PaywallView opens from all entry points
- [ ] Trial countdown works

### Phase 2.4: Bug Fix & Polish Pass (Complete)
- [x] CRITICAL: PreferencesView & MainWindowView use @EnvironmentObject for SubscriptionManager (UI now reacts to purchase)
- [x] Remove dead scheduleCheckTimer + checkSchedule() from DetectionEngine
- [x] Add videoPath existence validation in CaptureStore.loadCaptures()
- [x] WebhookManager: remove unnecessary DispatchQueue.main.async, dispatch network to background
- [x] VideoRecorder: ensure completion always fires in cleanup() (no lost callbacks)
- [x] StatusBarController: safe cast in NSImage tinting (as? instead of as!)
- [x] StatsView: added safety comment on Charts import for macOS 13
- [x] `swift build` passes (zero errors)
- [ ] Runtime verification (manual testing needed)

## Phase 3: Polish (TODO)
- [ ] App icon asset
- [ ] Xcode project file (proper pbxproj with all sources)
- [ ] Unit tests
