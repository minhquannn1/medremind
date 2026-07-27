# MedRemind 💊

A medication adherence app that connects a doctor's prescription to a patient's
daily routine: it reminds patients to take medicine on time, tracks what they've
taken, and surfaces refill / follow-up reminders. Built with **Expo (React
Native)** for **iOS and Android**, **local-first** (offline SQLite), and
**bilingual** (Tiếng Việt / English).

## Core flow

1. Add a prescription — **type it in** or **scan it** (photo → AI extracts the
   medicines, doses, times and what each drug is for).
2. Review and adjust intake times to fit your daily routine.
3. Get **alarm-style reminders** at each dose time.
4. **Tick "Đã uống" / "Taken"** — stock count decrements automatically.
5. See **7-day adherence**, low-stock alerts, and follow-up reminders.

## Tech stack

| Concern        | Choice                                            |
| -------------- | ------------------------------------------------- |
| Framework      | Expo SDK 54 + TypeScript + Expo Router            |
| Local database | expo-sqlite + Drizzle ORM (offline, local-first)  |
| Reminders      | expo-notifications (daily scheduled local alarms) |
| Scan           | expo-camera + expo-image-picker → GPT-4o vision via `server/` |
| Backend        | Express API on Railway (scan proxy, accounts, doctor portal)   |
| State          | Zustand                                           |
| i18n           | i18next + expo-localization (vi / en)             |
| Design system  | Custom tokens in `src/theme` ("soft clinical")    |

## Project structure

```
app/                      # Expo Router routes (screens)
  _layout.tsx             # Boot: DB init, i18n, notifications
  index.tsx               # Onboarded? → tabs : onboarding
  onboarding.tsx          # Patient profile setup
  (tabs)/                 # Home · Prescriptions · Schedule · Profile
  prescription/           # new · [id] · scan
  medication/[id].tsx     # Medication detail + editable times
  appointment/new.tsx     # Revisit / refill reminder
  settings.tsx
src/
  theme/                  # Design tokens (color, type, spacing, shadow)
  components/ui/          # Reusable primitives (Button, Card, Input, …)
  components/             # Composite components (DoseCard, MedicationRow)
  db/                     # client · schema · init · repositories/
  features/               # auth · medication · notifications · prescription
                          # profile · scan · sync
  content/                # encouragements · lifestyle tips (bilingual)
  i18n/                   # locales/vi.ts · locales/en.ts
  store/                  # appStore (zustand)
  lib/                    # date helpers (dayjs)
```

## Running it

### Install

```bash
npm install
```

### Run on a device or simulator (this is the real app)

```bash
npm run ios          # = npx expo run:ios
npm run android      # = npx expo run:android
```

The first run does `pod install` and a full native build (5–10 min); later runs
are incremental. Requires **Xcode + CocoaPods** for iOS, **Android Studio + JDK 17**
for Android. `ios/` is committed, so no `prebuild` step is needed.

Useful flags:

```bash
npx expo run:ios --device                    # pick a simulator/device interactively
npx expo run:ios --configuration Release     # standalone build, no Metro needed
```

### Quick UI check only (Metro / web)

```bash
npx expo start       # then press i / a, or open the web build
```

`expo start` alone only serves the JS bundle — it does **not** produce an iOS app.
If you have not run `expo run:ios` at least once, there is no native app to open,
which is why the web target is all you get. Prescription scanning needs a real
camera, so it cannot be tested on web.

> Scanning does **not** use an on-device OCR library. The photo is sent to
> `server/`, which calls GPT-4o vision. Do not install `@react-native-ml-kit/*` —
> it was removed, and adding it breaks the iOS build because it is not in
> `ios/Podfile.lock`.

### Typecheck

```bash
npm run typecheck
```

### Validate the bundle without a device

```bash
npx expo export --platform ios       # produces a JS bundle; catches import/build errors
npx expo export --platform android
```

## Building for the App Store (Xcode — no EAS)

This project does **not** use EAS. There is no `eas.json` and no `eas-cli`
dependency; builds are made locally with Xcode, which is free and has no queue.

```bash
open ios/MedRemind.xcworkspace          # always the .xcworkspace, not .xcodeproj
```

In Xcode:

1. Select **Any iOS Device (arm64)** as the destination (not a simulator).
2. Set your Team under *Signing & Capabilities* — signing is automatic.
3. Bump `CFBundleVersion` (build number) if you already uploaded this version.
4. **Product → Archive**, then **Distribute App → App Store Connect → Upload**.

The JS bundle is compiled into the archive, so no Metro server is involved.

Before archiving, sanity-check the bundle and types:

```bash
npm run typecheck
npx expo export --platform ios      # catches import/bundling errors without a device
```

The version string lives in `app.json` (`expo.version`) and must match the
version you create in App Store Connect. Listing copy, review notes and
screenshots are in [`docs/`](docs/) and [`appstore/`](appstore/).

### Android

```bash
npx expo run:android --variant release
```

Then build the AAB from `android/` with Gradle (`./gradlew bundleRelease`) for
Play Console upload.

## Data model

`patients` → `prescriptions` → `medications` → `schedule_times` → `dose_logs`,
plus `medical_conditions`, `allergies`, `appointments`, and `settings`. Data lives
on the device (SQLite) and works offline; when signed in it is also backed up to
the server so it restores on a new phone. See `src/db/schema.ts`.

## Roadmap (not yet built)

- Multi-patient / caregiver profiles (schema already keys by `patient_id`)
- Medicine photos synced across devices (currently device-local files)
- Push notifications from the doctor portal (local notifications only today)
```
