import { useCallback, useState } from 'react';
import { View, StyleSheet, ActivityIndicator } from 'react-native';
import { useLocalSearchParams, useFocusEffect } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Header, Text, Card, Badge, TimeField, Divider, Button } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import {
  getMedication,
  listScheduleTimes,
  updateScheduleTime,
  updateMedicationExplanation,
} from '@/db/repositories/prescriptions';
import { explainMedication } from '@/features/medication/explainMedication';
import { syncReminders } from '@/features/notifications/scheduler';
import { queueBackup } from '@/features/sync/backup';
import type { Medication, ScheduleTime } from '@/db/schema';

export default function MedicationDetail() {
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { activePatientId, language } = useAppStore();
  const medicationId = Number(id);

  const [med, setMed] = useState<Medication | null>(null);
  const [times, setTimes] = useState<ScheduleTime[]>([]);
  const [explaining, setExplaining] = useState(false);
  const [explainError, setExplainError] = useState(false);

  const load = useCallback(async () => {
    setMed(await getMedication(medicationId));
    setTimes(await listScheduleTimes(medicationId));
  }, [medicationId]);

  const fetchExplanation = useCallback(async () => {
    if (!med) return;
    setExplaining(true);
    setExplainError(false);
    const res = await explainMedication(med.name, language, {
      dosage: med.dosage,
      form: med.form,
    });
    if (res.ok && res.explanation) {
      await updateMedicationExplanation(medicationId, res.explanation, language);
      setMed((prev) =>
        prev ? { ...prev, explanation: res.explanation!, explanationLang: language } : prev,
      );
    } else {
      setExplainError(true);
    }
    setExplaining(false);
  }, [med, language, medicationId]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const onChangeTime = async (scheduleId: number, hhmm: string) => {
    await updateScheduleTime(scheduleId, hhmm);
    setTimes((prev) => prev.map((tm) => (tm.id === scheduleId ? { ...tm, time: hhmm } : tm)));
    if (activePatientId) {
      await syncReminders(activePatientId);
      queueBackup(activePatientId);
    }
  };

  if (!med) {
    return (
      <Screen>
        <Header title={t('medication.info')} />
      </Screen>
    );
  }

  const mealLabel =
    med.relationToMeal && med.relationToMeal !== 'anytime'
      ? t(`dose.${med.relationToMeal}Meal`)
      : t('dose.anytime');

  const facts: { icon: keyof typeof Ionicons.glyphMap; label: string; value: string }[] = [
    { icon: 'flask-outline', label: t('medication.form'), value: med.form ? t(`medication.forms.${med.form}`) : '—' },
    { icon: 'eyedrop-outline', label: t('medication.dosage'), value: med.dosage || '—' },
    { icon: 'restaurant-outline', label: t('medication.relationToMeal'), value: mealLabel },
    ...(med.takeWith ? [{ icon: 'water-outline' as const, label: t('medication.takeWith'), value: med.takeWith }] : []),
    ...(med.durationDays ? [{ icon: 'calendar-outline' as const, label: t('medication.duration'), value: `${med.durationDays} ${t('common.units.day')}` }] : []),
  ];

  return (
    <Screen>
      <Header title={med.name} />

      <Card style={styles.hero}>
        <View style={styles.heroIcon}>
          <Ionicons name="medical" size={28} color={colors.primary} />
        </View>
        <Text variant="heading" center>
          {med.name}
        </Text>
        {med.quantityRemaining != null && (
          <Badge
            label={`${t('medication.quantityRemaining')}: ${med.quantityRemaining}${med.quantityTotal != null ? ` / ${med.quantityTotal}` : ''}`}
            tone={med.quantityRemaining <= 5 ? 'danger' : 'success'}
          />
        )}
      </Card>

      {/* Plain-language explanation — "what is this medicine for" */}
      <Text variant="subheading" style={styles.sectionTitle}>
        {t('medication.whatIsItFor')}
      </Text>
      <Card tone="primary" style={styles.explainCard}>
        {med.explanation ? (
          <>
            <View style={styles.explainHeader}>
              <Ionicons name="sparkles" size={16} color={colors.primary} />
              <Text variant="caption" color="primary" style={styles.flex}>
                {t('medication.aiExplanation')}
              </Text>
              <Ionicons
                name="refresh"
                size={16}
                color={colors.textMuted}
                onPress={explaining ? undefined : fetchExplanation}
              />
            </View>
            {explaining ? (
              <ActivityIndicator color={colors.primary} style={styles.explainLoader} />
            ) : (
              <Text variant="body">{med.explanation}</Text>
            )}
            <Text variant="caption" color="textFaint" style={styles.disclaimer}>
              {t('medication.aiDisclaimer')}
            </Text>
          </>
        ) : explaining ? (
          <View style={styles.explainEmpty}>
            <ActivityIndicator color={colors.primary} />
            <Text variant="caption" color="textMuted">
              {t('medication.explaining')}
            </Text>
          </View>
        ) : (
          <View style={styles.explainEmpty}>
            <Text variant="body" color="textMuted" center>
              {explainError ? t('medication.explainError') : t('medication.explainPrompt')}
            </Text>
            <Button
              label={explainError ? t('medication.explainRetry') : t('medication.explainAction')}
              icon="sparkles"
              variant="secondary"
              onPress={fetchExplanation}
            />
          </View>
        )}
      </Card>

      {/* Schedule times — editable */}
      <Text variant="subheading" style={styles.sectionTitle}>
        {t('schedule.reviewTitle')}
      </Text>
      <Text variant="caption" color="textFaint" style={styles.hint}>
        {t('schedule.reviewHint')}
      </Text>
      <Card style={styles.times}>
        {times.map((tm) => (
          <TimeField key={tm.id} value={tm.time} onChange={(hhmm) => onChangeTime(tm.id, hhmm)} />
        ))}
      </Card>

      {/* Facts */}
      <Text variant="subheading" style={styles.sectionTitle}>
        {t('medication.info')}
      </Text>
      <Card>
        {facts.map((f, i) => (
          <View key={f.label}>
            {i > 0 && <Divider spaced={false} />}
            <View style={styles.factRow}>
              <Ionicons name={f.icon} size={18} color={colors.textMuted} />
              <Text variant="body" color="textMuted">
                {f.label}
              </Text>
              <Text variant="bodyStrong" style={styles.factValue}>
                {f.value}
              </Text>
            </View>
          </View>
        ))}
      </Card>

      {med.notes && (
        <Card tone="primary" style={styles.notes}>
          <Text variant="caption" color="primary">
            {t('medication.notes')}
          </Text>
          <Text variant="body">{med.notes}</Text>
        </Card>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: { alignItems: 'center', gap: spacing.md, marginBottom: spacing.lg },
  heroIcon: {
    width: 60,
    height: 60,
    borderRadius: radius.pill,
    backgroundColor: colors.primarySoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sectionTitle: { marginTop: spacing.lg, marginBottom: spacing.xs },
  hint: { marginBottom: spacing.md },
  flex: { flex: 1 },
  explainCard: { gap: spacing.sm },
  explainHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  explainLoader: { alignSelf: 'flex-start', marginVertical: spacing.sm },
  explainEmpty: { alignItems: 'center', gap: spacing.md, paddingVertical: spacing.sm },
  disclaimer: { marginTop: spacing.xs, fontStyle: 'italic' },
  times: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  factRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.md },
  factValue: { flex: 1, textAlign: 'right' },
  notes: { marginTop: spacing.lg, gap: 4 },
});
