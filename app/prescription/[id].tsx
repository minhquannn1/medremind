import { useCallback, useState } from 'react';
import { View, StyleSheet, Image, Alert } from 'react-native';
import { useLocalSearchParams, useRouter, useFocusEffect } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Header, Text, Card, Badge, Button, Divider } from '@/components/ui';
import { MedicationRow } from '@/components/MedicationRow';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import {
  getPrescription,
  listMedications,
  listScheduleTimes,
  deletePrescription,
  updatePrescriptionStatus,
} from '@/db/repositories/prescriptions';
import { syncReminders } from '@/features/notifications/scheduler';
import { queueBackup } from '@/features/sync/backup';
import type { Prescription, Medication, ScheduleTime } from '@/db/schema';
import { formatDate } from '@/lib/date';

export default function PrescriptionDetail() {
  const { t } = useTranslation();
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { activePatientId, language } = useAppStore();
  const prescriptionId = Number(id);

  const [prescription, setPrescription] = useState<Prescription | null>(null);
  const [meds, setMeds] = useState<{ med: Medication; times: ScheduleTime[] }[]>([]);

  const load = useCallback(async () => {
    const p = await getPrescription(prescriptionId);
    setPrescription(p);
    const list = await listMedications(prescriptionId);
    const withTimes = await Promise.all(
      list.map(async (med) => ({ med, times: await listScheduleTimes(med.id) })),
    );
    setMeds(withTimes);
  }, [prescriptionId]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const onDelete = () => {
    Alert.alert(t('prescriptions.title'), t('common.deleteConfirm'), [
      { text: t('common.cancel'), style: 'cancel' },
      {
        text: t('common.delete'),
        style: 'destructive',
        onPress: async () => {
          await deletePrescription(prescriptionId);
          if (activePatientId) {
            await syncReminders(activePatientId);
            queueBackup(activePatientId);
          }
          router.back();
        },
      },
    ]);
  };

  const toggleStatus = async () => {
    if (!prescription) return;
    const next = prescription.status === 'active' ? 'completed' : 'active';
    await updatePrescriptionStatus(prescriptionId, next);
    if (activePatientId) {
      await syncReminders(activePatientId);
      queueBackup(activePatientId);
    }
    load();
  };

  if (!prescription) {
    return (
      <Screen>
        <Header title={t('prescriptions.title')} />
      </Screen>
    );
  }

  return (
    <Screen>
      <Header
        title={prescription.doctorName || t('prescriptions.title')}
        actionIcon="trash-outline"
        onAction={onDelete}
      />

      <Card style={styles.info}>
        <View style={styles.infoRow}>
          <Ionicons name="person-outline" size={18} color={colors.textMuted} />
          <Text variant="body" color="textMuted">
            {t('prescriptions.doctor')}
          </Text>
          <Text variant="bodyStrong" style={styles.infoValue}>
            {prescription.doctorName || '—'}
          </Text>
        </View>
        <Divider spaced={false} />
        <View style={styles.infoRow}>
          <Ionicons name="business-outline" size={18} color={colors.textMuted} />
          <Text variant="body" color="textMuted">
            {t('prescriptions.clinic')}
          </Text>
          <Text variant="bodyStrong" style={styles.infoValue} numberOfLines={1}>
            {prescription.clinic || '—'}
          </Text>
        </View>
        <Divider spaced={false} />
        <View style={styles.infoRow}>
          <Ionicons name="calendar-outline" size={18} color={colors.textMuted} />
          <Text variant="body" color="textMuted">
            {t('prescriptions.issuedDate')}
          </Text>
          <Text variant="bodyStrong" style={styles.infoValue}>
            {formatDate(prescription.issuedDate ?? prescription.createdAt, language)}
          </Text>
        </View>
        <View style={styles.badgeRow}>
          <Badge
            label={prescription.status === 'active' ? t('prescriptions.active') : t('prescriptions.completed')}
            tone={prescription.status === 'active' ? 'success' : 'neutral'}
          />
        </View>
      </Card>

      {prescription.imageUri && (
        <Image source={{ uri: prescription.imageUri }} style={styles.photo} resizeMode="cover" />
      )}

      {prescription.notes && (
        <Card tone="primary" style={styles.notes}>
          <Text variant="caption" color="primary">
            {t('prescriptions.notes')}
          </Text>
          <Text variant="body">{prescription.notes}</Text>
        </Card>
      )}

      <Text variant="subheading" style={styles.medsTitle}>
        {t('prescriptions.medications')}
      </Text>
      {meds.map(({ med, times }) => (
        <MedicationRow
          key={med.id}
          medication={med}
          times={times}
          onPress={() => router.push(`/medication/${med.id}`)}
        />
      ))}

      <Button
        label={prescription.status === 'active' ? t('prescriptions.completed') : t('prescriptions.active')}
        variant="secondary"
        icon={prescription.status === 'active' ? 'checkmark-done' : 'refresh'}
        onPress={toggleStatus}
        style={styles.statusBtn}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  info: { gap: spacing.md, marginBottom: spacing.lg },
  infoRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  infoValue: { flex: 1, textAlign: 'right' },
  badgeRow: { flexDirection: 'row', marginTop: spacing.xs },
  photo: { width: '100%', height: 180, borderRadius: radius.md, marginBottom: spacing.lg },
  notes: { marginBottom: spacing.lg, gap: 4 },
  medsTitle: { marginBottom: spacing.md },
  statusBtn: { marginTop: spacing.md },
});
