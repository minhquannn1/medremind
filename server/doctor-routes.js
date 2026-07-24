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

// Mask an email for logs: "al***@gmail.com" — enough to correlate, not full PII.
const maskEmail = (e) => String(e).replace(/^(.{1,2})[^@]*(@.*)$/, '$1***$2');

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
    console.log(`[doctor login] FAIL — no such doctor (${maskEmail(key)})`);
    return res.status(401).json({ ok: false, error: 'invalid_credentials' });
  }
  if (!verifyPassword(String(password), doctor.password_hash)) {
    console.log(`[doctor login] FAIL — wrong password (${maskEmail(key)})`);
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

// Normalize a client-supplied snapshot into a strict, safe shape before storing.
// Numeric fields become real numbers (so the dashboard can't be tricked into
// rendering an HTML string where a number is expected — the stored-XSS vector);
// strings are length-capped; unknown fields are dropped.
const num = (v) => {
  const x = Number(v);
  return Number.isFinite(x) ? x : null;
};
const str = (v, max = 500) => (v == null ? null : String(v).slice(0, max));
const adh = (a) =>
  a && typeof a === 'object'
    ? { taken: num(a.taken) ?? 0, total: num(a.total) ?? 0, ratio: num(a.ratio) }
    : null;

function sanitizeSnapshot(snap) {
  if (!snap || typeof snap !== 'object') return {};
  const p = snap.patient && typeof snap.patient === 'object' ? snap.patient : null;
  const patient = p
    ? {
        name: str(p.name, 200),
        age: num(p.age),
        dob: str(p.dob, 40),
        gender: str(p.gender, 20),
        heightCm: num(p.heightCm),
        weightKg: num(p.weightKg),
        conditions: Array.isArray(p.conditions) ? p.conditions.slice(0, 100).map((x) => str(x, 300)) : [],
        allergies: Array.isArray(p.allergies) ? p.allergies.slice(0, 100).map((x) => str(x, 300)) : [],
        conditionsDetail: Array.isArray(p.conditionsDetail)
          ? p.conditionsDetail.slice(0, 100).map((c) => ({ name: str(c?.name, 300), note: str(c?.note, 300) }))
          : [],
        allergiesDetail: Array.isArray(p.allergiesDetail)
          ? p.allergiesDetail.slice(0, 100).map((a) => ({
              substance: str(a?.substance, 300),
              severity: str(a?.severity, 20),
              reaction: str(a?.reaction, 300),
            }))
          : [],
      }
    : null;
  const medications = Array.isArray(snap.medications)
    ? snap.medications.slice(0, 200).map((m) => ({
        name: str(m?.name, 200),
        dosage: str(m?.dosage, 200),
        form: str(m?.form, 30),
        relationToMeal: str(m?.relationToMeal, 30),
        times: Array.isArray(m?.times) ? m.times.slice(0, 50).map((t) => str(t, 10)) : [],
        schedule: Array.isArray(m?.schedule)
          ? m.schedule.slice(0, 50).map((x) => ({ time: str(x?.time, 10), doseAmount: num(x?.doseAmount) }))
          : [],
        quantityRemaining: num(m?.quantityRemaining),
        quantityTotal: num(m?.quantityTotal),
        startDate: str(m?.startDate, 40),
        durationDays: num(m?.durationDays),
        takeWith: str(m?.takeWith, 300),
        notes: str(m?.notes, 500),
      }))
    : [];
  const history = Array.isArray(snap.history)
    ? snap.history.slice(0, 90).map((d) => ({ date: str(d?.date, 40), taken: num(d?.taken) ?? 0, total: num(d?.total) ?? 0 }))
    : [];
  const appointments = Array.isArray(snap.appointments)
    ? snap.appointments.slice(0, 100).map((x) => ({ type: str(x?.type, 20), date: str(x?.date, 40), note: str(x?.note, 300) }))
    : [];
  return {
    patient,
    adherence: adh(snap.adherence),
    adherence30: adh(snap.adherence30),
    medications,
    history,
    appointments,
  };
}

doctorRouter.post('/sync', (req, res) => {
  const { pairCode, snapshot } = req.body || {};
  if (!pairCode || !snapshot) return res.status(400).json({ ok: false, error: 'missing_fields' });
  const p = db.prepare('SELECT * FROM patients WHERE pair_code = ?').get(String(pairCode).toUpperCase());
  if (!p) return res.status(404).json({ ok: false, error: 'invalid_code' });

  const clean = sanitizeSnapshot(snapshot);
  const taken = clean.adherence?.taken ?? 0;
  const total = clean.adherence?.total ?? 0;

  db.prepare(
    `INSERT INTO snapshots (patient_id, data, adherence_taken, adherence_total, updated_at)
     VALUES (@pid, @data, @taken, @total, @updated)
     ON CONFLICT(patient_id) DO UPDATE SET
       data = @data, adherence_taken = @taken, adherence_total = @total, updated_at = @updated`,
  ).run({
    pid: p.id,
    data: JSON.stringify(clean),
    taken,
    total,
    updated: nowIso(),
  });

  if (!p.linked) db.prepare('UPDATE patients SET linked = 1 WHERE id = ?').run(p.id);
  return res.json({ ok: true });
});
