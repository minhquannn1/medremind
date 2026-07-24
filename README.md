# MedRemind 💊

A medication adherence app that connects a doctor's prescription to a patient's
daily routine: it reminds patients to take medicine on time, tracks what they've
taken, and surfaces refill / follow-up reminders. Built with **Expo (React
Native)** for **iOS and Android**, **local-first** (offline SQLite), and
**bilingual** (Tiếng Việt / English).

## Core flow

1. Add a prescription — **type it in** or **scan it** (capture photo + optional
   on-device OCR auto-extraction).
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
| Scan           | expo-camera (capture) + expo-image-picker         |
| OCR (optional) | `@react-native-ml-kit/text-recognition` (on-device, native add-on) |
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
  features/               # notifications · ocr · prescription · profile
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

### Quick start (Expo Go or web — everything except OCR auto-extraction)

```bash
npx expo start
```

The scan screen still works in this mode: it captures the prescription photo and
attaches it; you then fill in the medications. **Automatic OCR text extraction**
needs the native add-on below.

### Enabling on-device OCR (native build)

OCR uses a native module that **cannot** run in Expo Go or a JS-only export —
it requires a native build. To enable automatic prescription text extraction:

```bash
npm install @react-native-ml-kit/text-recognition
npx expo run:ios       # or: npx expo run:android
```

The app loads the OCR module at runtime and degrades gracefully (falls back to
manual entry) when it isn't present — so the same codebase runs everywhere. See
`src/features/ocr/recognizer.ts`.

### Typecheck

```bash
npm run typecheck
```

### Validate the bundle without a device

```bash
npx expo export --platform ios       # produces a JS bundle; catches import/build errors
npx expo export --platform android
```

## Building for stores (EAS)

```bash
npm i -g eas-cli
eas login
# Add the OCR module first if you want scanning in the build:
#   npm install @react-native-ml-kit/text-recognition
eas build --profile development --platform ios      # dev build w/ OCR
eas build --profile production --platform android    # store build
eas build --profile production --platform ios
```

Profiles are defined in `eas.json`. Update `ios.bundleIdentifier` and
`android.package` in `app.json` before submitting to the stores.

## Data model

`patients` → `prescriptions` → `medications` → `schedule_times` → `dose_logs`,
plus `medical_conditions`, `allergies`, `appointments`, and `settings`. All data
stays on the device (SQLite). See `src/db/schema.ts`.

## Roadmap (not yet built)

- Doctor web portal + cloud sync (currently local-first only)
- OCR field-level mapping (currently a heuristic line parser the user reviews)
- Multi-patient / caregiver profiles (schema already keys by `patient_id`)
```
