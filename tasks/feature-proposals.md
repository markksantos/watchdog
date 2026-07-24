# Watchdog — 24 proposed features

Written after the UI rebuild, against the constraints the App Store compliance pass
established: sandboxed, no global hotkeys, no screen locking, no private API, and a privacy
label that currently says "no data collected". Each entry notes whether it is safe inside
those constraints.

Legend: **[SAFE]** ships under the current entitlements · **[ENTITLEMENT]** needs a new
entitlement + usage string + privacy-label change · **[RISK]** touches an area App Review
scrutinises on camera apps.

---

## Tier 1 — build these first

These five give the most value per unit of work, and three of them fix real gaps rather than
adding surface.

### 1. Pre-roll buffer — save the seconds *before* the trigger **[SAFE]**
Keep a rolling in-memory ring buffer of recent frames; on detection, write the 5 seconds
*preceding* it alongside the capture. Right now the trigger frame is the first frame, so the
approach — the part that shows who arrived and from where — is never recorded. This is the
single largest evidence improvement available and needs no new permissions.

### 2. Disk budget guard **[SAFE]**
Stop, or rotate oldest-first, when free space drops below a set floor. The new custom
interval allows 1-second captures at 4K, which can fill a disk overnight. There is currently
no ceiling of any kind — `CameraManager` writes until the write fails, then silently returns
nil. A monitoring app that dies quietly is worse than one that refuses to start.

### 3. Motion zones (region-of-interest mask) **[SAFE]**
Let the user paint out regions to ignore — a monitor, a window, a hallway. `MotionDetector`
already computes a per-pixel difference; masking is a filter over that array, so the cost is
low. This is the highest-leverage fix for false positives, more so than tuning sensitivity.

### 4. Sensitivity auto-calibration **[SAFE]**
Sample ~30 seconds of the empty room, measure baseline frame change, and recommend a
sensitivity level. The 1–10 scale now has meaning but the user still has to guess; this turns
guessing into a measurement.

### 5. Onboarding wizard **[SAFE]**
Camera check → recording notice (already built) → calibration → first test capture. The
consent screen exists but drops the user straight into an unconfigured app. This is also
where App Review forms its first impression.

---

## Tier 2 — detection intelligence

### 6. Person vs. pet vs. object classification **[SAFE]**
`VNRecognizeAnimalsRequest` and body-pose detection are on-device Vision APIs. Filtering
"cat walked past" from "person entered" removes the most common false positive and needs no
network or new permission.

### 7. Known-face allowlist **[RISK]**
Compute face embeddings on-device and skip alerts for enrolled faces — "don't alert on me".
Genuinely useful, but storing biometric templates changes the privacy label and invites
scrutiny. Would need explicit enrolment consent and a clear delete path.

### 8. Audio trigger **[ENTITLEMENT]**
Capture on a loud sound (glass, door). Needs `device.audio-input`,
`NSMicrophoneUsageDescription`, and a privacy-label update. Meaningful scope increase — a
camera app that also listens is a different product to review.

### 9. Escalation rules **[SAFE]**
Only fire the siren/flash if N detections occur within M minutes. Turns a twitchy detector
into a credible alarm and cuts alert fatigue.

### 10. Multi-camera monitoring **[SAFE]**
Watch the built-in and an external camera at once. `CameraManager` currently holds a single
session; this means N sessions and per-camera settings.

---

## Tier 3 — capture and evidence

### 11. Tamper-evident capture log **[SAFE]**
Hash each capture and chain the hashes in `captures.json`. Lets a user demonstrate a sequence
hasn't been altered or back-dated. For anyone using this as actual evidence, it is the
difference between a folder of JPEGs and a record.

### 12. Encrypted capture vault **[SAFE]**
Passphrase-protected storage. These are photographs of people, currently sitting unencrypted
in `~/Pictures`. The compliance audit flagged this (F6); it is not required by Apple but is
the right thing for the app's actual content.

### 13. Burst capture on detection **[SAFE]**
`DetectionEngine.burstCapture(duration:)` already exists and nothing calls it. Wire it to a
setting — 3–5 stills beat one blurry frame.

### 14. Timelapse export **[SAFE]**
Compile a day of captures into a single scrubable video. Far faster to review than a grid.

### 15. Near-duplicate collapsing **[SAFE]**
Group visually near-identical consecutive captures into one gallery entry with a count. A
curtain moving for an hour currently produces hundreds of separate cells.

### 16. Capture notes and tags **[SAFE]**
Annotate a capture ("delivery", "false alarm"). Feeds search, and makes the PDF export
useful as a report rather than a contact sheet.

---

## Tier 4 — review and awareness

### 17. Timeline / activity view **[SAFE]**
Captures per hour as a scrubable strip, replacing grid-only browsing. Answers "when did
things happen" — which is the actual question — instead of "what do I have".

### 18. Live preview on menu bar hover **[SAFE]**
Peek at the current camera frame without opening a window.

### 19. Quiet hours **[SAFE]**
Suppress sirens and notifications during set windows while still capturing. The existing
schedule disables *monitoring*; this separates recording from alerting, which are different
decisions.

### 20. Weekly digest **[SAFE]**
A local summary notification: captures, busiest hours, anything unusual. No server involved.

### 21. Companion iOS app for remote alerts **[ENTITLEMENT]**
The honest replacement for the webhook feature that compliance removed. Via CloudKit push,
this stays inside Apple's ecosystem — no user-supplied endpoints, no plaintext exfiltration.
Significant work and a real privacy-label change, but it is the feature people actually want
from a security camera.

---

## Tier 5 — polish

### 22. Full-text and semantic capture search **[SAFE]**
Search by date, detection type, tags — and optionally on-device image content.

### 23. Side-by-side capture compare **[SAFE]**
Two captures at once, for "what changed on the desk while I was out".

### 24. Per-detection-type retention **[SAFE]**
Keep face detections for 30 days, always-on frames for 3. Better data minimisation than one
global rule, and it maps cleanly onto what the privacy policy already promises.

---

## Deliberately not proposed

- **Hiding the menu bar icon** — the compliance pass removed this claim from the landing page
  because it was both false and a 5.1.2 rejection. It should stay removed.
- **Screen locking on detection** — no sanctioned public API from a sandboxed app; the
  private `login.framework` route is an automatic rejection.
- **Global hotkeys** — needs Input Monitoring trust that a sandboxed Mac App Store app cannot
  obtain, and reads as keylogging on a camera app.
- **User-supplied webhooks** — removed for good reason. Feature 21 is the compliant version.
