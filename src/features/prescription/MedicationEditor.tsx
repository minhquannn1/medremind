import { View, Pressable, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Text, Card, Input, ChipSelect, TimeField } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import type { MedicationDraft, MedicationForm, MealRelation } from './draft';

interface MedicationEditorProps {
  draft: MedicationDraft;
  index: number;
  onChange: (draft: MedicationDraft) => void;
  onRemove: () => void;
  removable: boolean;
}

export function MedicationEditor({
  draft,
  index,
  onChange,
  onRemove,
  removable,
}: MedicationEditorProps) {
  const { t } = useTranslation();
  const set = <K extends keyof MedicationDraft>(key: K, value: MedicationDraft[K]) =>
    onChange({ ...draft, [key]: value });

  const formOptions: { value: MedicationForm; label: string }[] = [
    { value: 'tablet', label: t('medication.forms.tablet') },
    { value: 'capsule', label: t('medication.forms.capsule') },
    { value: 'syrup', label: t('medication.forms.syrup') },
    { value: 'drops', label: t('medication.forms.drops') },
    { value: 'injection', label: t('medication.forms.injection') },
    { value: 'cream', label: t('medication.forms.cream') },
    { value: 'other', label: t('medication.forms.other') },
  ];

  const mealOptions: { value: MealRelation; label: string }[] = [
    { value: 'before', label: t('dose.beforeMeal') },
    { value: 'after', label: t('dose.afterMeal') },
    { value: 'with', label: t('dose.withMeal') },
    { value: 'anytime', label: t('dose.anytime') },
  ];

  const updateTime = (i: number, hhmm: string) => {
    const times = [...draft.times];
    times[i] = hhmm;
    set('times', times);
  };
  const addTime = () => set('times', [...draft.times, '12:00']);
  const removeTime = (i: number) =>
    set('times', draft.times.filter((_, idx) => idx !== i));

  return (
    <Card style={styles.card}>
      <View style={styles.head}>
        <View style={styles.badge}>
          <Text variant="label" color="primary">
            {index + 1}
          </Text>
        </View>
        <Text variant="subheading" style={styles.flex}>
          {draft.name || t('prescriptions.addMedication')}
        </Text>
        {removable && (
          <Pressable onPress={onRemove} hitSlop={8}>
            <Ionicons name="trash-outline" size={20} color={colors.danger} />
          </Pressable>
        )}
      </View>

      <Input
        label={t('medication.name')}
        value={draft.name}
        onChangeText={(v) => set('name', v)}
        placeholder={t('medication.namePlaceholder')}
        icon="medical-outline"
      />

      <ChipSelect<MedicationForm>
        label={t('medication.form')}
        options={formOptions}
        value={draft.form}
        onChange={(v) => set('form', v)}
      />

      <Input
        label={t('medication.dosage')}
        value={draft.dosage}
        onChangeText={(v) => set('dosage', v)}
        placeholder={t('medication.dosagePlaceholder')}
      />

      {/* Schedule times */}
      <Text variant="label" color="textMuted" style={styles.timesLabel}>
        {t('medication.times')}
      </Text>
      <View style={styles.times}>
        {draft.times.map((time, i) => (
          <TimeField
            key={`${draft.key}-time-${i}`}
            value={time}
            onChange={(hhmm) => updateTime(i, hhmm)}
            onRemove={draft.times.length > 1 ? () => removeTime(i) : undefined}
          />
        ))}
        <Pressable style={styles.addTime} onPress={addTime}>
          <Ionicons name="add" size={18} color={colors.primary} />
          <Text variant="label" color="primary">
            {t('medication.addTime')}
          </Text>
        </Pressable>
      </View>

      <ChipSelect<MealRelation>
        label={t('medication.relationToMeal')}
        options={mealOptions}
        value={draft.relationToMeal}
        onChange={(v) => set('relationToMeal', v)}
      />

      <View style={styles.row}>
        <View style={styles.half}>
          <Input
            label={t('medication.duration')}
            value={draft.durationDays}
            onChangeText={(v) => set('durationDays', v)}
            keyboardType="numeric"
            suffix={t('common.units.day')}
            placeholder="7"
            hint={t('medication.durationHint')}
          />
        </View>
        <View style={styles.half}>
          <Input
            label={t('medication.quantity')}
            value={draft.quantityTotal}
            onChangeText={(v) => set('quantityTotal', v)}
            keyboardType="numeric"
            placeholder="20"
          />
        </View>
      </View>

      <Input
        label={t('medication.takeWith')}
        value={draft.takeWith}
        onChangeText={(v) => set('takeWith', v)}
        placeholder={t('medication.takeWithPlaceholder')}
      />

      <Input
        label={t('medication.notes')}
        value={draft.notes}
        onChangeText={(v) => set('notes', v)}
        multiline
      />
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { marginBottom: spacing.lg },
  head: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.lg },
  flex: { flex: 1 },
  badge: {
    width: 28,
    height: 28,
    borderRadius: radius.pill,
    backgroundColor: colors.primarySoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  timesLabel: { marginBottom: spacing.sm },
  times: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.lg },
  addTime: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: colors.primary,
    borderStyle: 'dashed',
  },
  row: { flexDirection: 'row', gap: spacing.md },
  half: { flex: 1 },
});
