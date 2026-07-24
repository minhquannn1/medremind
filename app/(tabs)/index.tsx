import { useCallback, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import {
  Screen,
  Text,
  Card,
  ProgressRing,
  SectionHeader,
  EmptyState,
  Badge,
} from '@/components/ui';
import { DoseCard } from '@/components/DoseCard';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import { getPatient } from '@/db/repositories/patients';
import { getDosesForDay, markDose, getAdherence, type TodayDose } from '@/db/repositories/doses';
import { listActiveMedicationsWithSchedule } from '@/db/repositories/prescriptions';
import { listUpcomingAppointments } from '@/db/repositories/appointments';
import { encouragementOfTheDay } from '@/content/encouragements';
import { syncToDoctor } from '@/features/sync/doctorSync';
import { queueBackup } from '@/features/sync/backup';
import { dayjs, formatDate } from '@/lib/date';

const LOW_STOCK_THRESHOLD = 5;

export default function Home() {
  const { t } = useTranslation();
  const router = useRouter();
  const { activePatientId, language } = useAppStore();

  const [name, setName] = useState('');
  const [doses, setDoses] = useState<TodayDose[]>([]);
  const [adherence, setAdherence] = useState({ taken: 0, total: 0, ratio: 1 });
  const [lowStock, setLowStock] = useState<{ id: number; name: string; remaining: number }[]>([]);
  const [nextAppointment, setNextAppointment] = useState<{ type: string; date: string } | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const loadData = useCallback(async () => {
    if (!activePatientId) return;
    const patient = await getPatient(activePatientId);
    setName(patient?.fullName ?? '');
    setDoses(await getDosesForDay(activePatientId));
    setAdherence(await getAdherence(activePatientId, 7));

    const meds = await listActiveMedicationsWithSchedule(activePatientId);
    setLowStock(
      meds
        .filter(
          (m) =>
            m.medication.quantityRemaining != null &&
            m.medication.quantityRemaining <= LOW_STOCK_THRESHOLD,
        )
        .map((m) => ({
          id: m.medication.id,
          name: m.medication.name,
          remaining: m.medication.quantityRemaining ?? 0,
        })),
    );

    const appts = await listUpcomingAppointments(activePatientId);
    setNextAppointment(appts[0] ? { type: appts[0].type, date: appts[0].date } : null);
  }, [activePatientId]);

  useFocusEffect(
    useCallback(() => {
      loadData();
    }, [loadData]),
  );

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const handleMark = async (doseId: number, status: 'taken' | 'skipped') => {
    await markDose(doseId, status);
    await loadData();
    // Push updated adherence to the doctor if linked (fire-and-forget).
    if (activePatientId) {
      void syncToDoctor(activePatientId);
      queueBackup(activePatientId);
    }
  };

  const greeting = (() => {
    const h = dayjs().hour();
    if (h < 12) return t('home.greetingMorning');
    if (h < 18) return t('home.greetingAfternoon');
    return t('home.greetingEvening');
  })();

  const pending = doses.filter((d) => d.status === 'pending');
  const allDone = doses.length > 0 && pending.length === 0;
  const encouragement = encouragementOfTheDay(language, dayjs().dayOfYear());

  return (
    <Screen refreshing={refreshing} onRefresh={onRefresh}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.flex}>
          <Text variant="caption" color="textMuted">
            {greeting}
          </Text>
          <Text variant="heading" numberOfLines={1}>
            {name || t('common.appName')}
          </Text>
        </View>
        <Ionicons
          name="settings-outline"
          size={24}
          color={colors.textMuted}
          onPress={() => router.push('/settings')}
        />
      </View>

      {/* Adherence + encouragement */}
      <Card style={styles.adherenceCard}>
        <ProgressRing
          progress={adherence.ratio}
          label={`${Math.round(adherence.ratio * 100)}%`}
          caption={t('home.adherenceTitle')}
        />
        <View style={styles.adherenceInfo}>
          <Text variant="bodyStrong">{t('lifestyle.encouragement')}</Text>
          <Text variant="body" color="textMuted" style={styles.encouragement}>
            {encouragement}
          </Text>
          <Text variant="caption" color="textFaint">
            {adherence.taken}/{adherence.total} {t('home.adherenceCaption')}
          </Text>
        </View>
      </Card>

      {/* Alerts */}
      {lowStock.length > 0 && (
        <Card tone="warn" style={styles.alert} onPress={() => router.push('/(tabs)/prescriptions')}>
          <Ionicons name="alert-circle" size={22} color={colors.warn} />
          <View style={styles.flex}>
            <Text variant="bodyStrong" color="warn">
              {t('home.refillAlert')}
            </Text>
            <Text variant="caption" color="textMuted">
              {lowStock.map((m) => m.name).join(', ')}
            </Text>
          </View>
        </Card>
      )}

      {nextAppointment && (
        <Card tone="primary" style={styles.alert} onPress={() => router.push('/(tabs)/schedule')}>
          <Ionicons name="calendar" size={22} color={colors.primary} />
          <View style={styles.flex}>
            <Text variant="bodyStrong" color="primary">
              {t('home.upcomingAppointment')}
            </Text>
            <Text variant="caption" color="textMuted">
              {t(`appointments.${nextAppointment.type}`)} · {formatDate(nextAppointment.date, language)}
            </Text>
          </View>
        </Card>
      )}

      {/* Today doses */}
      <SectionHeader title={t('home.todayDoses')} />
      {doses.length === 0 ? (
        <EmptyState
          icon="add-circle-outline"
          title={t('home.noDosesToday')}
          message={t('home.noDosesTodayBody')}
          actionLabel={t('prescriptions.addManual')}
          onAction={() => router.push('/prescription/new')}
        />
      ) : allDone ? (
        <Card tone="success" style={styles.allDone}>
          <Ionicons name="checkmark-done-circle" size={28} color={colors.success} />
          <Text variant="bodyStrong" color="success" style={styles.flex}>
            {t('home.allDone')}
          </Text>
        </Card>
      ) : null}

      {doses.map((dose) => (
        <DoseCard
          key={dose.id}
          dose={dose}
          onTake={() => handleMark(dose.id, 'taken')}
          onSkip={() => handleMark(dose.id, 'skipped')}
        />
      ))}
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.lg,
  },
  flex: { flex: 1 },
  adherenceCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.lg,
  },
  adherenceInfo: { flex: 1, gap: 4 },
  encouragement: { marginBottom: spacing.xs },
  alert: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginTop: spacing.md,
  },
  allDone: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginBottom: spacing.md,
  },
});
