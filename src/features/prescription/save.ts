import { createPrescription, type MedicationInput } from '@/db/repositories/prescriptions';
import { syncReminders } from '@/features/notifications/scheduler';
import { queueBackup } from '@/features/sync/backup';
import { todayDate } from '@/lib/date';
import i18n from '@/i18n';
import type { MedicationDraft } from './draft';

export interface PrescriptionHeaderDraft {
  doctorName: string;
  clinic: string;
  issuedDate: string | null;
  notes: string;
  imageUri: string | null;
}

function toNumber(value: string): number | null {
  const n = Number(value);
  return value.trim() !== '' && !Number.isNaN(n) ? n : null;
}

export function draftToMedicationInput(draft: MedicationDraft): MedicationInput {
  return {
    name: draft.name.trim(),
    form: draft.form,
    dosage: draft.dosage.trim() || null,
    relationToMeal: draft.relationToMeal,
    takeWith: draft.takeWith.trim() || null,
    durationDays: toNumber(draft.durationDays),
    startDate: todayDate(),
    quantityTotal: toNumber(draft.quantityTotal),
    notes: draft.notes.trim() || null,
    // Uses detected at scan time become the medication's explanation, so the
    // detail screen shows it instantly without another AI call.
    explanation: draft.uses.trim() || null,
    explanationLang: draft.uses.trim() ? i18n.language : null,
    times: draft.times.map((time) => ({ time, doseAmount: 1 })),
  };
}

export async function savePrescription(
  patientId: number,
  header: PrescriptionHeaderDraft,
  drafts: MedicationDraft[],
): Promise<number> {
  const medications = drafts
    .filter((d) => d.name.trim().length > 0)
    .map(draftToMedicationInput);

  const id = await createPrescription({
    patientId,
    doctorName: header.doctorName.trim() || null,
    clinic: header.clinic.trim() || null,
    issuedDate: header.issuedDate,
    notes: header.notes.trim() || null,
    imageUri: header.imageUri,
    medications,
  });

  // Reschedule all reminders to include the new medications
  await syncReminders(patientId);
  queueBackup(patientId);
  return id;
}
