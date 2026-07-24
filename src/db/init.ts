import { rawDb } from './client';

const DDL = `
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS patients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name TEXT NOT NULL,
  dob TEXT,
  gender TEXT,
  height_cm REAL,
  weight_kg REAL,
  account_user_id INTEGER,
  account_email TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS medical_conditions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS allergies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id INTEGER NOT NULL,
  substance TEXT NOT NULL,
  severity TEXT,
  reaction TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS prescriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id INTEGER NOT NULL,
  doctor_name TEXT,
  clinic TEXT,
  issued_date TEXT,
  notes TEXT,
  image_uri TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS medications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  prescription_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  form TEXT,
  dosage TEXT,
  relation_to_meal TEXT,
  take_with TEXT,
  duration_days INTEGER,
  start_date TEXT,
  quantity_total REAL,
  quantity_remaining REAL,
  notes TEXT,
  explanation TEXT,
  explanation_lang TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS schedule_times (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medication_id INTEGER NOT NULL,
  time TEXT NOT NULL,
  dose_amount REAL NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS dose_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medication_id INTEGER NOT NULL,
  schedule_time_id INTEGER,
  scheduled_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  taken_at TEXT,
  quantity REAL
);

CREATE TABLE IF NOT EXISTS appointments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  date TEXT NOT NULL,
  note TEXT,
  notification_id TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE INDEX IF NOT EXISTS idx_meds_prescription ON medications(prescription_id);
CREATE INDEX IF NOT EXISTS idx_sched_med ON schedule_times(medication_id);
CREATE INDEX IF NOT EXISTS idx_dose_med ON dose_logs(medication_id);
CREATE INDEX IF NOT EXISTS idx_dose_scheduled ON dose_logs(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_presc_patient ON prescriptions(patient_id);
`;

// Idempotent column additions for databases created before these columns
// existed. SQLite has no "ADD COLUMN IF NOT EXISTS", so we swallow the
// duplicate-column error.
const MIGRATIONS = [
  `ALTER TABLE medications ADD COLUMN explanation TEXT`,
  `ALTER TABLE medications ADD COLUMN explanation_lang TEXT`,
  `ALTER TABLE patients ADD COLUMN account_user_id INTEGER`,
  `ALTER TABLE patients ADD COLUMN account_email TEXT`,
];

let initialized = false;

export async function initDatabase(): Promise<void> {
  if (initialized) return;
  await rawDb.execAsync(DDL);
  for (const sql of MIGRATIONS) {
    try {
      await rawDb.execAsync(sql);
    } catch (err) {
      // Ignore "duplicate column name" — the column already exists.
      if (!String(err).toLowerCase().includes('duplicate column')) throw err;
    }
  }
  initialized = true;
}
