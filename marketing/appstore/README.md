# Watchdog — App Store & marketing assets

Brand: red `#FF3B30` on charcoal, watchful-eye mark.

There are **two** gallery sets. Screenshots depict the **real running app** (App Review requires
this); the cinematic set composites that real UI into AI-generated scenes for impact.

---

## `gallery-cinematic/` — recommended App Store screenshots ⭐

Six 2560×1600 (16:10) images: an AI-generated cinematic scene (Nanobanana Pro) with the **real
app window** composited in and a headline. Upload these in order:

1. `01-hero.png` — night desk, "See who walked up to your Mac"
2. `02-detection.png` — doorway, "Three ways to watch"
3. `03-quality.png` — camera macro, "Capture in the detail you choose"
4. `04-appearance.png` — color-pop desk, "Make it yours"
5. `05-alerts.png` — red-lit room, "Know the moment it happens"
6. `06-privacy.png` — cozy home, "Everything stays on your Mac"

`backgrounds/` holds the AI scenes (2560px) without UI or text, for re-editing.

**Compliance note:** each frame contains a genuine screenshot of the app, so it satisfies the
"screenshots must show the app" rule while still selling the product. Pure AI images with no UI
would risk rejection — that's why these are composites, not illustrations.

## `gallery/` — plain screenshots (alternative)

The earlier set: real UI on a flat branded gradient. Cleaner but less punchy. Keep as a fallback
or for a minimalist listing.

## `video/` — App Preview video

- `watchdog-preview.mp4` — 1920×1080, H.264, 24s, 30fps. Within Apple's 15–30s App Preview spec.
  Intro → five animated feature scenes (real UI over the cinematic scenes) → outro.
- `poster.png` — a poster frame; App Store Connect lets you pick the still shown before playback.

Built with Remotion; the project source is in `../../video/` (see below) so it can be re-rendered
or edited.

## `icon/` — app icon

| File | Use |
|---|---|
| `AppStore-marketing-1024.png` | App Store Connect marketing icon. Flattened, **no alpha, square** — Apple masks it. |
| `Watchdog.icns` / `AppIcon.iconset/` | The rounded app-bundle icon (already shipping). |
| `icon_16…1024.png` | Rounded PNGs for web/press. |

## `screenshots/` — unframed UI captures

The plain retina window captures (`preferences-*.png`) behind everything else — for the landing
page or press kit.

## `../promo/` — fully-AI promo art (landing + social)

- `landing-hero-2560x1440.png` — website hero (glowing eye + headline + CTA).
- `social-1200x1200.png` — square social card (Twitter / Product Hunt).
- `eye-hero-background-4k.png` — the bare eye scene, no text, for reuse.

These are pure marketing art (no app UI required), so anything goes.
⚠️ The landing hero's "Download on the Mac App Store" pill is a **placeholder** — the app isn't
live yet, and Apple's official download badge has brand rules. Swap in the real badge at launch.

## `../video/` — Remotion project (video source)

Reproducible source for the App Preview video.

```bash
cd marketing/video
npm install
npx remotion render src/index.ts WatchdogPreview out/preview.mp4 --codec h264
# or:  npx remotion studio src/index.ts   # to edit interactively
```

`public/` holds the downscaled scene + UI assets it renders from. `node_modules/` and `out/` are
gitignored.

---

## Still needed (deliberately not generated)

The live camera feed and the captures gallery show whoever is in front of the Mac — real footage
of the developer's space — so they're omitted from all sets. Add them with **neutral sample
footage** (point the camera at a doorway/empty desk, capture, then reframe with the same pipeline).

## Metadata checklist (App Store Connect text fields)

- [ ] Name, subtitle, promotional text · Description (adapt from `landing/index.html`) · Keywords
- [ ] Support + Marketing URL (`nosleeplab.com/apps/watchdog`) · Privacy Policy URL (`landing/privacy.html`)
- [ ] App Privacy answers — correct answers in `tasks/app-store-compliance.md` §4
- [ ] Category: Utilities
