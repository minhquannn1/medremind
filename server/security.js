import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';

const MIN = 60 * 1000;

const json = (res, code, error) => res.status(code).json({ ok: false, error });
const limitReached = (_req, res) => json(res, 429, 'too_many_requests');

const base = {
  standardHeaders: true,
  legacyHeaders: false,
  handler: limitReached,
};

// Brute-force protection on credential endpoints. Per IP, so it has to
// tolerate many people behind one NAT: App Review runs several devices
// through shared egress IPs and blew through the old limit of 10, which the
// app then surfaced as an error — and a rejection under Guideline 2.1(a).
// Real brute-force protection comes from bcrypt cost, not from this number.
export const authLimiter = rateLimit({ ...base, windowMs: 15 * MIN, limit: 60 });

// Pair-code guessing: 20 lookups / 15 min / IP.
export const pairLimiter = rateLimit({ ...base, windowMs: 15 * MIN, limit: 20 });

// Adherence sync happens after dose actions — allow bursts but bound them.
export const syncLimiter = rateLimit({ ...base, windowMs: 5 * MIN, limit: 60 });

// OpenAI-backed endpoints are expensive — cap to prevent cost-abuse.
export const aiLimiter = rateLimit({ ...base, windowMs: 15 * MIN, limit: 30 });

// Catch-all for the whole API surface.
export const apiLimiter = rateLimit({ ...base, windowMs: 15 * MIN, limit: 300 });

// Security headers. The dashboard is a self-contained page with inline
// script/style, so 'unsafe-inline' is required there; everything else is
// locked down (no external scripts, no framing, no object embeds).
// scriptSrcAttr must be set explicitly: helmet merges these directives with
// its defaults, and its default 'none' blocks every onclick= handler on the
// dashboard, leaving all its buttons dead.
export const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      // 'wasm-unsafe-eval' is for the patient web app served at /: Flutter
      // web runs CanvasKit and SQLite as WebAssembly, all self-hosted.
      scriptSrc: ["'self'", "'unsafe-inline'", "'wasm-unsafe-eval'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'blob:'],
      // fonts.gstatic.com: the Flutter web engine lazy-loads Roboto glyph
      // subsets at runtime; everything else (scripts, wasm) is self-hosted.
      connectSrc: ["'self'", 'https://fonts.gstatic.com'],
      fontSrc: ["'self'", 'data:', 'https://fonts.gstatic.com'],
      workerSrc: ["'self'", 'blob:'],
      objectSrc: ["'none'"],
      frameAncestors: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
});

// CORS: browsers only. The dashboard is same-origin (needs no CORS) and the
// mobile app is not a browser (not subject to CORS). So we allow cross-origin
// only for explicitly configured origins; otherwise deny.
const allowed = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

export const corsMiddleware = cors({
  origin: allowed.length ? allowed : false,
  methods: ['GET', 'POST', 'DELETE'],
  maxAge: 86400,
});
