# MedRemind — Flutter port

A Flutter rewrite of the React Native (Expo) MedRemind app. The original lives
at `~/Documents/Medicine` and is still the version prepared for App Store
submission; nothing here has replaced it.

## Status

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` (unit + widget) | 104 passing |
| `flutter test test_live/` (real backend) | 6 passing |
| `flutter test integration_test/ -d <ios-sim>` | 2 passing |
| `flutter build ios` | succeeds |
| `flutter build apk` | succeeds |

## What was ported

- **Database** — 8 models, the same DDL and idempotent migrations, 6
  repositories (settings, patients, prescriptions, doses, appointments, backup).
- **i18n** — every Vietnamese and English string, with a test asserting the two
  locales stay key-for-key identical and their `{{placeholders}}` match.
- **UI** — design tokens and the primitive set (text, card, button, input,
  screen, header, badge, chips, segmented control, progress ring, date/time
  fields).
- **Network** — patient auth, AI prescription scan, cloud backup, doctor sync,
  medication explanation. Same endpoints and payloads as the RN client.
- **Notifications** — timezone-aware daily dose reminders and appointment
  alerts, with stable per-dose ids so rescheduling replaces instead of
  duplicating.
- **Screens** — all 14: auth, onboarding, home, prescriptions (list / detail /
  new / AI scan), medication detail, schedule, appointment, profile, history,
  doctor pairing, settings.

## Data compatibility

SQLite column names and cloud-backup JSON keys are byte-identical to the RN
app, and `test/backup_test.dart` restores a real RN backup end to end. A user
moving between the two apps keeps their data. The Android `applicationId` and
iOS bundle id also match, so this ships as an update rather than a second app.

## Configuration

The backend URL defaults to the deployed Railway instance. Override at build
time (the equivalent of the RN `EXPO_PUBLIC_SCAN_API_URL`):

```bash
flutter build ios --dart-define=SCAN_API_URL=https://your-host/api/scan-prescription
```

## Before this replaces the RN app

The RN version is the one that has been through App Store preparation. Carry
these over before switching:

1. Run the app on a physical iPhone and confirm dose reminders actually fire —
   the OS queues nothing until notifications are allowed, so this is the one
   behaviour that only a real device can settle.
2. Re-check App Store compliance against the Flutter build: account deletion
   (Settings → Delete account), the privacy and support links, and the medical
   disclaimers on onboarding and the scan review screen.
3. Set a real release signing config in `android/app/build.gradle.kts` — it
   currently signs release with the debug key.
4. Confirm an existing user's cloud backup restores into a fresh install.

Keep `~/Documents/Medicine` until those pass.
