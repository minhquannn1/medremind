import { useState } from 'react';
import { View, StyleSheet, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Text, Button, Input, SegmentedControl, DateField } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import { createPatient } from '@/db/repositories/patients';
import { useAppStore } from '@/store/appStore';
import { ageFromDob } from '@/lib/date';

type Gender = 'male' | 'female' | 'other';

export default function Onboarding() {
  const { t } = useTranslation();
  const router = useRouter();
  const completeOnboarding = useAppStore((s) => s.completeOnboarding);
  const account = useAppStore((s) => s.account);

  const [fullName, setFullName] = useState('');
  const [dob, setDob] = useState<string | null>(null);
  const [gender, setGender] = useState<Gender | null>(null);
  const [height, setHeight] = useState('');
  const [weight, setWeight] = useState('');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  const onStart = async () => {
    if (!fullName.trim()) {
      setError(t('common.required'));
      return;
    }
    setSaving(true);
    try {
      const id = await createPatient({
        fullName: fullName.trim(),
        dob,
        gender,
        heightCm: height ? Number(height) : null,
        weightKg: weight ? Number(weight) : null,
        accountUserId: account?.userId ?? null,
        accountEmail: account?.email ?? null,
      });
      await completeOnboarding(id);
      router.replace('/(tabs)');
    } catch (e) {
      Alert.alert('Error', String(e));
      setSaving(false);
    }
  };

  return (
    <Screen>
      <View style={styles.hero}>
        <View style={styles.logo}>
          <Ionicons name="medkit" size={34} color={colors.textInverse} />
        </View>
        <Text variant="title" style={styles.title}>
          {t('onboarding.welcomeTitle')}
        </Text>
        <Text variant="body" color="textMuted">
          {t('onboarding.welcomeBody')}
        </Text>
      </View>

      <View style={styles.form}>
        <Text variant="subheading" style={styles.formTitle}>
          {t('onboarding.createProfile')}
        </Text>
        <Text variant="caption" color="textFaint" style={styles.hint}>
          {t('onboarding.profileHint')}
        </Text>

        <Input
          label={t('profile.fullName')}
          value={fullName}
          onChangeText={(v) => {
            setFullName(v);
            setError('');
          }}
          placeholder={t('profile.fullName')}
          icon="person-outline"
          error={error}
        />

        <DateField
          label={t('profile.dob')}
          value={dob}
          onChange={setDob}
          maximumDate={new Date()}
          placeholder="DD/MM/YYYY"
        />

        <SegmentedControl<Gender>
          label={t('profile.gender')}
          value={gender}
          onChange={setGender}
          options={[
            { value: 'male', label: t('profile.genders.male') },
            { value: 'female', label: t('profile.genders.female') },
            { value: 'other', label: t('profile.genders.other') },
          ]}
        />

        <View style={styles.row}>
          <View style={styles.half}>
            <Input
              label={t('profile.height')}
              value={height}
              onChangeText={setHeight}
              keyboardType="numeric"
              suffix="cm"
              placeholder="170"
            />
          </View>
          <View style={styles.half}>
            <Input
              label={t('profile.weight')}
              value={weight}
              onChangeText={setWeight}
              keyboardType="numeric"
              suffix="kg"
              placeholder="65"
            />
          </View>
        </View>
      </View>

      <Button
        label={t('onboarding.start')}
        onPress={onStart}
        loading={saving}
        icon="arrow-forward"
        size="lg"
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: { marginTop: spacing.xl, marginBottom: spacing['2xl'] },
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
  form: { marginBottom: spacing.xl },
  formTitle: { marginBottom: spacing.xs },
  hint: { marginBottom: spacing.lg },
  row: { flexDirection: 'row', gap: spacing.md },
  half: { flex: 1 },
});
