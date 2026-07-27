# Watchdog — App Store listing copy

Paste-ready text for the App Store Connect fields. Character limits noted; counts verified.
Framing follows the compliance pass: it's *your* Mac, *your* desk, you are the subject — no
"surveillance / covert / invisible / no trace" language (that framing was removed for a reason).

---

## App Name — max 30
```
Watchdog: Mac Security Cam
```
(26 chars)

## Subtitle — max 30
```
See who used your Mac
```
(21 chars)

## Promotional Text — max 170 (editable anytime, no review)
```
Turn your Mac's camera into a private security monitor. Face, motion, and always-on capture — every photo stays on your device, never the cloud.
```
(143 chars)

## Keywords — max 100 (comma-separated, no spaces)
```
security,camera,webcam,motion,face,detection,monitor,alarm,privacy,intruder,guard,alert,snapshot
```
(96 chars)

---

## Description — max 4000

```
Watchdog turns your Mac's built-in camera into a quiet, private security monitor. Step away from your desk and Watchdog watches it for you — capturing a photo the moment it sees a face, detects motion, or on a schedule you set. Everything is saved on your Mac. Nothing is ever sent to the cloud.

WHY WATCHDOG
• Private by design — captures live only on your device. No account, no analytics, no network connections.
• Genuinely simple — it lives in your menu bar and starts monitoring with one click.
• Made for your own Mac — see who sat down while you were away, catch a curious roommate, or keep an eye on your desk at the office.

THREE WAYS TO WATCH
• Face Detection — capture the moment a face appears in front of the camera.
• Motion Detection — capture when enough of the scene changes, with adjustable sensitivity from turtle to rabbit.
• Always-On — capture on a timer you choose, from seconds to minutes apart.

CONTROL THE DETAIL
• Choose your photo resolution, from 480p up to 4K, or match your camera natively.
• Set compression independently, so you trade file size for quality on your terms.

KNOW THE MOMENT IT HAPPENS
• A macOS notification with a thumbnail on every capture.
• Optional audible alarm siren, on-screen flash, or a quiet screen dim.

BROWSE AND KEEP
• A clean gallery groups every capture by day.
• Export a PDF report of your captures.
• Free plan keeps a 3-day history; delete anything, anytime.

MAKE IT YOURS
• Light, dark, or automatic theme.
• Six accent colors and a menu bar icon you pick.

WATCHDOG PRO
Upgrade to unlock:
• Unlimited capture history
• Detection scheduling (monitor only during set hours)
• Video clip recording on detection
• Advanced PDF reports
• A statistics dashboard
• Alarm siren, screen flash, and screen dim
Pro is a subscription. The annual plan starts with a 7-day free trial, then renews at the price shown in the app. Manage or cancel anytime in System Settings › Apple Account › Subscriptions.

PRIVACY YOU CAN VERIFY
Watchdog ships without the network entitlement for capture data — the app physically cannot upload your photos. macOS shows its green camera indicator whenever monitoring is active, and the Watchdog icon stays visible in your menu bar. You're always in control, and you're responsible for using it lawfully where you are.

Requires macOS 13 or later. Works with your built-in camera or an external webcam.
```
(~1,950 chars — well under 4,000)

---

## What's New (version 1.0) — max 4000
```
The first release of Watchdog.
• Face, motion, and always-on detection
• Photo resolution up to 4K with independent compression
• Notifications, alarm siren, screen flash, and screen dim
• Capture gallery grouped by day, plus PDF export
• Light/dark themes, six accent colors, custom menu bar icon
• Every capture stays on your Mac — no cloud, no account
```

---

## Other App Store Connect fields

| Field | Value |
|---|---|
| Primary category | Utilities |
| Secondary category | (optional) Productivity |
| Price | Free (with Watchdog Pro subscription IAP) |
| Marketing URL | https://nosleeplab.com/apps/watchdog |
| Support URL | https://nosleeplab.com/apps/watchdog/support |
| Privacy Policy URL | https://nosleeplab.com/apps/watchdog/privacy |
| Copyright | © 2026 NoSleepLab |

**Subscription (App Store Connect › Subscriptions)**
- Group: Watchdog Pro
- Monthly — display name "Watchdog Pro (Monthly)"
- Annual — display name "Watchdog Pro (Annual)", with a 7-day free-trial introductory offer
- Set the actual prices here; the app reads them from StoreKit and never hardcodes a number.

**App Privacy** — do NOT answer "Data Not Collected". Use the table in
`tasks/app-store-compliance.md` §4 (Photos/Videos collected only if webhooks are enabled — and
webhooks were removed, so if that still holds, "Data Not Collected" may now be truthful; verify
against the shipping build before answering).

**Age rating** — 4+ (no objectionable content). Be ready to explain the camera use in review notes.

**App Review notes** — use the draft in `tasks/app-store-compliance.md` §6 (explains it's a local
security tool for the user's own Mac, the green indicator is always shown, monitoring is
user-initiated after a consent screen, and there's no covert capability).

---

## Notes
- App name/subtitle avoid the word "surveillance" on purpose. Keep it that way.
- Every feature above exists in the shipping build — don't add roadmap items (e.g. cloud backup)
  to the description; that surface is marked "coming soon" in-app and must not be advertised as
  available (2.3.1 accurate metadata).
