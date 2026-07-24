import { useEffect, useState } from 'react';
import { View, StyleSheet, Linking, Switch, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Header, Text, Card, SegmentedControl, Divider, Button } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import { getBoolSetting, setSetting, SettingsKeys } from '@/db/repositories/settings';
import { applyReminderPrefs } from '@/features/notifications/scheduler';
import type { AppLanguage } from '@/i18n';

export default function Settings() {
  const { t } = useTranslation();
  const router = useRouter();
  const { language, setLanguage, activePatientId, account, signOut } = useAppStore();

  const onLogout = () => {
    Alert.alert(t('auth.logout'), t('auth.logoutConfirm'), [
      { text: t('common.cancel'), style: 'cancel' },
      {
        text: t('auth.logout'),
        style: 'destructive',
        onPress: async () => {
          await signOut();
          router.replace('/auth');
        },
      },
    ]);
  };
  const [lang, setLang] = useState<AppLanguage>(language);
  const [sound, setSound] = useState(true);
  const [vibration, setVibration] = useState(true);

  useEffect(() => {
    (async () => {
      setSound(await getBoolSetting(SettingsKeys.reminderSound, true));
      setVibration(await getBoolSetting(SettingsKeys.reminderVibration, true));
    })();
  }, []);

  const onChangeLang = async (next: AppLanguage) => {
    setLang(next);
    await setLanguage(next);
  };

  const onToggleSound = async (value: boolean) => {
    setSound(value);
    await setSetting(SettingsKeys.reminderSound, String(value));
    await applyReminderPrefs(activePatientId);
  };

  const onToggleVibration = async (value: boolean) => {
    setVibration(value);
    await setSetting(SettingsKeys.reminderVibration, String(value));
    await applyReminderPrefs(activePatientId);
  };

  return (
    <Screen>
      <Header title={t('settings.title')} />

      <Card style={styles.section}>
        <View style={styles.rowHead}>
          <Ionicons name="language" size={20} color={colors.primary} />
          <Text variant="bodyStrong">{t('settings.language')}</Text>
        </View>
        <SegmentedControl<AppLanguage>
          value={lang}
          onChange={onChangeLang}
          options={[
            { value: 'vi', label: t('settings.languageVi') },
            { value: 'en', label: t('settings.languageEn') },
          ]}
        />
      </Card>

      <Card>
        <View style={styles.rowHead}>
          <Ionicons name="notifications-outline" size={20} color={colors.primary} />
          <Text variant="bodyStrong">{t('settings.notifications')}</Text>
        </View>
        <Text variant="caption" color="textMuted">
          {t('reminders.permissionBody')}
        </Text>
        <Divider />

        <View style={styles.toggleRow}>
          <View style={styles.toggleLabel}>
            <Ionicons name="volume-high-outline" size={18} color={colors.textMuted} />
            <Text variant="body">{t('settings.reminderSound')}</Text>
          </View>
          <Switch
            value={sound}
            onValueChange={onToggleSound}
            trackColor={{ true: colors.primary, false: colors.border }}
          />
        </View>
        <View style={styles.toggleRow}>
          <View style={styles.toggleLabel}>
            <Ionicons name="phone-portrait-outline" size={18} color={colors.textMuted} />
            <Text variant="body">{t('settings.reminderVibration')}</Text>
          </View>
          <Switch
            value={vibration}
            onValueChange={onToggleVibration}
            trackColor={{ true: colors.primary, false: colors.border }}
          />
        </View>

        <Divider />
        <Text
          variant="label"
          color="primary"
          onPress={() => Linking.openSettings()}
        >
          {t('reminders.enable')} →
        </Text>
      </Card>

      <Card style={styles.linkCard} onPress={() => router.push('/doctor')}>
        <Ionicons name="medkit-outline" size={20} color={colors.primary} />
        <Text variant="body" style={styles.flex}>
          {t('doctor.title')}
        </Text>
        <Ionicons name="chevron-forward" size={20} color={colors.textMuted} />
      </Card>

      {/* Account */}
      <Card style={styles.accountCard}>
        <View style={styles.rowHead}>
          <Ionicons name="person-circle-outline" size={20} color={colors.primary} />
          <Text variant="bodyStrong">{t('auth.account')}</Text>
        </View>
        {account && (
          <>
            <Text variant="body">{account.name || t('auth.account')}</Text>
            <Text variant="caption" color="textFaint">
              {account.email}
            </Text>
          </>
        )}
        <Divider />
        <Button label={t('auth.logout')} variant="ghost" icon="log-out-outline" onPress={onLogout} />
      </Card>

      <View style={styles.about}>
        <Text variant="caption" color="textFaint" center>
          {t('common.appName')} · v1.0.0
        </Text>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  section: { marginBottom: spacing.lg },
  rowHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.md },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: spacing.xs,
  },
  toggleLabel: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  linkCard: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginTop: spacing.lg },
  accountCard: { marginTop: spacing.lg, gap: 2 },
  flex: { flex: 1 },
  about: { marginTop: spacing['2xl'] },
});
