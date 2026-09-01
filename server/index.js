import 'dotenv/config';
import express from 'express';
import OpenAI from 'openai';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { doctorRouter } from './doctor-routes.js';
import { patientRouter } from './patient-routes.js';
import {
  securityHeaders,
  corsMiddleware,
  authLimiter,
  pairLimiter,
  syncLimiter,
  aiLimiter,
  apiLimiter,
} from './security.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

const API_KEY = process.env.OPENAI_API_KEY;
if (!API_KEY) {
  console.error('[FATAL] OPENAI_API_KEY is not set. Copy .env.example to .env and add your key.');
  process.exit(1);
}

const MODEL = process.env.OPENAI_MODEL || 'gpt-4o';
const PORT = Number(process.env.PORT || 3000);

const openai = new OpenAI({ apiKey: API_KEY });

const app = express();
// Behind Railway's proxy — trust exactly one hop so req.ip is the real client
// (needed for correct per-IP rate limiting).
app.set('trust proxy', 1);
app.disable('x-powered-by');
app.use(securityHeaders);
app.use(corsMiddleware);

// Body parsing: the scan endpoint needs room for a base64 image, the backup
// endpoint for a full app-data export, and sync for a detailed snapshot;
// everything else is capped tightly to limit DoS via oversized payloads.
app.use('/api/scan-prescription', express.json({ limit: '25mb' }));
app.use('/api/patient/backup', express.json({ limit: '5mb' }));
app.use('/api/sync', express.json({ limit: '1mb' }));
app.use(express.json({ limit: '128kb' }));

// Rate limiting per surface (registered before the routes they protect).
app.use('/api', apiLimiter);
app.use(['/api/patient/login', '/api/patient/register', '/api/doctor/login', '/api/doctor/register'], authLimiter);
app.use('/api/pair', pairLimiter);
app.use('/api/sync', syncLimiter);
app.use('/api/patient/backup', syncLimiter);
app.use(['/api/scan-prescription', '/api/explain-medication'], aiLimiter);

// Doctor portal API (auth, patients, pairing, sync) + web dashboard.
app.use('/api', doctorRouter);
// Patient app auth (sign-up / sign-in).
app.use('/api', patientRouter);
app.get(['/', '/dashboard'], (_req, res) => {
  res.sendFile(join(__dirname, 'dashboard.html'));
});
// Public legal pages — linked from the app and App Store Connect.
app.get('/privacy', (_req, res) => {
  res.sendFile(join(__dirname, 'privacy.html'));
});
app.get('/support', (_req, res) => {
  res.sendFile(join(__dirname, 'support.html'));
});
app.get('/terms', (_req, res) => {
  res.sendFile(join(__dirname, 'terms.html'));
});
app.get('/about', (_req, res) => {
  res.sendFile(join(__dirname, 'about.html'));
});
// Browsers request this on every page load; without it the console logs a 404.
app.get('/favicon.ico', (_req, res) => {
  res.type('image/png').sendFile(join(__dirname, 'favicon.png'));
});

// ---- Prompt -----------------------------------------------------------------

const SYSTEM_PROMPT = (lang) => `Bạn là trợ lý y tế chuyên đọc ĐƠN THUỐC (tiếng Việt hoặc tiếng Anh) từ ảnh chụp.

Nhiệm vụ:
1. Đọc (transcribe) toàn bộ chữ trong ảnh vào trường rawText, giữ nguyên như thấy.
2. Trích xuất từng loại thuốc thành dữ liệu có cấu trúc qua hàm extract_prescription.

Quy tắc:
- Giữ NGUYÊN tên thuốc kèm hàm lượng như trên đơn (vd "Paracetamol 500mg", "Amlodipin 5mg").
- KHÔNG bịa thuốc. Chỉ trích xuất thứ thật sự đọc được. Nếu không chắc, bỏ qua hoặc ghi vào notes.
- form: chọn 1 trong tablet | capsule | syrup | drops | injection | cream | other (suy đoán hợp lý; mặc định tablet nếu không rõ).
- dosage: liều mỗi lần uống, vd "1 viên", "2 viên", "5 ml".
- frequencyPerDay: số lần uống mỗi ngày (số nguyên) nếu đọc được.
- times: danh sách giờ uống dạng "HH:mm" 24 giờ. Nếu đơn ghi giờ cụ thể, dùng giờ đó. Nếu chỉ ghi số lần/ngày, suy ra giờ hợp lý:
    1 lần -> ["08:00"]
    2 lần -> ["08:00","20:00"]
    3 lần -> ["08:00","13:00","20:00"]
    4 lần -> ["07:00","12:00","17:00","22:00"]
- relationToMeal: before (trước ăn) | after (sau ăn) | with (trong bữa) | anytime. Mặc định anytime nếu không rõ.
- takeWith: lưu ý uống cùng gì (vd "nhiều nước", "sau khi ăn no").
- durationDays: số ngày dùng (số nguyên) nếu có.
- quantityTotal: tổng số lượng đã kê/mua (số) nếu có.
- notes: lưu ý khác cho riêng thuốc đó.
- uses: công dụng chính của thuốc — 1–2 câu NGẮN, dễ hiểu cho bệnh nhân phổ thông, dựa trên kiến thức dược về hoạt chất trong tên thuốc (vd "Giảm đau, hạ sốt." cho Paracetamol). KHÔNG chẩn đoán. Nếu không nhận ra thuốc, để trống — KHÔNG đoán bừa.${
  lang === 'en' ? ' Viết uses bằng TIẾNG ANH.' : ' Viết uses bằng TIẾNG VIỆT.'
}
- doctorName, clinic, issuedDate (YYYY-MM-DD): điền nếu đọc được, để trống nếu không.
- Nếu ảnh không phải đơn thuốc hoặc không đọc được chữ nào: trả medications = [] và rawText mô tả ngắn những gì thấy.

Luôn trả lời bằng cách gọi hàm extract_prescription.`;

