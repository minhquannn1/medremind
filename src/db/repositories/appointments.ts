import { and, eq, gte, lte, asc } from 'drizzle-orm';
import { db } from '../client';
import { appointments, type Appointment } from '../schema';
import { nowIso, dayjs } from '@/lib/date';

/** Appointments falling on one calendar day, for the schedule screen. */
export async function listAppointmentsForDay(
  patientId: number,
  day: dayjs.Dayjs,
): Promise<Appointment[]> {
  return db
    .select()
    .from(appointments)
    .where(
      and(
        eq(appointments.patientId, patientId),
        gte(appointments.date, day.startOf('day').toISOString()),
        lte(appointments.date, day.endOf('day').toISOString()),
      ),
    )
    .orderBy(asc(appointments.date));
}

export async function listUpcomingAppointments(patientId: number): Promise<Appointment[]> {
  return db
    .select()
    .from(appointments)
    .where(
      and(eq(appointments.patientId, patientId), gte(appointments.date, dayjs().startOf('day').toISOString())),
    )
    .orderBy(asc(appointments.date));
}

export async function listAllAppointments(patientId: number): Promise<Appointment[]> {
  return db
    .select()
    .from(appointments)
    .where(eq(appointments.patientId, patientId))
    .orderBy(asc(appointments.date));
}

export async function createAppointment(data: {
  patientId: number;
  type: 'revisit' | 'refill';
  date: string;
  note?: string | null;
  notificationId?: string | null;
}): Promise<number> {
  const res = await db
    .insert(appointments)
    .values({ ...data, createdAt: nowIso() })
    .returning({ id: appointments.id });
  return res[0].id;
}

export async function deleteAppointment(id: number): Promise<void> {
  await db.delete(appointments).where(eq(appointments.id, id));
}
