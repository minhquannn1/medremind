import Database from 'better-sqlite3';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.DOCTOR_DB_PATH || join(__dirname, 'doctor.db');

export const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');

db.exec(`
CREATE TABLE IF NOT EXISTS doctors (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);

-- Patient sign-in accounts (the phone app authenticates against these).
CREATE TABLE IF NOT EXISTS accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS patients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  doctor_id INTEGER NOT NULL,
  pair_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  linked INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS snapshots (
  patient_id INTEGER PRIMARY KEY,
  data TEXT NOT NULL,
  adherence_taken INTEGER NOT NULL DEFAULT 0,
  adherence_total INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);

-- Tombstones for deleted patient accounts, so signing in again can say the
-- account was deleted instead of "wrong password". Only a one-way hash of the
-- address is kept — the email itself is gone with the account.
CREATE TABLE IF NOT EXISTS deleted_accounts (
  email_hash TEXT PRIMARY KEY,
  deleted_at TEXT NOT NULL
);

-- Full app-data backup per patient account (JSON export of the on-device db),
-- used to restore data when the user signs in on a new device.
CREATE TABLE IF NOT EXISTS backups (
  account_id INTEGER PRIMARY KEY,
  data TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_patients_doctor ON patients(doctor_id);
`);
