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

// Brute-force protection on credential endpoints: 10 attempts / 15 min / IP.
export const authLimiter = rateLimit({ ...base, windowMs: 15 * MIN, limit: 10 });

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
export const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:'],
      connectSrc: ["'self'"],
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