// OpenAI function-calling tool (JSON Schema)
const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'extract_prescription',
      description: 'Trả về thông tin đơn thuốc đã đọc được từ ảnh.',
      parameters: {
        type: 'object',
        properties: {
          doctorName: { type: 'string', description: 'Tên bác sĩ, để trống nếu không có' },
          clinic: { type: 'string', description: 'Phòng khám / bệnh viện, để trống nếu không có' },
          issuedDate: { type: 'string', description: 'Ngày kê đơn dạng YYYY-MM-DD, để trống nếu không có' },
          rawText: { type: 'string', description: 'Toàn bộ chữ đọc được trong ảnh, giữ nguyên' },
          medications: {
            type: 'array',
            description: 'Danh sách thuốc đọc được',
            items: {
              type: 'object',
              properties: {
                name: { type: 'string', description: 'Tên thuốc kèm hàm lượng' },
                form: {
                  type: 'string',
                  enum: ['tablet', 'capsule', 'syrup', 'drops', 'injection', 'cream', 'other'],
                },
                dosage: { type: 'string', description: 'Liều mỗi lần, vd "1 viên"' },
                frequencyPerDay: { type: 'integer', description: 'Số lần uống/ngày' },
                times: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'Giờ uống dạng HH:mm 24h',
                },
                relationToMeal: {
                  type: 'string',
                  enum: ['before', 'after', 'with', 'anytime'],
                },
                takeWith: { type: 'string' },
                durationDays: { type: 'integer' },
                quantityTotal: { type: 'number' },
                notes: { type: 'string' },
                uses: {
                  type: 'string',
                  description: 'Công dụng chính của thuốc, 1–2 câu ngắn dễ hiểu; để trống nếu không nhận ra thuốc',
                },
              },
              required: ['name'],
            },
          },
        },
        required: ['medications', 'rawText'],
      },
    },
  },
];

// ---- Helpers ----------------------------------------------------------------

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function callOpenAIWithRetry(params, maxRetries = 3) {
  let attempt = 0;
  // Exponential backoff on rate limit (429) / server errors (5xx)
  // eslint-disable-next-line no-constant-condition
  while (true) {
    try {
      return await openai.chat.completions.create(params);
    } catch (err) {
      const status = err?.status;
      if ((status === 429 || (status >= 500 && status < 600)) && attempt < maxRetries) {
        const wait = 2 ** attempt * 1000;
        console.warn(`[retry] status ${status}, waiting ${wait}ms (attempt ${attempt + 1})`);
        await sleep(wait);
        attempt += 1;
        continue;
      }
      throw err;
    }
  }
}

// ---- Routes -----------------------------------------------------------------

app.get('/health', (_req, res) => {
  res.json({ ok: true, model: MODEL });
});

// ---- Medicine explanation (plain-language "what is this for") ---------------

const EXPLAIN_SYSTEM = {
  vi: `Bạn là dược sĩ thân thiện. Giải thích NGẮN GỌN, DỄ HIỂU cho bệnh nhân phổ thông về một loại thuốc.
Trả lời bằng tiếng Việt, 2–4 câu, không dùng thuật ngữ khó. Bao gồm:
- Thuốc này thường dùng để làm gì (công dụng chính).
- Một lưu ý an toàn quan trọng nếu có (vd uống sau ăn, không tự ý ngưng, tác dụng phụ hay gặp).
KHÔNG chẩn đoán, KHÔNG thay thế lời khuyên bác sĩ. Nếu không chắc tên thuốc, nói rõ là thông tin chung.
Kết thúc bằng: "Luôn dùng theo chỉ định của bác sĩ."`,
  en: `You are a friendly pharmacist. Explain a medicine to a general patient BRIEFLY and SIMPLY.
Answer in English, 2–4 sentences, no jargon. Include:
- What this medicine is commonly used for.
- One important safety note if relevant (e.g. take after food, don't stop abruptly, common side effect).
Do NOT diagnose, do NOT replace a doctor's advice. If unsure about the name, say it is general information.
End with: "Always follow your doctor's instructions."`,
};

