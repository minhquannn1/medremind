export type MedicationForm =
  | 'tablet'
  | 'capsule'
  | 'syrup'
  | 'drops'
  | 'injection'
  | 'cream'
  | 'other';

export type MealRelation = 'before' | 'after' | 'with' | 'anytime';

export interface MedicationDraft {
  key: string;
  name: string;
  form: MedicationForm;
  dosage: string;
  relationToMeal: MealRelation;
  takeWith: string;
  durationDays: string;
  quantityTotal: string;
  notes: string;
  times: string[]; // HH:mm
}

let counter = 0;
export function newDraftKey(): string {
  counter += 1;
  return `med-${counter}`;
}

export function emptyMedicationDraft(overrides: Partial<MedicationDraft> = {}): MedicationDraft {
  return {
    key: newDraftKey(),
    name: '',
    form: 'tablet',
    dosage: '',
    relationToMeal: 'anytime',
    takeWith: '',
    durationDays: '',
    quantityTotal: '',
    notes: '',
    times: ['08:00'],
    ...overrides,
  };
}
