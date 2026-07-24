import express from 'express';
import { db } from './db.js';
import {
  hashPassword,
  verifyPassword,
  signToken,
  requireDoctor,
  generatePairCode,
} from './auth.js';

export const doctorRouter = express.Router();

const nowIso = () => new Date().toISOString();

// ---- Doctor auth ------------------------------------------------------------

doctorRouter.post('/doctor/register', (req, res) => {
  const { email, password, name } = req.body || {};
  if (!email || !password || !name) {
    return res.status(400).json({ ok: false, error: 'missing_fields' });
  }
  if (String(password).length < 8) {
    return res.status(400).json({ ok: false, error: 'weak_password' });
  }
  const existing = db.prepare('SELECT id FROM doctors WHERE email = ?').get(String(email).toLowerCase());
  if (existing) return res.status(409).json({ ok: false, error: 'email_taken' });

  const info = db
    .prepare('INSERT INTO doctors (email, password_hash, name, created_at) VALUES (?, ?, ?, ?)')
    .run(String(email).toLowerCase(), hashPassword(String(password)), String(name), nowIso());
  const token = signToken(info.lastInsertRowid, 'doctor');
  return res.json({ ok: true, token, name });
});

doctorRouter.post('/doctor/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ ok: false, error: 'missing_fields' });
  const key = String(email).toLowerCase();
  const doctor = db.prepare('SELECT * FROM doctors WHERE email = ?').get(key);
  if (!doctor) {
    console.log(`[doctor login] FAIL — no doctor for "${key}"`);
    return res.status(401).json({ ok: false, error: 'invalid_credentials' });
  }
  if (!verifyPassword(String(password), doctor.password_hash)) {
    console.log(`[doctor login] FAIL — wrong password for "${key}"`);
    return res.status(401).json({ ok: false, error: 'invalid_credentials' });
  }
  return res.json({ ok: true, token: signToken(doctor.id, 'doctor'), name: doctor.name });
});

doctorRouter.get('/doctor/me', requireDoctor, (req, res) => {
  const doctor = db.prepare('SELECT id, email, name FROM doctors WHERE id = ?').get(req.doctorId);
  if (!doctor) return res.status(404).json({ ok: false, error: 'not_found' });
  return res.json({ ok: true, doctor });
});

// ---- Patient management (doctor-facing) -------------------------------------

function patientRowToSummary(p) {
  const snap = db.prepare('SELECT * FROM snapshots WHERE patient_id = ?').get(p.id);
  const ratio = snap && snap.adherence_total > 0 ? snap.adherence_taken / snap.adherence_total : null;
  return {
    id: p.id,
    name: p.name,
    pairCode: p.pair_code,
    linked: !!p.linked,
    adherence:
      snap && snap.adherence_total > 0
        ? { taken: snap.adherence_taken, total: snap.adherence_total, ratio }
        : null,
    updatedAt: snap?.updated_at ?? null,
  };
}

doctorRouter.post('/doctor/patients', requireDoctor, (req, res) => {
  const { name } = req.body || {};
  if (!name) return res.status(400).json({ ok: false, error: 'missing_name' });

  // Ensure a unique pair code.
  let code = generatePairCode();
  for (let i = 0; i < 5 && db.prepare('SELECT 1 FROM patients WHERE pair_code = ?').get(code); i++) {
    code = generatePairCode();
  }
  const info = db
    .prepare('INSERT INTO patients (doctor_id, pair_code, name, linked, created_at) VALUES (?, ?, ?, 0, ?)')
    .run(req.doctorId, code, String(name), nowIso());
  return res.json({ ok: true, id: info.lastInsertRowid, pairCode: code, name });
});

doctorRouter.get('/doctor/patients', requireDoctor, (req, res) => {
  const rows = db
    .prepare('SELECT * FROM patients WHERE doctor_id = ? ORDER BY created_at DESC')
    .all(req.doctorId);
  return res.json({ ok: true, patients: rows.map(patientRowToSummary) });
});

doctorRouter.get('/doctor/patients/:id', requireDoctor, (req, res) => {
  const p = db
    .prepare('SELECT * FROM patients WHERE id = ? AND doctor_id = ?')
    .get(Number(req.params.id), req.doctorId);
  if (!p) return res.status(404).json({ ok: false, error: 'not_found' });
  const snap = db.prepare('SELECT * FROM snapshots WHERE patient_id = ?').get(p.id);
  return res.json({
    ok: true,
    patient: patientRowToSummary(p),
    snapshot: snap ? JSON.parse(snap.data) : null,
  });
});

doctorRouter.delete('/doctor/patients/:id', requireDoctor, (req, res) => {
  const p = db
    .prepare('SELECT id FROM patients WHERE id = ? AND doctor_id = ?')
    .get(Number(req.params.id), req.doctorId);
  if (!p) return res.status(404).json({ ok: false, error: 'not_found' });
  db.prepare('DELETE FROM snapshots WHERE patient_id = ?').run(p.id);
  db.prepare('DELETE FROM patients WHERE id = ?').run(p.id);
  return res.json({ ok: true });
});

// ---- Pairing + sync (patient-app-facing, authed by pair code) ---------------

doctorRouter.get('/pair/:code', (req, res) => {
  const p = db.prepare('SELECT * FROM patients WHERE pair_code = ?').get(String(req.params.code).toUpperCase());
  if (!p) return res.status(404).json({ ok: false, error: 'invalid_code' });
  const doctor = db.prepare('SELECT name FROM doctors WHERE id = ?').get(p.doctor_id);
  return res.json({ ok: true, doctorName: doctor?.name ?? '', patientName: p.name });
});

doctorRouter.post('/sync', (req, res) => {
  const { pairCode, snapshot } = req.body || {};
  if (!pairCode || !snapshot) return res.status(400).json({ ok: false, error: 'missing_fields' });
  const p = db.prepare('SELECT * FROM patients WHERE pair_code = ?').get(String(pairCode).toUpperCase());
  if (!p) return res.status(404).json({ ok: false, error: 'invalid_code' });

  const adherence = snapshot.adherence || {};
  const taken = Number.isFinite(adherence.taken) ? adherence.taken : 0;
  const total = Number.isFinite(adherence.total) ? adherence.total : 0;

  db.prepare(
    `INSERT INTO snapshots (patient_id, data, adherence_taken, adherence_total, updated_at)
     VALUES (@pid, @data, @taken, @total, @updated)
     ON CONFLICT(patient_id) DO UPDATE SET
       data = @data, adherence_taken = @taken, adherence_total = @total, updated_at = @updated`,
  ).run({
    pid: p.id,
    data: JSON.stringify(snapshot),
    taken,
    total,
    updated: nowIso(),
  });

  if (!p.linked) db.prepare('UPDATE patients SET linked = 1 WHERE id = ?').run(p.id);
  return res.json({ ok: true });
});
