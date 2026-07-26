# Watchdog — App Store marketing assets

Everything needed for the Mac App Store listing. All screenshots are captures of the **real
running app** (App Review requires screenshots to depict the actual UI), framed on-brand.

Brand: red `#FF3B30` on charcoal, watchful-eye mark.

---

## `icon/` — app icon

| File | Size | Use |
|---|---|---|
| `AppStore-marketing-1024.png` | 1024×1024 | **App Store Connect → App Information → App Icon.** Flattened RGB, **no alpha, square (not rounded)** — Apple applies the mask itself. |
| `Watchdog.icns` | multi | The app-bundle icon (rounded squircle, with transparency). Already installed in the shipping app; here for reference. |
| `AppIcon.iconset/` | 16→1024 @1x/@2x | Source iconset the `.icns` is built from. Regenerate with `iconutil -c icns AppIcon.iconset`. |
| `icon_16 … icon_1024.png` | individual | Rounded PNGs at each size, for web/press/README use. |

**Important:** the App Store Connect marketing icon and the in-app icon are *different files* —
the marketing icon must be a full-bleed square with no transparency and no rounded corners.
Use `AppStore-marketing-1024.png` for the listing, not the rounded one.

## `gallery/` — App Store screenshots (upload these)

Six framed 2560×1600 (16:10) images — the standard Mac retina screenshot size App Store
Connect accepts. Upload in this order:

1. `01-hero.png` — icon + "See who walked up to your Mac"
2. `02-camera.png` — "Three ways to watch" (detection modes)
3. `03-recording.png` — "Capture in the detail you choose" (480p–4K)
4. `04-appearance.png` — "Make it yours" (themes + accents)
5. `05-alerts.png` — "Know the moment it happens"
6. `06-storage.png` — "Everything stays on your Mac" (privacy)

App Store Connect accepts 1–10 Mac screenshots; 2560×1600 or 2880×1800 (16:10). These are
2560×1600. You can drop any you don't want.

## `screenshots/` — plain UI captures

The unframed retina window captures behind the gallery frames (`preferences-*.png`). Handy for
the landing page, press kit, or README — not for direct App Store upload (the framed
`gallery/` versions are the marketing ones).

---

## Still needed (deliberately not generated)

Two screens would round out the set but need **non-personal sample footage** — the live camera
feed and the captures gallery show whoever is in front of the Mac, which right now is real
footage of the developer's room. They were left out rather than ship someone's face in a
public listing. To add them:

1. Point the camera at a neutral scene (a doorway, an empty desk) and let it capture a few frames.
2. Capture the main window's **Captures** and **Live** views.
3. Frame them with the same `gen_slides.py` pipeline (captions e.g. "Every capture, organised by
   day" and "Watch live, any time").

## Metadata checklist (App Store Connect text fields, not in this folder)

- [ ] App name, subtitle, promotional text
- [ ] Description (adapt from `landing/index.html`)
- [ ] Keywords
- [ ] Support URL + Marketing URL (`nosleeplab.com/apps/watchdog` — see `LegalLinks.swift`)
- [ ] Privacy Policy URL (required; page exists in `landing/privacy.html`)
- [ ] App Privacy answers (the audit in `tasks/app-store-compliance.md` §4 has the correct answers)
- [ ] Category: Utilities

## Regenerating

Assets are reproducible from the app itself:
- Icon sizes: `sips` from `branding/watchdog-icon-1024.png` (rounded) and the 4K master.
- Screenshots: capture the app windows, then `scratchpad/gen_slides.py` + a headless render at
  2560×1600. The generator and per-slide HTML are in the working scratchpad for this session.
