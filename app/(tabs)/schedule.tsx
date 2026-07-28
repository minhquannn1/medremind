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
import { listAllAppointments, deleteAppointment } from '@/db/repositories/appointments';
import { queueBackup } from '@/features/sync/backup';
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
    // All of them, so the week strip can mark past days too and the selected
    // day can show its own appointments alongside that day's doses.
    setAppointments(await listAllAppointments(activePatientId));
  }, [activePatientId, selected]);

  const dayKey = (iso: string) => dayjs(iso).format('YYYY-MM-DD');
  const appointmentDays = new Set(appointments.map((a) => dayKey(a.date)));
  const selectedAppointments = appointments.filter(
    (a) => dayKey(a.date) === selected.format('YYYY-MM-DD'),
  );
  const upcoming = appointments.filter(
    (a) => !dayjs(a.date).isBefore(dayjs().startOf('day')),
  );

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const handleMark = async (doseId: number, status: 'taken' | 'skipped') => {
    await markDose(doseId, status);
    if (activePatientId) queueBackup(activePatientId);
    load();
  };

  const removeAppointment = async (id: number) => {
    await deleteAppointment(id);
    if (activePatientId) queueBackup(activePatientId);
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
          const hasAppointment = appointmentDays.has(day.format('YYYY-MM-DD'));
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
              <View style={styles.dayMarks}>
                {isToday && <View style={[styles.todayDot, active && styles.todayDotActive]} />}
                {hasAppointment && (
                  <View style={[styles.apptDot, active && styles.apptDotActive]} />
                )}
              </View>
            </Pressable>
          );
        })}
      </ScrollView>

      {/* Appointments falling on the selected day */}
      {selectedAppointments.length > 0 && (
        <View>
          <SectionHeader title={t('appointments.onThisDay')} />
          {selectedAppointments.map((appt) => (
            <AppointmentCard
              key={appt.id}
              appointment={appt}
              language={language}
              withTime
              onRemove={() => removeAppointment(appt.id)}
            />
          ))}
        </View>
      )}

      {/* Doses grouped by part of day */}
      {doses.length === 0 ? (
        selectedAppointments.length === 0 ? (
          <EmptyState icon="time-outline" title={t('schedule.noSchedule')} />
        ) : null
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

      {/* All upcoming appointments, regardless of the selected day */}
      <SectionHeader title={t('appointments.upcoming')} />
      {upcoming.length === 0 ? (
        <Card>
          <Text variant="body" color="textFaint" center>
            {t('appointments.none')}
          </Text>
        </Card>
      ) : (
        upcoming.map((appt) => (
          <AppointmentCard
            key={appt.id}
            appointment={appt}
            language={language}
            onRemove={() => removeAppointment(appt.id)}
          />
        ))
      )}
    </Screen>
  );
}

interface AppointmentCardProps {
  appointment: Appointment;
  language: string;
  /** Show the time of day as well — used when the date is already implied. */
  withTime?: boolean;
  onRemove: () => void;
}

function AppointmentCard({ appointment, language, withTime, onRemove }: AppointmentCardProps) {
  const { t } = useTranslation();
  const isRevisit = appointment.type === 'revisit';
  const when = withTime
    ? dayjs(appointment.date).locale(language).format('HH:mm')
    : formatDate(appointment.date, language);

  return (
    <Card style={styles.appt}>
      <View
        style={[
          styles.apptIcon,
          { backgroundColor: isRevisit ? colors.primarySoft : colors.warnSoft },
        ]}
      >
        <Ionicons
          name={isRevisit ? 'medkit' : 'cart'}
          size={18}
          color={isRevisit ? colors.primary : colors.warn}
        />
      </View>
      <View style={styles.flex}>
        <Text variant="bodyStrong">{t(`appointments.${appointment.type}`)}</Text>
        <Text variant="caption" color="textMuted">
          {when}
          {appointment.note ? ` · ${appointment.note}` : ''}
        </Text>
      </View>
      <Pressable onPress={onRemove} hitSlop={8}>
        <Ionicons name="close-circle-outline" size={22} color={colors.textFaint} />
      </Pressable>
    </Card>
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
  dayMarks: { flexDirection: 'row', gap: 3, height: 5, alignItems: 'center' },
  todayDot: { width: 5, height: 5, borderRadius: 3, backgroundColor: colors.primary },
  todayDotActive: { backgroundColor: colors.textInverse },
  apptDot: { width: 5, height: 5, borderRadius: 3, backgroundColor: colors.warn },
  apptDotActive: { backgroundColor: colors.textInverse },
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
