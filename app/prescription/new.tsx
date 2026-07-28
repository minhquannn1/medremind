import { useMemo, useState } from 'react';
import { View, StyleSheet, Alert, Image, Pressable } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';

import { Screen, Header, Text, Card, Input, Button, DateField } from '@/components/ui';
import { MedicationEditor } from '@/features/prescription/MedicationEditor';
import {
  emptyMedicationDraft,
  type MedicationDraft,
} from '@/features/prescription/draft';
import { savePrescription } from '@/features/prescription/save';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import {
  ensureMediaLibraryPermission,
  ensureNotificationPermission,
} from '@/features/permissions/ensure';

interface Prefill {
  doctorName?: string;
  clinic?: string;
  issuedDate?: string | null;
  imageUri?: string | null;
  medications?: Partial<MedicationDraft>[];
  rawText?: string;
}

export default function NewPrescription() {
  const { t } = useTranslation();
  const router = useRouter();
  const { activePatientId } = useAppStore();
  const params = useLocalSearchParams<{ prefill?: string }>();

  const prefill = useMemo<Prefill>(() => {
    if (!params.prefill) return {};
    try {
      return JSON.parse(params.prefill) as Prefill;
    } catch {
      return {};
    }
  }, [params.prefill]);

  const [doctorName, setDoctorName] = useState(prefill.doctorName ?? '');
  const [clinic, setClinic] = useState(prefill.clinic ?? '');
  const [issuedDate, setIssuedDate] = useState<string | null>(prefill.issuedDate ?? null);
  const [notes, setNotes] = useState('');
  const [imageUri, setImageUri] = useState<string | null>(prefill.imageUri ?? null);
  const [drafts, setDrafts] = useState<MedicationDraft[]>(
    prefill.medications?.length
      ? prefill.medications.map((m) => emptyMedicationDraft(m))
      : [emptyMedicationDraft()],
  );
  const [saving, setSaving] = useState(false);

  const updateDraft = (key: string, next: MedicationDraft) =>
    setDrafts((prev) => prev.map((d) => (d.key === key ? next : d)));
  const addDraft = () => setDrafts((prev) => [...prev, emptyMedicationDraft()]);
  const removeDraft = (key: string) =>
    setDrafts((prev) => prev.filter((d) => d.key !== key));

  const pickImage = async () => {
    if (!(await ensureMediaLibraryPermission())) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      quality: 0.6,
    });
    if (!result.canceled && result.assets[0]) {
      setImageUri(result.assets[0].uri);
    }
  };

  const onSave = async () => {
    if (!activePatientId) return;
    const named = drafts.filter((d) => d.name.trim());
    if (named.length === 0) {
      Alert.alert(t('prescriptions.title'), t('medication.name') + ' ' + t('common.required'));
      return;
    }
    setSaving(true);
    try {
      await ensureNotificationPermission();
      await savePrescription(
        activePatientId,
        { doctorName, clinic, issuedDate, notes, imageUri },
        drafts,
      );
      router.back();
    } catch (e) {
      Alert.alert('Error', String(e));
      setSaving(false);
    }
  };

  const fromScan = Boolean(prefill.medications?.length || prefill.rawText);

  return (
    <Screen>
      <Header title={t('prescriptions.new')} />

      {/* AI results are reference-only — the user must verify against the
          original prescription (App Review guideline 1.4.1). */}
      {fromScan ? (
        <View style={styles.disclaimer}>
          <Ionicons name="information-circle-outline" size={18} color={colors.textMuted} />
          <Text variant="caption" color="textMuted" style={styles.disclaimerText}>
            {t('scan.disclaimer')}
          </Text>
        </View>
      ) : null}

      {/* Prescription header */}
      <Card style={styles.section}>
        <Input
          label={t('prescriptions.doctor')}
          value={doctorName}
          onChangeText={setDoctorName}
          icon="person-outline"
        />
        <Input
          label={t('prescriptions.clinic')}
          value={clinic}
          onChangeText={setClinic}
          icon="business-outline"
        />
        <DateField
          label={t('prescriptions.issuedDate')}
          value={issuedDate}
          onChange={setIssuedDate}
          maximumDate={new Date()}
        />
        {imageUri ? (
          <Pressable onPress={pickImage} style={styles.photoWrap}>
            <Image source={{ uri: imageUri }} style={styles.photo} resizeMode="cover" />
            <View style={styles.photoEdit}>
              <Ionicons name="pencil" size={16} color={colors.textInverse} />
            </View>
          </Pressable>
        ) : (
          <Pressable style={styles.addPhoto} onPress={pickImage}>
            <Ionicons name="image-outline" size={22} color={colors.primary} />
            <Text variant="label" color="primary">
              {t('prescriptions.addPhoto')}
            </Text>
          </Pressable>
        )}
      </Card>

      {/* OCR-detected raw text (reference, when parser couldn't structure it) */}
      {prefill.rawText ? (
        <Card tone="primary" style={styles.rawText}>
          <Text variant="caption" color="primary">
            {t('scan.detectedText')}
          </Text>
          <Text variant="body" selectable style={styles.rawTextBody}>
            {prefill.rawText}
          </Text>
          <Text variant="caption" color="textFaint">
            {t('scan.detectedTextHint')}
          </Text>
        </Card>
      ) : null}

      {/* Medications */}
      <Text variant="subheading" style={styles.medsTitle}>
        {t('prescriptions.medications')}
      </Text>
      {drafts.map((draft, index) => (
        <MedicationEditor
          key={draft.key}
          draft={draft}
          index={index}
          onChange={(next) => updateDraft(draft.key, next)}
          onRemove={() => removeDraft(draft.key)}
          removable={drafts.length > 1}
        />
      ))}

      <Button
        label={t('prescriptions.addMedication')}
        variant="ghost"
        icon="add"
        onPress={addDraft}
        style={styles.addMed}
      />

      <Input
        label={t('prescriptions.notes')}
        value={notes}
        onChangeText={setNotes}
        multiline
      />

      <Button
        label={t('prescriptions.savePrescription')}
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
  section: { marginBottom: spacing.lg },
  disclaimer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: spacing.sm,
    marginBottom: spacing.md,
    paddingHorizontal: spacing.xs,
  },
  disclaimerText: { flex: 1 },
  rawText: { marginBottom: spacing.lg, gap: spacing.xs },
  rawTextBody: { fontFamily: 'Courier', lineHeight: 20 },
  medsTitle: { marginBottom: spacing.md },
  addMed: { marginBottom: spacing.xl },
  save: { marginTop: spacing.sm },
  addPhoto: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.lg,
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: colors.primary,
    borderStyle: 'dashed',
  },
  photoWrap: { borderRadius: radius.md, overflow: 'hidden' },
  photo: { width: '100%', height: 160, borderRadius: radius.md },
  photoEdit: {
    position: 'absolute',
    right: spacing.sm,
    bottom: spacing.sm,
    width: 32,
    height: 32,
    borderRadius: radius.pill,
    backgroundColor: colors.overlay,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
