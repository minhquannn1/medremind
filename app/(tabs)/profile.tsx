import { useCallback, useState } from 'react';
import { View, StyleSheet, Pressable } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Text, Card, Input, Button, SectionHeader } from '@/components/ui';
import { EditableListSection } from '@/features/profile/EditableListSection';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import {
  getPatient,
  updatePatient,
  listConditions,
  addCondition,
  removeCondition,
  listAllergies,
  addAllergy,
  removeAllergy,
} from '@/db/repositories/patients';
import { getLifestyleTips } from '@/content/lifestyleTips';
import { queueBackup } from '@/features/sync/backup';
import type { Patient, MedicalCondition, Allergy } from '@/db/schema';
import { ageFromDob } from '@/lib/date';

export default function Profile() {
  const { t } = useTranslation();
  const router = useRouter();
  const { activePatientId, language } = useAppStore();

  const [patient, setPatient] = useState<Patient | null>(null);
  const [conditions, setConditions] = useState<MedicalCondition[]>([]);
  const [allergyList, setAllergyList] = useState<Allergy[]>([]);
  const [editingMetrics, setEditingMetrics] = useState(false);
  const [height, setHeight] = useState('');
  const [weight, setWeight] = useState('');

  const load = useCallback(async () => {
    if (!activePatientId) return;
    const p = await getPatient(activePatientId);
    setPatient(p);
    setHeight(p?.heightCm ? String(p.heightCm) : '');
    setWeight(p?.weightKg ? String(p.weightKg) : '');
    setConditions(await listConditions(activePatientId));
    setAllergyList(await listAllergies(activePatientId));
  }, [activePatientId]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  if (!patient || !activePatientId) {
    return (
      <Screen>
        <Text variant="title">{t('profile.title')}</Text>
      </Screen>
    );
  }

  const initials = patient.fullName
    .split(' ')
    .map((w) => w[0])
    .slice(-2)
    .join('')
    .toUpperCase();

  const age = ageFromDob(patient.dob);
  const genderLabel = patient.gender ? t(`profile.genders.${patient.gender}`) : null;
  const bmi =
    patient.heightCm && patient.weightKg
      ? patient.weightKg / Math.pow(patient.heightCm / 100, 2)
      : null;

  const saveMetrics = async () => {
    await updatePatient(activePatientId, {
      heightCm: height ? Number(height) : null,
      weightKg: weight ? Number(weight) : null,
    });
    setEditingMetrics(false);
    queueBackup(activePatientId);
    load();
  };

  const tips = getLifestyleTips(language, {
    age,
    bmi,
    conditions: conditions.map((c) => c.name.toLowerCase()),
    allergies: allergyList.map((a) => a.substance.toLowerCase()),
  });

  return (
    <Screen>
      <View style={styles.titleRow}>
        <Text variant="title">{t('profile.title')}</Text>
        <Pressable onPress={() => router.push('/settings')} hitSlop={8}>
          <Ionicons name="settings-outline" size={24} color={colors.textMuted} />
        </Pressable>
      </View>

      {/* Identity */}
      <Card style={styles.identity}>
        <View style={styles.avatar}>
          <Text variant="heading" color="textInverse">
            {initials}
          </Text>
        </View>
        <View style={styles.flex}>
          <Text variant="subheading">{patient.fullName}</Text>
          <Text variant="body" color="textMuted">
            {[age != null ? `${age} ${t('profile.age').toLowerCase()}` : null, genderLabel]
              .filter(Boolean)
              .join(' · ')}
          </Text>
        </View>
      </Card>

      {/* Body metrics */}
      <SectionHeader
        title={t('profile.anthropometry')}
        actionLabel={editingMetrics ? t('common.save') : t('common.edit')}
        onAction={editingMetrics ? saveMetrics : () => setEditingMetrics(true)}
      />
      {editingMetrics ? (
        <Card>
          <View style={styles.row}>
            <View style={styles.flex}>
              <Input label={t('profile.height')} value={height} onChangeText={setHeight} keyboardType="numeric" suffix="cm" />
            </View>
            <View style={styles.flex}>
              <Input label={t('profile.weight')} value={weight} onChangeText={setWeight} keyboardType="numeric" suffix="kg" />
            </View>
          </View>
        </Card>
      ) : (
        <View style={styles.metrics}>
          <MetricBox label={t('profile.height')} value={patient.heightCm ? `${patient.heightCm}` : '—'} unit="cm" />
          <MetricBox label={t('profile.weight')} value={patient.weightKg ? `${patient.weightKg}` : '—'} unit="kg" />
          <MetricBox label={t('profile.bmi')} value={bmi ? bmi.toFixed(1) : '—'} unit="" />
        </View>
      )}

      {/* Medical history */}
      <SectionHeader title={t('profile.medicalHistory')} />
      <EditableListSection
        items={conditions.map((c) => ({ id: c.id, label: c.name, sub: c.note }))}
        placeholder={t('profile.conditionPlaceholder')}
        addLabel={t('profile.addCondition')}
        icon="pulse"
        onAdd={async (text) => {
          await addCondition(activePatientId, text);
          queueBackup(activePatientId);
          load();
        }}
        onRemove={async (id) => {
          await removeCondition(id);
          queueBackup(activePatientId);
          load();
        }}
      />

      {/* Allergies */}
      <SectionHeader title={t('profile.allergies')} />
      <EditableListSection
        items={allergyList.map((a) => ({ id: a.id, label: a.substance, sub: a.severity ? t(`profile.severities.${a.severity}`) : null }))}
        placeholder={t('profile.allergyPlaceholder')}
        addLabel={t('profile.addAllergy')}
        icon="warning"
        tone="danger"
        onAdd={async (text) => {
          await addAllergy(activePatientId, text);
          queueBackup(activePatientId);
          load();
        }}
        onRemove={async (id) => {
          await removeAllergy(id);
          queueBackup(activePatientId);
          load();
        }}
      />

      {/* Medication & visit history */}
      <SectionHeader title={t('profile.history')} />
      <Card style={styles.historyLink} onPress={() => router.push('/history')}>
        <Ionicons name="time-outline" size={22} color={colors.primary} />
        <Text variant="body" style={styles.flex}>
          {t('history.open')}
        </Text>
        <Ionicons name="chevron-forward" size={20} color={colors.textMuted} />
      </Card>

      {/* Lifestyle tips */}
      <SectionHeader title={t('lifestyle.title')} />
      {tips.map((tip, i) => (
        <Card key={i} style={styles.tip} tone={tip.category === 'nutrition' ? 'success' : 'primary'}>
          <Ionicons
            name={tip.category === 'nutrition' ? 'nutrition' : 'walk'}
            size={20}
            color={tip.category === 'nutrition' ? colors.success : colors.primary}
          />
          <Text variant="body" style={styles.flex}>
            {tip.text}
          </Text>
        </Card>
      ))}
    </Screen>
  );
}

function MetricBox({ label, value, unit }: { label: string; value: string; unit: string }) {
  return (
    <Card style={styles.metricBox}>
      <Text variant="caption" color="textMuted">
        {label}
      </Text>
      <View style={styles.metricValue}>
        <Text variant="heading" color="primary">
          {value}
        </Text>
        {unit ? (
          <Text variant="caption" color="textFaint">
            {unit}
          </Text>
        ) : null}
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  titleRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.lg },
  identity: { flexDirection: 'row', alignItems: 'center', gap: spacing.lg, marginBottom: spacing.sm },
  avatar: {
    width: 60,
    height: 60,
    borderRadius: radius.pill,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  flex: { flex: 1 },
  row: { flexDirection: 'row', gap: spacing.md },
  metrics: { flexDirection: 'row', gap: spacing.md },
  metricBox: { flex: 1, gap: spacing.xs },
  metricValue: { flexDirection: 'row', alignItems: 'baseline', gap: 4 },
  tip: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginBottom: spacing.md },
  historyLink: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
});
