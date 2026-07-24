import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import { Platform } from 'react-native';
import i18n from '@/i18n';
import { listActiveMedicationsWithSchedule } from '@/db/repositories/prescriptions';
import { getBoolSetting, SettingsKeys } from '@/db/repositories/settings';
import { dayjs } from '@/lib/date';

const ANDROID_CHANNEL_ID = 'medication-reminders';

export interface ReminderPrefs {
  sound: boolean;
  vibration: boolean;
}

export async function getReminderPrefs(): Promise<ReminderPrefs> {
  return {
    sound: await getBoolSetting(SettingsKeys.reminderSound, true),
    vibration: await getBoolSetting(SettingsKeys.reminderVibration, true),
  };
}

// Foreground display behaviour
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

export async function configureNotifications(): Promise<void> {
  if (Platform.OS === 'android') {
    const prefs = await getReminderPrefs();
    await Notifications.setNotificationChannelAsync(ANDROID_CHANNEL_ID, {
      name: i18n.t('reminders.channelName'),
      importance: Notifications.AndroidImportance.HIGH,
      sound: prefs.sound ? 'default' : undefined,
      // Android channel vibration is immutable once created; an empty pattern
      // disables it. Recreated via applyReminderPrefs() when the user toggles.
      vibrationPattern: prefs.vibration ? [0, 250, 250, 250] : [0],
      enableVibrate: prefs.vibration,
      lightColor: '#0E7C7B',
      lockscreenVisibility: Notifications.AndroidNotificationVisibility.PUBLIC,
    });
  }
}

/**
 * Re-applies reminder preferences: recreates the Android channel (channels are
 * immutable, so we delete + recreate) and reschedules all reminders so the new
 * sound setting takes effect on already-queued notifications.
 */
export async function applyReminderPrefs(patientId: number | null): Promise<void> {
  if (Platform.OS === 'android') {
    await Notifications.deleteNotificationChannelAsync(ANDROID_CHANNEL_ID).catch(() => {});
    await configureNotifications();
  }
  if (patientId != null) await syncReminders(patientId);
}

export async function requestNotificationPermission(): Promise<boolean> {
  if (!Device.isDevice) return false;
  const settings = await Notifications.getPermissionsAsync();
  let granted = settings.granted || settings.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL;
  if (!granted) {
    const req = await Notifications.requestPermissionsAsync({
      ios: { allowAlert: true, allowBadge: true, allowSound: true },
    });
    granted = req.granted;
  }
  return granted;
}

export async function hasNotificationPermission(): Promise<boolean> {
  const settings = await Notifications.getPermissionsAsync();
  return settings.granted;
}

interface ScheduleArgs {
  medicationId: number;
  medicationName: string;
  dosage: string | null;
  hour: number;
  minute: number;
  sound: boolean;
}

async function scheduleDailyDose({
  medicationId,
  medicationName,
  dosage,
  hour,
  minute,
  sound,
}: ScheduleArgs): Promise<void> {
  await Notifications.scheduleNotificationAsync({
    content: {
      title: i18n.t('reminders.doseTitle'),
      body: i18n.t('reminders.doseBody', {
        medication: medicationName,
        dosage: dosage ?? '',
      }),
      sound: sound ? 'default' : undefined,
      data: { type: 'dose', medicationId },
      ...(Platform.OS === 'android' ? { channelId: ANDROID_CHANNEL_ID } : {}),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DAILY,
      hour,
      minute,
    },
  });
}

/**
 * Cancel all scheduled notifications and reschedule daily reminders for every
 * active medication / schedule time. Call after any prescription change.
 */
export async function syncReminders(patientId: number): Promise<void> {
  const granted = await hasNotificationPermission();
  if (!granted) return;

  await Notifications.cancelAllScheduledNotificationsAsync();

  const prefs = await getReminderPrefs();
  const meds = await listActiveMedicationsWithSchedule(patientId);
  for (const { medication, times } of meds) {
    // Skip medications that have ended
    if (medication.startDate && medication.durationDays) {
      const end = dayjs(medication.startDate).add(medication.durationDays - 1, 'day').endOf('day');
      if (dayjs().isAfter(end)) continue;
    }
    for (const t of times) {
      const [hour, minute] = t.time.split(':').map(Number);
      await scheduleDailyDose({
        medicationId: medication.id,
        medicationName: medication.name,
        dosage: medication.dosage,
        hour,
        minute,
        sound: prefs.sound,
      });
    }
  }
}

export async function scheduleAppointmentReminder(
  title: string,
  body: string,
  when: Date,
): Promise<string | null> {
  if (dayjs(when).isBefore(dayjs())) return null;
  return Notifications.scheduleNotificationAsync({
    content: {
      title,
      body,
      sound: 'default',
      ...(Platform.OS === 'android' ? { channelId: ANDROID_CHANNEL_ID } : {}),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DATE,
      date: when,
    },
  });
}

export async function cancelNotification(id: string): Promise<void> {
  await Notifications.cancelScheduledNotificationAsync(id);
}
