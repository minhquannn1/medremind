import crypto from 'crypto';
import express from 'express';
import { db } from './db.js';
import { hashPassword, verifyPassword, signToken, requirePatient } from './auth.js';

export const patientRouter = express.Router();

const nowIso = () => new Date().toISOString();

// Mask an email for logs: "al***@gmail.com" — enough to correlate, not full PII.
const maskEmail = (e) => String(e).replace(/^(.{1,2})[^@]*(@.*)$/, '$1***$2');

// One-way so a deleted account leaves no readable address behind.
const emailHash = (e) =>
  crypto.createHash('sha256').update(String(e).trim().toLowerCase()).digest('hex');

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
  // Registering again with a previously deleted address makes it live again.
  db.prepare('DELETE FROM deleted_accounts WHERE email_hash = ?').run(emailHash(key));
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
    const tombstone = db
      .prepare('SELECT deleted_at FROM deleted_accounts WHERE email_hash = ?')
      .get(emailHash(key));
    if (tombstone) {
      console.log(`[patient login] FAIL — account was deleted (${maskEmail(key)})`);
      return res
        .status(410)
        .json({ ok: false, error: 'account_deleted', deletedAt: tombstone.deleted_at });
    }
    console.log(`[patient login] FAIL — no such account (${maskEmail(key)})`);
    return res.status(401).json({ ok: false, error: 'invalid_credentials' });
  }
  if (!verifyPassword(String(password), account.password_hash)) {
    console.log(`[patient login] FAIL — wrong password (${maskEmail(key)})`);
    return res.status(401).json({ ok: false, error: 'invalid_credentials' });
  }
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

// ---- Full-data backup (upload) / restore (download) -------------------------
// The app uploads a JSON export of its entire local database. Stored as an
// opaque blob keyed by account so a new device can restore everything.

const MAX_BACKUP_BYTES = 4 * 1024 * 1024;

patientRouter.put('/patient/backup', requirePatient, (req, res) => {
  const { data } = req.body || {};
  if (!data || typeof data !== 'object') {
    return res.status(400).json({ ok: false, error: 'missing_data' });
  }
  const json = JSON.stringify(data);
  if (json.length > MAX_BACKUP_BYTES) {
    return res.status(413).json({ ok: false, error: 'backup_too_large' });
  }
  const updatedAt = nowIso();
  db.prepare(
    `INSERT INTO backups (account_id, data, updated_at)
     VALUES (@id, @data, @updated)
     ON CONFLICT(account_id) DO UPDATE SET data = @data, updated_at = @updated`,
  ).run({ id: req.accountId, data: json, updated: updatedAt });
  return res.json({ ok: true, updatedAt });
});

patientRouter.get('/patient/backup', requirePatient, (req, res) => {
  const row = db.prepare('SELECT data, updated_at FROM backups WHERE account_id = ?').get(req.accountId);
  if (!row) return res.json({ ok: true, data: null, updatedAt: null });
  try {
    return res.json({ ok: true, data: JSON.parse(row.data), updatedAt: row.updated_at });
  } catch {
    return res.status(500).json({ ok: false, error: 'corrupt_backup' });
  }
});

// ---- Account deletion --------------------------------------------------------
// App Store Guideline 5.1.1(v): the app must let users delete their account and
// all server-side data. Removes the account row, its cloud backup, and — when
// the app passes the doctor pair code it was linked with — the shared snapshot.

patientRouter.delete('/patient/account', requirePatient, (req, res) => {
  const account = db.prepare('SELECT id, email FROM accounts WHERE id = ?').get(req.accountId);
  if (!account) return res.status(404).json({ ok: false, error: 'not_found' });

  const { pairCode } = req.body || {};
  db.transaction(() => {
    db.prepare('DELETE FROM backups WHERE account_id = ?').run(account.id);
    if (pairCode) {
      const p = db
        .prepare('SELECT id FROM patients WHERE pair_code = ?')
        .get(String(pairCode).trim().toUpperCase());
      if (p) {
        db.prepare('DELETE FROM snapshots WHERE patient_id = ?').run(p.id);
        db.prepare('UPDATE patients SET linked = 0 WHERE id = ?').run(p.id);
      }
    }
    db.prepare('DELETE FROM accounts WHERE id = ?').run(account.id);
    db.prepare(
      `INSERT INTO deleted_accounts (email_hash, deleted_at) VALUES (?, ?)
       ON CONFLICT(email_hash) DO UPDATE SET deleted_at = excluded.deleted_at`,
    ).run(emailHash(account.email), nowIso());
  })();
  console.log(`[patient account] deleted (${maskEmail(account.email)})`);
  return res.json({ ok: true });
});
