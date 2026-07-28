/**
 * Permission helpers.
 *
 * Every permission the app asks for goes through here so a denial is always
 * explained instead of failing silently — tapping a button and having nothing
 * happen is the worst outcome for an app whose whole job is reminding people.
 */
import { Alert, Linking } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import * as Device from 'expo-device';
import i18n from '@/i18n';
import { requestNotificationPermission } from '@/features/notifications/scheduler';

function explain(titleKey: string, bodyKey: string): void {
  Alert.alert(i18n.t(titleKey), i18n.t(bodyKey), [
    { text: i18n.t('common.cancel'), style: 'cancel' },
    { text: i18n.t('permissions.openSettings'), onPress: () => void Linking.openSettings() },
  ]);
}

/** Camera access for taking a prescription or medicine photo. */
export async function ensureCameraPermission(): Promise<boolean> {
  const current = await ImagePicker.getCameraPermissionsAsync();
  if (current.granted) return true;
  if (current.canAskAgain) {
    const asked = await ImagePicker.requestCameraPermissionsAsync();
    if (asked.granted) return true;
  }
  explain('permissions.cameraTitle', 'permissions.cameraBody');
  return false;
}

/** Photo library access for picking an existing prescription photo. */
export async function ensureMediaLibraryPermission(): Promise<boolean> {
  const current = await ImagePicker.getMediaLibraryPermissionsAsync();
  if (current.granted) return true;
  if (current.canAskAgain) {
    const asked = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (asked.granted) return true;
  }
  explain('permissions.photosTitle', 'permissions.photosBody');
  return false;
}

/**
 * Notification permission. Returns false when reminders cannot be delivered;
 * the caller still saves the data, we only warn that alerts will not fire.
 */
export async function ensureNotificationPermission(): Promise<boolean> {
  const granted = await requestNotificationPermission();
  // Simulators cannot receive notifications at all — don't nag during testing.
  if (!granted && Device.isDevice) {
    explain('permissions.notificationsTitle', 'permissions.notificationsBody');
  }
  return granted;
}
