# MedRemind Scan API

Backend proxy that keeps the OpenAI API key off the device. The app sends a
prescription image; this server calls GPT-4o vision (with function calling for
structured output) and returns medications as JSON.

## Setup

```bash
cd server
npm install
cp .env.example .env      # then paste your OPENAI_API_KEY into .env
npm start
```

Server listens on `http://0.0.0.0:3000`. From a phone on the same Wi-Fi, reach it
at `http://<your-mac-LAN-ip>:3000` (e.g. http://192.168.0.105:3000).

Quick check: open `http://localhost:3000/health` → `{ "ok": true, ... }`.

## Endpoint

`POST /api/scan-prescription`

```json
{ "imageBase64": "<base64 without data: prefix>", "mediaType": "image/jpeg" }
```

Response:

```json
{
  "ok": true,
  "doctorName": "", "clinic": "", "issuedDate": "",
  "rawText": "…full transcription…",
  "medications": [
    { "name": "Paracetamol 500mg", "form": "tablet", "dosage": "1 viên",
      "frequencyPerDay": 3, "times": ["08:00","13:00","20:00"],
      "relationToMeal": "after", "durationDays": 5, "quantityTotal": 15 }
  ]
}
```

## Deploy (production)

Any Node host works (Render, Railway, Fly, a VM). For Vercel, wrap the handler
as a serverless function. Set `OPENAI_API_KEY` as an environment variable in the
host — never commit `.env`. Then point the app's `EXPO_PUBLIC_SCAN_API_URL` at
the deployed URL.
