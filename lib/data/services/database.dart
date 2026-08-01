import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// SQLite client + schema creation.
///
/// Ported from `src/db/client.ts` and `src/db/init.ts`. The DDL is byte-for-byte
/// the same statement list the React Native app runs, so a database created by
/// either app is readable by the other — that matters because cloud backups are
/// restored across both.
///
/// There is no migration runner: tables are created with IF NOT EXISTS and
/// later columns are added by the idempotent ALTER list below.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  /// Overridable for tests (an in-memory database).
  static String databaseName = 'medremind.db';

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final opened = await _open();
    _db = opened;
    return opened;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, databaseName);
    final database = await openDatabase(path, version: 1);
    await _createSchema(database);
    return database;
  }

  /// Opens an in-memory database — used by tests so nothing touches the disk.
  Future<Database> openInMemory() async {
    final database = await openDatabase(inMemoryDatabasePath);
    await _createSchema(database);
    _db = database;
    return database;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static const List<String> _ddl = [
    '''
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
)''',
    '''
CREATE TABLE IF NOT EXISTS medical_conditions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL
)''',
    '''
CREATE TABLE IF NOT EXISTS allergies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id INTEGER NOT NULL,
  substance TEXT NOT NULL,
  severity TEXT,
  reaction TEXT,
  created_at TEXT NOT NULL
)''',
    '''
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
)''',
    '''
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
  image_uri TEXT,
  created_at TEXT NOT NULL
)''',
    '''
CREATE TABLE IF NOT EXISTS schedule_times (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medication_id INTEGER NOT NULL,
  time TEXT NOT NULL,
  dose_amount REAL NOT NULL DEFAULT 1
)''',
    '''
CREATE TABLE IF NOT EXISTS dose_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medication_id INTEGER NOT NULL,
  schedule_time_id INTEGER,
  scheduled_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  taken_at TEXT,
  quantity REAL
)''',
    '''
CREATE TABLE IF NOT EXISTS appointments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  date TEXT NOT NULL,
  note TEXT,
  notification_id TEXT,
  created_at TEXT NOT NULL
)''',
    '''
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT
)''',
    'CREATE INDEX IF NOT EXISTS idx_meds_prescription ON medications(prescription_id)',
    'CREATE INDEX IF NOT EXISTS idx_sched_med ON schedule_times(medication_id)',
    'CREATE INDEX IF NOT EXISTS idx_dose_med ON dose_logs(medication_id)',
    'CREATE INDEX IF NOT EXISTS idx_dose_scheduled ON dose_logs(scheduled_at)',
    'CREATE INDEX IF NOT EXISTS idx_presc_patient ON prescriptions(patient_id)',
  ];

  /// Columns added after the first release. SQLite has no
  /// "ADD COLUMN IF NOT EXISTS", so a duplicate-column error means the column
  /// is already there and is swallowed.
  static const List<String> _migrations = [
    'ALTER TABLE medications ADD COLUMN explanation TEXT',
    'ALTER TABLE medications ADD COLUMN explanation_lang TEXT',
    'ALTER TABLE medications ADD COLUMN image_uri TEXT',
    'ALTER TABLE patients ADD COLUMN account_user_id INTEGER',
    'ALTER TABLE patients ADD COLUMN account_email TEXT',
  ];

  Future<void> _createSchema(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
    for (final statement in _ddl) {
      await database.execute(statement);
    }
    for (final statement in _migrations) {
      try {
        await database.execute(statement);
      } on DatabaseException catch (e) {
        if (!e.toString().toLowerCase().contains('duplicate column')) rethrow;
      }
    }
  }
}
