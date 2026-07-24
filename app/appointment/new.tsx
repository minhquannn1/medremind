import { useState } from 'react';
import { StyleSheet, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';

import { Screen, Header, Card, Input, Button, SegmentedControl, DateField } from '@/components/ui';
import { spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import { createAppointment } from '@/db/repositories/appointments';
import { scheduleAppointmentReminder, requestNotificationPermission } from '@/features/notifications/scheduler';
import { dayjs } from '@/lib/date';
import i18n from '@/i18n';

type ApptType = 'revisit' | 'refill';

export default function NewAppointment() {
  const { t } = useTranslation();
  const router = useRouter();
  const { activePatientId, language } = useAppStore();

  const [type, setType] = useState<ApptType>('revisit');
  const [date, setDate] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [saving, setSaving] = useState(false);

  const onSave = async () => {
    if (!activePatientId || !date) {
      Alert.alert(t('appointments.title'), t('appointments.date') + ' ' + t('common.required'));
      return;
    }
    setSaving(true);
    try {
      await requestNotificationPermission();
      const when = dayjs(date);
      const notificationId = await scheduleAppointmentReminder(
        i18n.t('reminders.appointmentTitle'),
        `${t(`appointments.${type}`)} · ${when.locale(language).format('DD/MM/YYYY HH:mm')}`,
        when.toDate(),
      );
      await createAppointment({
        patientId: activePatientId,
        type,
        date: when.toISOString(),
        note: note.trim() || null,
        notificationId,
      });
      router.back();
    } catch (e) {
      Alert.alert('Error', String(e));
      setSaving(false);
    }
  };

  return (
    <Screen>
      <Header title={t('appointments.add')} />
      <Card>
        <SegmentedControl<ApptType>
          label={t('appointments.title')}
          value={type}
          onChange={setType}
          options={[
            { value: 'revisit', label: t('appointments.revisit') },
            { value: 'refill', label: t('appointments.refill') },
          ]}
        />
        <DateField
          label={t('appointments.date')}
          value={date}
          onChange={setDate}
          mode="datetime"
          minimumDate={new Date()}
          locale={language}
          placeholder="DD/MM/YYYY HH:mm"
        />
        <Input label={t('prescriptions.notes')} value={note} onChangeText={setNote} multiline />
      </Card>
      <Button
        label={t('common.save')}
        icon="checkmark"
        size="lg"
        loading={saving}
        onPress={onSave}
        style={styles.save}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  save: { marginTop: spacing.lg },
});
