import { useCallback, useState } from 'react';
import { View, StyleSheet, Alert } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Header, Text, Card, Input, Button } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import {
  getDoctorLink,
  pairWithDoctor,
  unlinkDoctor,
  syncToDoctor,
  type DoctorLink,
} from '@/features/sync/doctorSync';

export default function DoctorConnect() {
  const { t } = useTranslation();
  const { activePatientId } = useAppStore();

  const [link, setLink] = useState<DoctorLink | null>(null);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLink(await getDoctorLink());
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const onConnect = async () => {
    if (!code.trim()) return;
    setBusy(true);
    setError('');
    const res = await pairWithDoctor(code);
    if (res.ok) {
      setCode('');
      await load();
      if (activePatientId) await syncToDoctor(activePatientId);
    } else {
      setError(res.error === 'invalid_code' ? t('doctor.invalidCode') : t('doctor.networkError'));
    }
    setBusy(false);
  };

  const onDisconnect = () => {
    Alert.alert(t('doctor.disconnect'), t('doctor.disconnectConfirm'), [
      { text: t('common.cancel'), style: 'cancel' },
      {
        text: t('doctor.disconnect'),
        style: 'destructive',
        onPress: async () => {
          await unlinkDoctor();
          await load();
        },
      },
    ]);
  };

  const onSyncNow = async () => {
    if (!activePatientId) return;
    setBusy(true);
    const ok = await syncToDoctor(activePatientId);
    setBusy(false);
    Alert.alert(ok ? t('doctor.syncDone') : t('doctor.networkError'));
  };

  return (
    <Screen>
      <Header title={t('doctor.title')} />

      <Card tone="primary" style={styles.intro}>
        <Ionicons name="medkit-outline" size={26} color={colors.primary} />
        <Text variant="body" color="textMuted" style={styles.flex}>
          {t('doctor.subtitle')}
        </Text>
      </Card>

      {link ? (
        <>
          <Card style={styles.statusCard}>
            <View style={styles.statusIcon}>
              <Ionicons name="checkmark-circle" size={28} color={colors.success} />
            </View>
            <Text variant="caption" color="textMuted">
              {t('doctor.connectedTo')}
            </Text>
            <Text variant="subheading">{link.doctorName || t('doctor.yourDoctor')}</Text>
            <Text variant="caption" color="textFaint">
              {t('doctor.code')}: {link.pairCode}
            </Text>
          </Card>

          <Button
            label={t('doctor.syncNow')}
            icon="sync"
            variant="secondary"
            loading={busy}
            onPress={onSyncNow}
          />
          <View style={styles.spacer} />
          <Button label={t('doctor.disconnect')} variant="ghost" onPress={onDisconnect} />
        </>
      ) : (
        <Card>
          <Text variant="bodyStrong">{t('doctor.enterCodeTitle')}</Text>
          <Text variant="caption" color="textMuted" style={styles.hint}>
            {t('doctor.enterCodeHint')}
          </Text>
          <Input
            value={code}
            onChangeText={(v) => {
              setCode(v.toUpperCase());
              setError('');
            }}
            placeholder="MED-XXXXXX"
            autoCapitalize="characters"
            icon="key-outline"
            error={error}
          />
          <Button
            label={t('doctor.connect')}
            icon="link"
            loading={busy}
            onPress={onConnect}
            style={styles.connectBtn}
          />
        </Card>
      )}

      <Text variant="caption" color="textFaint" style={styles.privacy}>
        {t('doctor.privacyNote')}
      </Text>
    </Screen>
  );
}

const styles = StyleSheet.create({
  intro: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginBottom: spacing.lg },
  flex: { flex: 1 },
  statusCard: { alignItems: 'center', gap: 4, marginBottom: spacing.lg },
  statusIcon: { marginBottom: spacing.xs },
  hint: { marginBottom: spacing.md },
  connectBtn: { marginTop: spacing.md },
  spacer: { height: spacing.sm },
  privacy: { marginTop: spacing.xl, textAlign: 'center' },
});
