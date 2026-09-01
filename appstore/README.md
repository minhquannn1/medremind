# App Store assets — Medoly 1.0.0

Listing copy lives in [`../docs/app-store-listing.md`](../docs/app-store-listing.md);
review notes in [`../docs/app-review-notes.md`](../docs/app-review-notes.md).

## What to upload

| Folder | Size | Where it goes in App Store Connect |
| --- | --- | --- |
| `screenshots/iphone-6.9-vi/` | 1320 × 2868 | iPhone 6.9" — Vietnamese localization |
| `screenshots/iphone-6.9-en/` | 1320 × 2868 | iPhone 6.9" — English (U.S.) localization |
| `screenshots/ipad-13-vi/` | 2064 × 2752 | iPad 13" — only needed while the app declares iPad support |

Apple generates the smaller iPhone sizes (6.5", 6.1") from the 6.9" set
automatically, so one set per language is enough.

Upload them in filename order — the numbering is the intended story:

1. Home / today's doses (the hero shot)
2. Scan review — AI-extracted prescription with drug uses
3. Medication detail — what the medicine is for
4. Schedule
5. Dose history
6. Prescriptions list
7. Health profile

## iPad support

The binary ships as iPhone + iPad, which is why Apple asks for iPad screenshots.
On a 13" iPad the layout is a stretched phone UI with a lot of empty space (see
`raw/ipad/`). The iPad set is included in case tablet support is kept.

To go iPhone-only, edit the **Xcode project**, not `app.json` — this is a
non-CNG project, so `expo.ios.supportsTablet` is ignored (see `CLAUDE.md`):

```
ios/Medoly.xcodeproj/project.pbxproj
  TARGETED_DEVICE_FAMILY = "1,2";   →   TARGETED_DEVICE_FAMILY = "1";
```

(or set *Supported Destinations* to iPhone only in Xcode's target editor), then
rebuild. That drops the iPad screenshot requirement and avoids review comments
about the tablet experience.

## Regenerating

`raw/` holds the unframed device captures (straight from the simulator). They are
the input for any screenshot framing tool — e.g. the local copy of
[appscreen](https://github.com/YUZU-Hub/appscreen), which runs at
`http://localhost:8000` after `python3 -m http.server 8000` inside that repo.
Drop a `raw/` folder in, pick a background and headline, and export.

Captures were taken on an iPhone 17 Pro Max and iPad Pro 13" simulator with a
seeded demo patient (see `docs/app-review-notes.md` for the demo account) and a
status bar overridden to 9:41 / full signal.
