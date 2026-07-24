import express from 'express';
import { db } from './db.js';
import { hashPassword, verifyPassword, signToken, requirePatient } from './auth.js';

export const patientRouter = express.Router();

const nowIso = () => new Date().toISOString();

patientRouter.post('/patient/register', (req, res) => {
  const { email, password, name } = req.body || {};
  if (!email || !password || !name) {
    return res.status(400).json({ ok: false, error: 'missing_fields' });
  }
  if (String(password).length < 8) {
    return res.status(400).json({ ok: false, error: 'weak_password' });
  }
  const key = String(email).trim().toLowerCase();
  const existing = db.prepare('SELECT id FROM accounts WHERE email = ?').get(key);
  if (existing) return res.status(409).json({ ok: false, error: 'email_taken' });

  const info = db
    .prepare('INSERT INTO accounts (email, password_hash, name, created_at) VALUES (?, ?, ?, ?)')
    .run(key, hashPassword(String(password)), String(name), nowIso());
  return res.json({
    ok: true,
    token: signToken(info.lastInsertRowid, 'patient'),
    userId: info.lastInsertRowid,
    name,
  });
});

patientRouter.post('/patient/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ ok: false, error: 'missing_fields' });
  const key = String(email).trim().toLowerCase();
  const account = db.prepare('SELECT * FROM accounts WHERE email = ?').get(key);
  if (!account) {
    console.log(`[patient login] FAIL — no account for "${key}"`);
    return res.status(401).json({ ok: false, error: 'invalid_credentials' });
  }
  if (!verifyPassword(String(password), account.password_hash)) {
    console.log(`[patient login] FAIL — wrong password for "${key}"`);
    return res.status(401).json({ ok: false, error: 'invalid_credentials' });
  }
  console.log(`[patient login] OK — "${key}"`);
  return res.json({
    ok: true,
    token: signToken(account.id, 'patient'),
    userId: account.id,
    name: account.name,
  });
});

patientRouter.get('/patient/me', requirePatient, (req, res) => {
  const account = db.prepare('SELECT id, email, name FROM accounts WHERE id = ?').get(req.accountId);
  if (!account) return res.status(404).json({ ok: false, error: 'not_found' });
  return res.json({ ok: true, account });
});
