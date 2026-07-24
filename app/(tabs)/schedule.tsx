import { useCallback, useState } from 'react';
import { View, StyleSheet, Pressable, ScrollView } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Text, Card, SectionHeader, Badge, EmptyState } from '@/components/ui';
import { DoseCard } from '@/components/DoseCard';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import { getDosesForDay, markDose, type TodayDose } from '@/db/repositories/doses';
import { listUpcomingAppointments, deleteAppointment } from '@/db/repositories/appointments';
import type { Appointment } from '@/db/schema';
import { dayjs, partOfDay, formatDate } from '@/lib/date';

const PARTS = ['morning', 'noon', 'evening', 'night'] as const;

export default function Schedule() {
  const { t } = useTranslation();
  const router = useRouter();
  const { activePatientId, language } = useAppStore();

  const [selected, setSelected] = useState(dayjs());
  const [doses, setDoses] = useState<TodayDose[]>([]);
  const [appointments, setAppointments] = useState<Appointment[]>([]);

  const week = Array.from({ length: 7 }, (_, i) => dayjs().add(i - 2, 'day'));

  const load = useCallback(async () => {
    if (!activePatientId) return;
    setDoses(await getDosesForDay(activePatientId, selected));
    setAppointments(await listUpcomingAppointments(activePatientId));
  }, [activePatientId, selected]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const handleMark = async (doseId: number, status: 'taken' | 'skipped') => {
    await markDose(doseId, status);
    load();
  };

  const removeAppointment = async (id: number) => {
    await deleteAppointment(id);
    load();
  };

  return (
    <Screen>
      <View style={styles.titleRow}>
        <Text variant="title">{t('schedule.title')}</Text>
        <Pressable
          style={styles.addAppt}
          onPress={() => router.push('/appointment/new')}
          hitSlop={8}
        >
          <Ionicons name="calendar" size={18} color={colors.primary} />
          <Text variant="label" color="primary">
            {t('appointments.add')}
          </Text>
        </Pressable>
      </View>

      {/* Week strip */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.week}
      >
        {week.map((day) => {
          const active = day.isSame(selected, 'day');
          const isToday = day.isSame(dayjs(), 'day');
          return (
            <Pressable
              key={day.format('YYYY-MM-DD')}
              onPress={() => setSelected(day)}
              style={[styles.day, active && styles.dayActive]}
            >
              <Text variant="caption" color={active ? 'textInverse' : 'textFaint'}>
                {day.locale(language).format('dd')}
              </Text>
              <Text variant="bodyStrong" style={{ color: active ? colors.textInverse : colors.text }}>
                {day.format('D')}
              </Text>
              {isToday && <View style={[styles.todayDot, active && styles.todayDotActive]} />}
            </Pressable>
          );
        })}
      </ScrollView>

      {/* Doses grouped by part of day */}
      {doses.length === 0 ? (
        <EmptyState icon="time-outline" title={t('schedule.noSchedule')} />
      ) : (
        PARTS.map((part) => {
          const partDoses = doses.filter((d) => partOfDay(d.time) === part);
          if (partDoses.length === 0) return null;
          return (
            <View key={part}>
              <SectionHeader title={t(`schedule.${part}`)} />
              {partDoses.map((dose) => (
                <DoseCard
                  key={dose.id}
                  dose={dose}
                  onTake={() => handleMark(dose.id, 'taken')}
                  onSkip={() => handleMark(dose.id, 'skipped')}
                />
              ))}
            </View>
          );
        })
      )}

      {/* Appointments */}
      <SectionHeader title={t('appointments.upcoming')} />
      {appointments.length === 0 ? (
        <Card>
          <Text variant="body" color="textFaint" center>
            {t('appointments.none')}
          </Text>
        </Card>
      ) : (
        appointments.map((appt) => (
          <Card key={appt.id} style={styles.appt}>
            <View
              style={[
                styles.apptIcon,
                { backgroundColor: appt.type === 'revisit' ? colors.primarySoft : colors.warnSoft },
              ]}
            >
              <Ionicons
                name={appt.type === 'revisit' ? 'medkit' : 'cart'}
                size={18}
                color={appt.type === 'revisit' ? colors.primary : colors.warn}
              />
            </View>
            <View style={styles.flex}>
              <Text variant="bodyStrong">{t(`appointments.${appt.type}`)}</Text>
              <Text variant="caption" color="textMuted">
                {formatDate(appt.date, language)}
                {appt.note ? ` · ${appt.note}` : ''}
              </Text>
            </View>
            <Pressable onPress={() => removeAppointment(appt.id)} hitSlop={8}>
              <Ionicons name="close-circle-outline" size={22} color={colors.textFaint} />
            </Pressable>
          </Card>
        ))
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  titleRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.lg },
  addAppt: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  week: { gap: spacing.sm, paddingBottom: spacing.lg },
  day: {
    width: 52,
    paddingVertical: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.surface,
    alignItems: 'center',
    gap: 4,
    borderWidth: 1,
    borderColor: colors.border,
  },
  dayActive: { backgroundColor: colors.primary, borderColor: colors.primary },
  todayDot: { width: 5, height: 5, borderRadius: 3, backgroundColor: colors.primary },
  todayDotActive: { backgroundColor: colors.textInverse },
  flex: { flex: 1 },
  appt: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginBottom: spacing.md },
  apptIcon: {
    width: 40,
    height: 40,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