app.post('/api/explain-medication', async (req, res) => {
  const { name, dosage, form, lang } = req.body || {};
  if (!name || typeof name !== 'string') {
    return res.status(400).json({ ok: false, error: 'missing_name' });
  }
  const language = lang === 'en' ? 'en' : 'vi';
  const startedAt = Date.now();
  console.log(`[explain] "${name}" (${language})…`);

  const details = [
    `Tên thuốc: ${name}`,
    form ? `Dạng: ${form}` : null,
    dosage ? `Liều: ${dosage}` : null,
  ]
    .filter(Boolean)
    .join('\n');

  try {
    const completion = await callOpenAIWithRetry({
      model: MODEL,
      max_tokens: 400,
      temperature: 0.3,
      messages: [
        { role: 'system', content: EXPLAIN_SYSTEM[language] },
        { role: 'user', content: details },
      ],
    });
    const explanation = completion.choices?.[0]?.message?.content?.trim();
    if (!explanation) {
      return res.status(502).json({ ok: false, error: 'no_output' });
    }
    console.log(`[explain] done in ${((Date.now() - startedAt) / 1000).toFixed(1)}s`);
    return res.json({ ok: true, explanation, lang: language });
  } catch (err) {
    console.error('[explain error]', err?.status, err?.message);
    return res.status(500).json({ ok: false, error: 'server_error' });
  }
});

app.post('/api/scan-prescription', async (req, res) => {
  const { imageBase64, mediaType, lang } = req.body || {};
  if (!imageBase64 || typeof imageBase64 !== 'string') {
    return res.status(400).json({ ok: false, error: 'missing_image' });
  }
  const language = lang === 'en' ? 'en' : 'vi';

  const dataUrl = `data:${mediaType || 'image/jpeg'};base64,${imageBase64}`;
  const imageKb = Math.round((imageBase64.length * 0.75) / 1024);
  const startedAt = Date.now();
  console.log(`[scan] request received — image ~${imageKb} KB, calling ${MODEL}…`);

  try {
    const completion = await callOpenAIWithRetry({
      model: MODEL,
      max_tokens: 2048,
      temperature: 0,
      tools: TOOLS,
      tool_choice: { type: 'function', function: { name: 'extract_prescription' } },
      messages: [
        { role: 'system', content: SYSTEM_PROMPT(language) },
        {
          role: 'user',
          content: [
            { type: 'text', text: 'Đọc đơn thuốc trong ảnh này và trích xuất thông tin.' },
            { type: 'image_url', image_url: { url: dataUrl, detail: 'high' } },
          ],
        },
      ],
    });

    const toolCall = completion.choices?.[0]?.message?.tool_calls?.[0];
    if (!toolCall?.function?.arguments) {
      return res.status(502).json({ ok: false, error: 'no_structured_output' });
    }

    let data;
    try {
      data = JSON.parse(toolCall.function.arguments);
    } catch {
      return res.status(502).json({ ok: false, error: 'bad_json' });
    }

    console.log(
      `[scan] done in ${((Date.now() - startedAt) / 1000).toFixed(1)}s — ${
        Array.isArray(data.medications) ? data.medications.length : 0
      } meds, tokens ${completion.usage?.total_tokens ?? '?'}`,
    );
    return res.json({
      ok: true,
      doctorName: data.doctorName || '',
      clinic: data.clinic || '',
      issuedDate: data.issuedDate || '',
      rawText: data.rawText || '',
      medications: Array.isArray(data.medications) ? data.medications : [],
      usage: completion.usage,
    });
  } catch (err) {
    console.error('[scan error]', err?.status, err?.message);
    return res.status(500).json({ ok: false, error: 'server_error' });
  }
});

// Catch-all error handler — logs full detail server-side, returns a generic
// message so stack traces / internals never reach the client.
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  if (err?.type === 'entity.too.large') {
    return res.status(413).json({ ok: false, error: 'payload_too_large' });
  }
  console.error('[unhandled]', err?.message);
  if (res.headersSent) return;
  return res.status(500).json({ ok: false, error: 'server_error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Medoly scan API listening on http://0.0.0.0:${PORT}`);
  console.log(`Model: ${MODEL}`);
  console.log(`Health: http://localhost:${PORT}/health`);
});
