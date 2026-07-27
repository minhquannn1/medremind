# App Review Information — MedRemind 1.0.0

Paste the "Notes" section below into App Store Connect →
App Review Information → Notes.

## Sign-in

| | |
| --- | --- |
| Sign-in required | Yes |
| Email | `review@medremind.app` |
| Password | `AppReview2026!` |

The account is pre-loaded with a demo patient (medications, dose history,
appointments), so the app is populated immediately after sign-in — no setup
needed. Data restores automatically from the account's cloud backup.

## Notes (paste into App Store Connect)

```
MedRemind is a medication reminder and adherence tracker for patients in Vietnam
(bilingual Vietnamese/English). It is a reminder and record-keeping tool — it does
not diagnose, does not prescribe, and does not replace professional medical advice.
A disclaimer to that effect is shown on the prescription-scan review screen and
under every AI-generated medicine explanation.

DEMO ACCOUNT
Email: review@medremind.app
Password: AppReview2026!
The account already contains demo medications and 30 days of dose history, so all
screens are populated right after sign-in.

WHAT TO TEST
1. Home — today's doses, 7-day adherence, low-stock and appointment alerts.
   Tap the check button on a dose to log it; the remaining pill count decreases.
2. Prescriptions tab — "Quét đơn" (Scan) opens the camera to photograph a paper
   prescription. The image is sent to our backend, which calls OpenAI GPT-4o to
   extract the medicines, and the result is shown for review before saving.
   On the Simulator the camera is unavailable — please use "Nhập tay"
   (Manual entry) or pick an image from the photo library instead.
3. Medication detail — plain-language explanation of what each medicine is for,
   editable reminder times, and an optional user-taken photo of the medicine.
4. Schedule / History — per-day dose schedule and a 30-day adherence log.
5. Profile → Settings — language switch (VI/EN), notification settings,
   and Account → Delete account.

ACCOUNT DELETION (guideline 5.1.1(v))
Settings → Tài khoản / Account → "Xóa tài khoản" / "Delete account".
This permanently deletes the account and all server-side data, including the
cloud backup. No email or support request is required.

DOCTOR PAIRING (optional feature)
A patient may enter a pairing code from their doctor so the doctor can view
adherence on a web dashboard. This is entirely optional and off by default; the
app is fully functional without it. It can be unlinked at any time in Settings.

DATA & PRIVACY
Medication data is stored locally on the device (SQLite) and works offline.
When signed in, an encrypted-in-transit backup is stored on our server so users
can restore after changing phones. Prescription photos are sent to OpenAI only
to extract the text and are not retained by our servers. No advertising,
no analytics SDKs, no tracking.

BACKEND
https://medremind-backend-production.up.railway.app (health check: /health)
Support: https://medremind-backend-production.up.railway.app/support
Privacy: https://medremind-backend-production.up.railway.app/privacy
```

## If review asks about the medical claims

The app never states a diagnosis or recommends a treatment. Medicine
explanations describe the common use of a named drug in general terms and always
end with an instruction to follow the prescribing doctor. Dose schedules come
from the user's own prescription, entered or scanned by the user.
