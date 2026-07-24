# MedRemind — project notes for Claude

Medication adherence app. Expo (React Native, SDK 54) → iOS + Android.
Local-first (SQLite), bilingual (vi/en). See `README.md` for full overview.

## Conventions

- **Path alias:** import from `@/...` (maps to `src/`). Resolved by
  `babel-plugin-module-resolver` in `babel.config.js` and `tsconfig.json` paths.
- **Styling:** never hardcode colors/spacing/type — use tokens from `@/theme`
  (`colors`, `spacing`, `radius`, `fontSize`, `shadow`). Design direction is
  "soft clinical" (teal primary, warm coral accent).
- **UI primitives** live in `src/components/ui` (barrel: `@/components/ui`).
  Prefer composing these over raw RN views.
- **Text:** use the `<Text variant=… color=…>` component, not RN `Text`.
- **i18n:** every user-facing string goes in `src/i18n/locales/{vi,en}.ts`
  (keep both in sync — `en.ts` is typed against `vi`). Use `useTranslation()`.
- **Data access:** only through `src/db/repositories/*`. Never query the db
  client directly from screens. Repositories return typed rows from
  `src/db/schema.ts`.
- **Dates:** use helpers in `@/lib/date` (dayjs), ISO strings in the db.
- **Immutability:** update state with new objects (see drafts in
  `src/features/prescription/draft.ts`).

## After changing prescriptions/medications/times

Call `syncReminders(patientId)` (from `@/features/notifications/scheduler`) so
scheduled local notifications stay in sync. The repositories don't do this
automatically.

## Schema changes

Tables are created via raw DDL in `src/db/init.ts` (no migration runner). If you
add/alter a table, update **both** `src/db/schema.ts` (Drizzle types) **and** the
DDL in `init.ts`.

## Gotchas

- **Prescription scan uses OpenAI GPT-4o vision via a backend proxy** (not
  on-device OCR — ML Kit was removed). Flow: `app/prescription/scan.tsx`
  captures a photo with `base64: true` → `scanPrescriptionImage()` in
  `src/features/scan/aiScanner.ts` POSTs it to the backend → `server/index.js`
  calls GPT-4o vision + function calling → returns structured medications →
  mapped to `MedicationDraft` and pre-filled in `prescription/new`. Plain HTTP
  fetch (no native module), so scan changes only need a JS reload, not a native
  rebuild.
  - Backend URL: `EXPO_PUBLIC_SCAN_API_URL` in `.env` (Metro inlines it at
    bundle time; restart Metro with `--clear` after changing). Falls back to the
    LAN IP default in `aiScanner.ts`.
  - The OpenAI API key lives ONLY in `server/.env` (gitignored). Never put it in
    the app. For production, deploy `server/` and point the env var at it.
  - Model is `OPENAI_MODEL` in `server/.env` (default `gpt-4o`).
  - `aiScanner.ts` is provider-agnostic — it just hits the proxy. Swapping the
    AI provider only touches `server/index.js`.
- **Hermes + private class fields:** `babel.config.js` force-transforms
  `#private` fields (loose) because a transitive dep ships them and this Hermes
  build rejects them. Don't remove those plugins.
- **Tooling:** run bash commands ONE AT A TIME, not in parallel — parallel
  Bash calls in this harness corrupt/cancel each other's output.
- Verify changes with `npm run typecheck` and
  `npx expo export --platform ios` / `--platform android` (catches
  bundling/import errors without a simulator; both must exit 0).
