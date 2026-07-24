import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

// Never ship a hardcoded default secret — a known value would let anyone forge
// tokens. If JWT_SECRET is unset, use a random per-boot secret (all sessions
// invalidate on restart, but nothing is guessable).
const JWT_SECRET =
  process.env.JWT_SECRET || crypto.randomBytes(48).toString('base64url');
if (!process.env.JWT_SECRET) {
  console.warn(
    '[auth] JWT_SECRET not set — generated a random ephemeral secret. Sessions reset on restart. Set JWT_SECRET in the environment for production.',
  );
}

const TOKEN_TTL = '7d';
const JWT_ALGO = 'HS256';

export function hashPassword(plain) {
  return bcrypt.hashSync(plain, 10);
}

export function verifyPassword(plain, hash) {
  return bcrypt.compareSync(plain, hash);
}

export function signToken(id, role) {
  return jwt.sign({ sub: id, role }, JWT_SECRET, { expiresIn: TOKEN_TTL, algorithm: JWT_ALGO });
}

function verifyRole(req, res, next, role, field) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ ok: false, error: 'unauthorized' });
  try {
    const payload = jwt.verify(token, JWT_SECRET, { algorithms: [JWT_ALGO] });
    if (payload.role !== role) return res.status(403).json({ ok: false, error: 'wrong_role' });
    req[field] = Number(payload.sub);
    next();
  } catch {
    return res.status(401).json({ ok: false, error: 'invalid_token' });
  }
}

/** Express middleware: requires a valid doctor token, sets req.doctorId. */
export function requireDoctor(req, res, next) {
  return verifyRole(req, res, next, 'doctor', 'doctorId');
}

/** Express middleware: requires a valid patient token, sets req.accountId. */
export function requirePatient(req, res, next) {
  return verifyRole(req, res, next, 'patient', 'accountId');
}

/** Human-friendly pairing code, e.g. "MED-4F9K". */
export function generatePairCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O/1/I
  let code = '';
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return `MED-${code.slice(0, 3)}${code.slice(3)}`;
}
