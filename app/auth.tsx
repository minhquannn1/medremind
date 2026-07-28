import { useState } from 'react';
import { View, StyleSheet, Pressable } from 'react-native';
import { useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Text, Input, Button } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import type { AuthErrorCode } from '@/features/auth/patientAuth';

type Mode = 'login' | 'signup';

export default function Auth() {
  const { t } = useTranslation();
  const router = useRouter();
  const signIn = useAppStore((s) => s.signIn);
  const signUp = useAppStore((s) => s.signUp);

  const [mode, setMode] = useState<Mode>('login');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const errorText = (code: AuthErrorCode): string => {
    const map: Record<AuthErrorCode, string> = {
      email_taken: t('auth.errorEmailTaken'),
      invalid_credentials: t('auth.errorInvalidCredentials'),
      account_deleted: t('auth.errorAccountDeleted'),
      weak_password: t('auth.errorWeakPassword'),
      missing_fields: t('auth.errorMissingFields'),
      network: t('auth.errorNetwork'),
    };
    return map[code];
  };

  const onSubmit = async () => {
    setError('');
    if (!email.trim() || !password || (mode === 'signup' && !name.trim())) {
      setError(t('auth.errorMissingFields'));
      return;
    }
    setBusy(true);
    const res =
      mode === 'signup'
        ? await signUp(email, password, name)
        : await signIn(email, password);
    setBusy(false);
    if (res.ok) {
      router.replace('/');
    } else {
      setError(errorText(res.error));
    }
  };

  const toggleMode = () => {
    setMode((m) => (m === 'login' ? 'signup' : 'login'));
    setError('');
  };

  return (
    <Screen>
      <View style={styles.hero}>
        <View style={styles.logo}>
          <Ionicons name="medkit" size={34} color={colors.textInverse} />
        </View>
        <Text variant="title" style={styles.title}>
          {t('common.appName')}
        </Text>
        <Text variant="body" color="textMuted">
          {mode === 'login' ? t('auth.loginSubtitle') : t('auth.signupSubtitle')}
        </Text>
      </View>

      <View style={styles.form}>
        {mode === 'signup' && (
          <Input
            label={t('profile.fullName')}
            value={name}
            onChangeText={setName}
            placeholder={t('profile.fullName')}
            icon="person-outline"
            autoCapitalize="words"
          />
        )}
        <Input
          label={t('auth.email')}
          value={email}
          onChangeText={(v) => {
            setEmail(v);
            setError('');
          }}
          placeholder="you@example.com"
          icon="mail-outline"
          keyboardType="email-address"
          autoCapitalize="none"
          autoCorrect={false}
        />
        <Input
          label={t('auth.password')}
          value={password}
          onChangeText={(v) => {
            setPassword(v);
            setError('');
          }}
          placeholder="••••••"
          icon="lock-closed-outline"
          secureTextEntry
          error={error}
        />

        <Button
          label={mode === 'login' ? t('auth.login') : t('auth.signup')}
          onPress={onSubmit}
          loading={busy}
          icon="arrow-forward"
          size="lg"
          style={styles.submit}
        />
      </View>

      <Pressable onPress={toggleMode} style={styles.switch} hitSlop={8}>
        <Text variant="body" color="textMuted" center>
          {mode === 'login' ? t('auth.noAccount') : t('auth.haveAccount')}{' '}
          <Text variant="bodyStrong" color="primary">
            {mode === 'login' ? t('auth.signup') : t('auth.login')}
          </Text>
        </Text>
      </Pressable>
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: { marginTop: spacing.xl, marginBottom: spacing.xl },
  logo: {
    width: 64,
    height: 64,
    borderRadius: radius.lg,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.lg,
  },
  title: { marginBottom: spacing.sm },
  form: { marginTop: spacing.sm },
  submit: { marginTop: spacing.md },
  switch: { marginTop: spacing.xl, alignItems: 'center' },
});
