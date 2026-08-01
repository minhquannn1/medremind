# MedRemind — project notes for Claude

Medication adherence app. **Flutter** (iOS + Android) plus a Node/Express
backend. Local-first (SQLite), bilingual (vi/en). See `README.md` for the app
overview.

This repo holds two independent things:

| Path | What it is |
|---|---|
| `lib/`, `test/`, `ios/`, `android/`, `pubspec.yaml` | the Flutter app |
| `server/`, `Dockerfile`, `railway.json` | the backend Railway deploys |

## Backend — do not break it

Railway builds **only** `server/`, via the root `Dockerfile`, and serves the
doctor dashboard, the AI scan proxy, patient auth, cloud backup and the
`/privacy` + `/support` pages that App Store Connect points at.

- Never delete or move `server/`, `Dockerfile` or `railway.json`.
- The SQLite file is on a Railway volume at `/data/doctor.db`
  (`DOCTOR_DB_PATH`). It is gitignored; the filesystem is otherwise ephemeral,
  so anything written outside the volume is lost on deploy.
- `OPENAI_API_KEY` lives only in Railway's env vars, never in the app.
- Deploys are health-gated on `/health`, so a broken build cannot replace a
  working one.
- The dashboard is a single self-contained HTML file with inline `onclick`
  handlers; the CSP in `server/security.js` must keep
  `scriptSrcAttr: ["'unsafe-inline'"]` or every button silently stops working.

## Architecture

Flutter's recommended layering (see the `flutter-apply-architecture-best-practices`
skill in `.agents/skills/`):

```
lib/data/services/       database, auth, scan, backup, doctor sync, notifications
lib/data/repositories/   the six repositories — the only place SQL lives
lib/domain/models/       row models and the medication draft
lib/ui/core/             components, theme, i18n, app state, tab shell
lib/ui/features/<x>/
  ├── view_models/       ChangeNotifier holding the screen's state and rules
  └── views/             widgets that lay out and forward taps, nothing more
```

Every screen with logic has a ViewModel. Put a rule in the ViewModel, not the
widget: anything in a `build()` method can only be tested by pumping a widget
tree, which is why the rules that used to live there had no tests and shipped
bugs — BMI dividing by a zero height, evening rendering above morning, a
reminder deducting stock twice.

ViewModels take their dependencies through the constructor (repositories,
callbacks, and the clock where behaviour depends on the time), so tests choose
the situation instead of waiting for it. Views hold only `TextEditingController`s
and `ListenableBuilder`.

Riverpod stays for session state (`ui/core/app_state.dart`) and for handing
services to screens. It is not used inside ViewModels.

Cross-layer imports are `package:medremind/...`, never relative.

## Flutter app conventions

- **Theme:** never hardcode colours or spacing — use `lib/theme/tokens.dart`
  (`AppColors`, `Spacing`, `Radii`, `FontSizes`). Direction is "soft clinical"
  (teal primary, warm coral accent).
- **Widgets:** compose the primitives in `lib/components/` (`AppText`,
  `AppCard`, `AppButton`, `AppInput`, `AppScreen`, …) rather than raw Material
  widgets, so screens stay visually consistent.
- **i18n:** every user-facing string goes in `lib/i18n/locale_vi.dart` **and**
  `locale_en.dart`. A test asserts the two stay key-for-key identical and that
  their `{{placeholders}}` match — add to both or it fails.
- **Data access:** only through `lib/db/repositories/*`. Screens never touch
  the database directly.
- **State:** Riverpod. Session and language live in `lib/store/app_state.dart`.

## After changing prescriptions, medications or times

Call `NotificationScheduler.syncReminders(patientId, t)`. Repositories do not
do it automatically, and `syncReminders` returns **false** when notifications
are not permitted — tell the user rather than leaving them with medications and
no alerts.

## Schema changes

There is no migration runner. Tables are created by the DDL in
`lib/db/database.dart`; new columns go in the idempotent `_migrations` list
there. Column names are byte-identical to the old React Native app so cloud
backups restore across both — changing one breaks existing users' backups.

## Agent skills

`.agents/skills/` holds the official Flutter and Dart agent skills
(github.com/flutter/skills, github.com/dart-lang/skills) — task recipes for
things like adding a widget test, setting up localization, collecting
coverage or migrating to pattern matching. `.claude/skills` is a symlink to
that directory so Claude Code finds them without a second copy.

Refresh them with:

```bash
npx skills add flutter/skills --skill '*' --agent universal
npx skills add dart-lang/skills --skill '*' --agent universal
```

They are instructions only — plain markdown, no scripts — but they run with
full agent permissions, so read a skill before relying on it.

## Verifying

```bash
flutter analyze                  # must be 0 issues
flutter test                     # unit + widget
flutter test test_live/          # hits the real backend
flutter build ios --simulator    # catches native/plugin breakage
flutter build apk --debug
```

## Gotchas

- `flutter_local_notifications` needs core library desugaring on Android; it is
  enabled in `android/app/build.gradle.kts` and removing it fails the build.
- Android release currently signs with the **debug** key — set a real signing
  config before shipping to Play.
- Reminders are scheduled in the device timezone (wall-clock), so an 08:00 dose
  stays 08:00 across travel and DST.
- Whether reminders actually fire can only be confirmed on a physical device:
  the OS queues nothing until notifications are allowed, and that prompt cannot
  be scripted.
- The backend URL defaults to the Railway instance; override with
  `--dart-define=SCAN_API_URL=…`.
