import { and, eq, gte, lte, inArray } from 'drizzle-orm';
import { db } from '../client';
import { doseLogs, medications, scheduleTimes, prescriptions } from '../schema';
import { dayjs, dateAtTime } from '@/lib/date';
import { adjustMedicationStock } from './prescriptions';

export type DoseStatus = 'pending' | 'taken' | 'skipped' | 'missed';

export interface TodayDose {
  id: number;
  medicationId: number;
  medicationName: string;
  form: string | null;
  dosage: string | null;
  relationToMeal: string | null;
  takeWith: string | null;
  scheduledAt: string;
  time: string; // HH:mm
  status: DoseStatus;
  doseAmount: number;
}

function withinMedicationWindow(
  startDate: string | null,
  durationDays: number | null,
  day: dayjs.Dayjs,
): boolean {
  if (startDate) {
    const start = dayjs(startDate).startOf('day');
    if (day.startOf('day').isBefore(start)) return false;
    if (durationDays && durationDays > 0) {
      const end = start.add(durationDays - 1, 'day').endOf('day');
      if (day.isAfter(end)) return false;
    }
  }
  return true;
}

/** Lazily create pending dose logs for a given day for all active meds. */
export async function ensureDoseLogsForDay(patientId: number, day = dayjs()): Promise<void> {
  const presIds = (
    await db
      .select({ id: prescriptions.id })
      .from(prescriptions)
      .where(and(eq(prescriptions.patientId, patientId), eq(prescriptions.status, 'active')))
  ).map((p) => p.id);
  if (!presIds.length) return;

  const meds = await db
    .select()
    .from(medications)
    .where(inArray(medications.prescriptionId, presIds));
  if (!meds.length) return;

  const medIds = meds.map((m) => m.id);
  const times = await db
    .select()
    .from(scheduleTimes)
    .where(inArray(scheduleTimes.medicationId, medIds));

  const dayStart = day.startOf('day').toISOString();
  const dayEnd = day.endOf('day').toISOString();
  const existing = await db
    .select()
    .from(doseLogs)
    .where(and(gte(doseLogs.scheduledAt, dayStart), lte(doseLogs.scheduledAt, dayEnd)));

  const existingKeys = new Set(
    existing.map((e) => `${e.medicationId}-${e.scheduleTimeId}`),
  );

  for (const t of times) {
    const med = meds.find((m) => m.id === t.medicationId);
    if (!med) continue;
    if (!withinMedicationWindow(med.startDate, med.durationDays, day)) continue;
    const key = `${t.medicationId}-${t.id}`;
    if (existingKeys.has(key)) continue;
    const scheduledAt = dateAtTime(day, t.time).toISOString();
    await db.insert(doseLogs).values({
      medicationId: t.medicationId,
      scheduleTimeId: t.id,
      scheduledAt,
      status: 'pending',
      quantity: t.doseAmount,
    });
  }
}

export async function getDosesForDay(patientId: number, day = dayjs()): Promise<TodayDose[]> {
  await ensureDoseLogsForDay(patientId, day);
  const dayStart = day.startOf('day').toISOString();
  const dayEnd = day.endOf('day').toISOString();

  const rows = await db
    .select({
      id: doseLogs.id,
      medicationId: doseLogs.medicationId,
      scheduledAt: doseLogs.scheduledAt,
      status: doseLogs.status,
      quantity: doseLogs.quantity,
      medicationName: medications.name,
      form: medications.form,
      dosage: medications.dosage,
      relationToMeal: medications.relationToMeal,
      takeWith: medications.takeWith,
    })
    .from(doseLogs)
    .innerJoin(medications, eq(doseLogs.medicationId, medications.id))
    .where(and(gte(doseLogs.scheduledAt, dayStart), lte(doseLogs.scheduledAt, dayEnd)));

  return rows
    .map((r) => ({
      id: r.id,
      medicationId: r.medicationId,
      medicationName: r.medicationName,
      form: r.form,
      dosage: r.dosage,
      relationToMeal: r.relationToMeal,
      takeWith: r.takeWith,
      scheduledAt: r.scheduledAt,
      time: dayjs(r.scheduledAt).format('HH:mm'),
      status: r.status as DoseStatus,
      doseAmount: r.quantity ?? 1,
    }))
    .sort((a, b) => a.scheduledAt.localeCompare(b.scheduledAt));
}

export async function markDose(doseLogId: number, status: DoseStatus): Promise<void> {
  const rows = await db.select().from(doseLogs).where(eq(doseLogs.id, doseLogId)).limit(1);
  const log = rows[0];
  if (!log) return;

  const wasTaken = log.status === 'taken';
  await db
    .update(doseLogs)
    .set({
      status,
      takenAt: status === 'taken' ? dayjs().toISOString() : null,
    })
    .where(eq(doseLogs.id, doseLogId));

  // Adjust stock: deduct when newly taken, restore when un-taking
  const amount = log.quantity ?? 1;
  if (status === 'taken' && !wasTaken) {
    await adjustMedicationStock(log.medicationId, -amount);
  } else if (status !== 'taken' && wasTaken) {
    await adjustMedicationStock(log.medicationId, amount);
  }
}

