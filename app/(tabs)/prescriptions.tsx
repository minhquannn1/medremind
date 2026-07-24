import { useCallback, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Text, Card, Button, Badge, EmptyState } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import { listPrescriptions, listMedications } from '@/db/repositories/prescriptions';
import type { Prescription } from '@/db/schema';
import { formatDate } from '@/lib/date';

interface PrescriptionRow extends Prescription {
  medCount: number;
}

export default function Prescriptions() {
  const { t } = useTranslation();
  const router = useRouter();
  const { activePatientId, language } = useAppStore();
  const [rows, setRows] = useState<PrescriptionRow[]>([]);

  const load = useCallback(async () => {
    if (!activePatientId) return;
    const list = await listPrescriptions(activePatientId);
    const withCounts = await Promise.all(
      list.map(async (p) => ({ ...p, medCount: (await listMedications(p.id)).length })),
    );
    setRows(withCounts);
  }, [activePatientId]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  return (
    <Screen>
      <Text variant="title" style={styles.title}>
        {t('prescriptions.title')}
      </Text>

      <View style={styles.actions}>
        <View style={styles.actionFlex}>
          <Button
            label={t('prescriptions.scan')}
            icon="scan"
            onPress={() => router.push('/prescription/scan')}
          />
        </View>
        <View style={styles.actionFlex}>
          <Button
            label={t('prescriptions.addManual')}
            icon="create-outline"
            variant="secondary"
            onPress={() => router.push('/prescription/new')}
          />
        </View>
      </View>

      {rows.length === 0 ? (
        <EmptyState
          icon="document-text-outline"
          title={t('prescriptions.empty')}
          message={t('prescriptions.emptyBody')}
        />
      ) : (
        rows.map((p) => (
          <Card key={p.id} style={styles.card} onPress={() => router.push(`/prescription/${p.id}`)}>
            <View style={styles.cardIcon}>
              <Ionicons name="document-text" size={22} color={colors.primary} />
            </View>
            <View style={styles.cardBody}>
              <Text variant="bodyStrong" numberOfLines={1}>
                {p.doctorName || p.clinic || t('prescriptions.new')}
              </Text>
              <Text variant="caption" color="textMuted">
                {p.issuedDate ? formatDate(p.issuedDate, language) : formatDate(p.createdAt, language)}
                {'  ·  '}
                {t('prescriptions.medicineCount', { count: p.medCount })}
              </Text>
              <View style={styles.badgeRow}>
                <Badge
                  label={p.status === 'active' ? t('prescriptions.active') : t('prescriptions.completed')}
                  tone={p.status === 'active' ? 'success' : 'neutral'}
                />
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textFaint} />
          </Card>
        ))
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  title: { marginBottom: spacing.lg },
  actions: { flexDirection: 'row', gap: spacing.md, marginBottom: spacing.xl },
  actionFlex: { flex: 1 },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginBottom: spacing.md,
  },
  cardIcon: {
    width: 44,
    height: 44,
    borderRadius: radius.md,
    backgroundColor: colors.primarySoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardBody: { flex: 1, gap: 2 },
  badgeRow: { flexDirection: 'row', marginTop: 4 },
});
