import { sqliteTable, integer, text, real } from 'drizzle-orm/sqlite-core';

export const patients = sqliteTable('patients', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  fullName: text('full_name').notNull(),
  dob: text('dob'), // ISO date YYYY-MM-DD
  gender: text('gender'), // male | female | other
  heightCm: real('height_cm'),
  weightKg: real('weight_kg'),
  accountUserId: integer('account_user_id'), // server account id this profile belongs to
  accountEmail: text('account_email'),
  createdAt: text('created_at').notNull(),
});

export const medicalConditions = sqliteTable('medical_conditions', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  patientId: integer('patient_id').notNull(),
  name: text('name').notNull(),
  note: text('note'),
  createdAt: text('created_at').notNull(),
});

export const allergies = sqliteTable('allergies', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  patientId: integer('patient_id').notNull(),
  substance: text('substance').notNull(),
  severity: text('severity'), // mild | moderate | severe
  reaction: text('reaction'),
  createdAt: text('created_at').notNull(),
});

export const prescriptions = sqliteTable('prescriptions', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  patientId: integer('patient_id').notNull(),
  doctorName: text('doctor_name'),
  clinic: text('clinic'),
  issuedDate: text('issued_date'), // ISO date
  notes: text('notes'),
  imageUri: text('image_uri'),
  status: text('status').notNull().default('active'), // active | completed
  createdAt: text('created_at').notNull(),
});

export const medications = sqliteTable('medications', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  prescriptionId: integer('prescription_id').notNull(),
  name: text('name').notNull(),
  form: text('form'), // tablet | capsule | syrup | ...
  dosage: text('dosage'), // free text "1 viên"
  relationToMeal: text('relation_to_meal'), // before | after | with | anytime
  takeWith: text('take_with'),
  durationDays: integer('duration_days'),
  startDate: text('start_date'), // ISO date
  quantityTotal: real('quantity_total'),
  quantityRemaining: real('quantity_remaining'),
  notes: text('notes'),
  explanation: text('explanation'), // AI plain-language "what this medicine is for"
  explanationLang: text('explanation_lang'), // language the explanation was generated in
  imageUri: text('image_uri'), // user photo of the medicine (box/pill), device-local
  createdAt: text('created_at').notNull(),
});

export const scheduleTimes = sqliteTable('schedule_times', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  medicationId: integer('medication_id').notNull(),
  time: text('time').notNull(), // HH:mm (24h)
  doseAmount: real('dose_amount').notNull().default(1),
});

export const doseLogs = sqliteTable('dose_logs', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  medicationId: integer('medication_id').notNull(),
  scheduleTimeId: integer('schedule_time_id'),
  scheduledAt: text('scheduled_at').notNull(), // ISO datetime
  status: text('status').notNull().default('pending'), // pending | taken | skipped | missed
  takenAt: text('taken_at'),
  quantity: real('quantity'),
});

export const appointments = sqliteTable('appointments', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  patientId: integer('patient_id').notNull(),
  type: text('type').notNull(), // revisit | refill
  date: text('date').notNull(), // ISO datetime
  note: text('note'),
  notificationId: text('notification_id'),
  createdAt: text('created_at').notNull(),
});

export const settings = sqliteTable('settings', {
  key: text('key').primaryKey(),
  value: text('value'),
});

export type Patient = typeof patients.$inferSelect;
export type NewPatient = typeof patients.$inferInsert;
export type MedicalCondition = typeof medicalConditions.$inferSelect;
export type Allergy = typeof allergies.$inferSelect;
export type Prescription = typeof prescriptions.$inferSelect;
export type NewPrescription = typeof prescriptions.$inferInsert;
export type Medication = typeof medications.$inferSelect;
export type NewMedication = typeof medications.$inferInsert;
export type ScheduleTime = typeof scheduleTimes.$inferSelect;
export type DoseLog = typeof doseLogs.$inferSelect;
export type Appointment = typeof appointments.$inferSelect;