export interface HistoryDose {
  id: number;
  medicationName: string;
  scheduledAt: string;
  time: string; // HH:mm
  status: DoseStatus;
  takenAt: string | null;
}

export interface HistoryDay {
  date: string; // YYYY-MM-DD
  doses: HistoryDose[];
  taken: number;
  total: number;
}

/**
 * Full dose history for the patient over the past `days`, grouped by day
 * (most recent first). Only includes doses whose scheduled time has passed.
 */
export async function getDoseHistory(patientId: number, days = 30): Promise<HistoryDay[]> {
  const start = dayjs().subtract(days - 1, 'day').startOf('day');
  for (let i = 0; i < days; i++) {
    await ensureDoseLogsForDay(patientId, start.add(i, 'day'));
  }

  const presIds = (
    await db
      .select({ id: prescriptions.id })
      .from(prescriptions)
      .where(eq(prescriptions.patientId, patientId))
  ).map((p) => p.id);
  if (!presIds.length) return [];

  const medIds = (
    await db
      .select({ id: medications.id })
      .from(medications)
      .where(inArray(medications.prescriptionId, presIds))
  ).map((m) => m.id);
  if (!medIds.length) return [];

  const now = dayjs();
  const rows = await db
    .select({
      id: doseLogs.id,
      scheduledAt: doseLogs.scheduledAt,
      status: doseLogs.status,
      takenAt: doseLogs.takenAt,
      medicationName: medications.name,
    })
    .from(doseLogs)
    .innerJoin(medications, eq(doseLogs.medicationId, medications.id))
    .where(
      and(
        inArray(doseLogs.medicationId, medIds),
        gte(doseLogs.scheduledAt, start.toISOString()),
        lte(doseLogs.scheduledAt, now.toISOString()),
      ),
    );

  const byDay = new Map<string, HistoryDose[]>();
  for (const r of rows) {
    const day = dayjs(r.scheduledAt).format('YYYY-MM-DD');
    const dose: HistoryDose = {
      id: r.id,
      medicationName: r.medicationName,
      scheduledAt: r.scheduledAt,
      time: dayjs(r.scheduledAt).format('HH:mm'),
      // A pending dose whose time has passed counts as missed in history.
      status: r.status === 'pending' ? 'missed' : (r.status as DoseStatus),
      takenAt: r.takenAt,
    };
    const list = byDay.get(day) ?? [];
    list.push(dose);
    byDay.set(day, list);
  }

  return Array.from(byDay.entries())
    .map(([date, doses]) => {
      doses.sort((a, b) => b.scheduledAt.localeCompare(a.scheduledAt));
      return {
        date,
        doses,
        taken: doses.filter((d) => d.status === 'taken').length,
        total: doses.length,
      };
    })
    .sort((a, b) => b.date.localeCompare(a.date));
}

export interface AdherenceStat {
  taken: number;
  total: number;
  ratio: number;
}

export async function getAdherence(patientId: number, days = 7): Promise<AdherenceStat> {
  const start = dayjs().subtract(days - 1, 'day').startOf('day');
  // Make sure logs exist for each day in window
  for (let i = 0; i < days; i++) {
    await ensureDoseLogsForDay(patientId, start.add(i, 'day'));
  }
  const startIso = start.toISOString();
  const endIso = dayjs().endOf('day').toISOString();

  const presIds = (
    await db
      .select({ id: prescriptions.id })
      .from(prescriptions)
      .where(eq(prescriptions.patientId, patientId))
  ).map((p) => p.id);
  if (!presIds.length) return { taken: 0, total: 0, ratio: 1 };

  const medIds = (
    await db
      .select({ id: medications.id })
      .from(medications)
      .where(inArray(medications.prescriptionId, presIds))
  ).map((m) => m.id);
  if (!medIds.length) return { taken: 0, total: 0, ratio: 1 };

  const logs = await db
    .select()
    .from(doseLogs)
    .where(
      and(
        inArray(doseLogs.medicationId, medIds),
        gte(doseLogs.scheduledAt, startIso),
        lte(doseLogs.scheduledAt, endIso),
      ),
    );

  // Only count doses already due (scheduled time passed)
  const now = dayjs();
  const due = logs.filter((l) => dayjs(l.scheduledAt).isBefore(now) || dayjs(l.scheduledAt).isSame(now, 'day'));
  const total = due.length;
  const taken = due.filter((l) => l.status === 'taken').length;
  return { taken, total, ratio: total === 0 ? 1 : taken / total };
}
