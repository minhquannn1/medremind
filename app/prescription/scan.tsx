import { useRef, useState } from 'react';
import { View, StyleSheet, Pressable, ActivityIndicator, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { CameraView, useCameraPermissions } from 'expo-camera';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Header, Text, Button } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import { scanPrescriptionImage, type ScannedMedication } from '@/features/scan/aiScanner';
import type { MedicationDraft } from '@/features/prescription/draft';

export default function ScanPrescription() {
  const { t } = useTranslation();
  const router = useRouter();
  const cameraRef = useRef<CameraView>(null);
  const [permission, requestPermission] = useCameraPermissions();
  const [processing, setProcessing] = useState(false);

  const mapToDraft = (m: ScannedMedication): Partial<MedicationDraft> => ({
    name: m.name,
    form: (m.form as MedicationDraft['form']) ?? 'tablet',
    dosage: m.dosage ?? '',
    relationToMeal: (m.relationToMeal as MedicationDraft['relationToMeal']) ?? 'anytime',
    takeWith: m.takeWith ?? '',
    durationDays: m.durationDays != null ? String(m.durationDays) : '',
    quantityTotal: m.quantityTotal != null ? String(m.quantityTotal) : '',
    notes: m.notes ?? '',
    times: m.times?.length ? m.times : ['08:00'],
  });

  const processImage = async (uri: string, base64?: string) => {
    if (!base64) {
      Alert.alert(t('scan.title'), t('scan.noText'));
      return;
    }
    setProcessing(true);
    try {
      const result = await scanPrescriptionImage(base64, 'image/jpeg');

      if (!result.ok) {
        const msg =
          result.error === 'timeout'
            ? t('scan.timeout')
            : result.error === 'network'
              ? t('scan.networkError')
              : t('scan.serverError');
        Alert.alert(t('scan.title'), msg, [
          { text: t('scan.retake'), style: 'cancel' },
          { text: t('prescriptions.addManual'), onPress: () => goToReview(uri, []) },
        ]);
        return;
      }

      const meds = result.medications.map(mapToDraft);

      if (meds.length === 0) {
        Alert.alert(t('scan.title'), t('scan.noMedsParsed'), [
          { text: t('scan.retake'), style: 'cancel' },
          {
            text: t('common.next'),
            onPress: () =>
              goToReview(uri, [], {
                rawText: result.rawText,
                doctorName: result.doctorName,
                clinic: result.clinic,
                issuedDate: result.issuedDate,
              }),
          },
        ]);
        return;
      }

      goToReview(uri, meds, {
        rawText: result.rawText,
        doctorName: result.doctorName,
        clinic: result.clinic,
        issuedDate: result.issuedDate,
      });
    } catch (e) {
      Alert.alert('Error', String(e));
    } finally {
      setProcessing(false);
    }
  };

  const goToReview = (
    uri: string,
    meds: Partial<MedicationDraft>[],
    extra?: { rawText?: string; doctorName?: string; clinic?: string; issuedDate?: string },
  ) => {
    router.replace({
      pathname: '/prescription/new',
      params: {
        prefill: JSON.stringify({ imageUri: uri, medications: meds, ...extra }),
      },
    });
  };

  const capture = async () => {
    if (!cameraRef.current) return;
    const photo = await cameraRef.current.takePictureAsync({ quality: 0.6, base64: true });
    if (photo?.uri) await processImage(photo.uri, photo.base64);
  };

  const pickFromGallery = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      quality: 0.6,
      base64: true,
    });
    if (!result.canceled && result.assets[0]) {
      await processImage(result.assets[0].uri, result.assets[0].base64 ?? undefined);
    }
  };

  // Permission gate
  if (!permission) {
    return (
      <Screen>
        <Header title={t('scan.title')} />
        <ActivityIndicator color={colors.primary} />
      </Screen>
    );
  }

  if (!permission.granted) {
    return (
      <Screen>
        <Header title={t('scan.title')} />
        <View style={styles.permission}>
          <View style={styles.permIcon}>
            <Ionicons name="camera-outline" size={40} color={colors.primary} />
          </View>
          <Text variant="subheading" center>
            {t('scan.permissionTitle')}
          </Text>
          <Text variant="body" color="textMuted" center style={styles.permBody}>
            {t('scan.permissionBody')}
          </Text>
          <Button label={t('scan.grant')} icon="camera" onPress={requestPermission} fullWidth={false} />
          <Pressable onPress={pickFromGallery} style={styles.galleryLink}>
            <Ionicons name="images-outline" size={18} color={colors.primary} />
            <Text variant="label" color="primary">
              {t('scan.fromGallery')}
            </Text>
          </Pressable>
        </View>
      </Screen>
    );
  }

  return (
    <View style={styles.fullscreen}>
      <CameraView ref={cameraRef} style={styles.camera} facing="back" />

      {/* Overlay frame */}
      <View style={styles.overlay} pointerEvents="box-none">
        <View style={styles.topBar}>
          <Pressable onPress={() => router.back()} hitSlop={10} style={styles.closeBtn}>
            <Ionicons name="close" size={26} color={colors.textInverse} />
          </Pressable>
          <Text variant="bodyStrong" color="textInverse">
            {t('scan.title')}
          </Text>
          <View style={styles.closeBtn} />
        </View>

        <View style={styles.frame} />

        <Text variant="body" color="textInverse" center style={styles.instruction}>
          {t('scan.instruction')}
        </Text>

        <View style={styles.controls}>
          <Pressable onPress={pickFromGallery} style={styles.sideBtn}>
            <Ionicons name="images" size={26} color={colors.textInverse} />
          </Pressable>
          <Pressable onPress={capture} style={styles.shutter} disabled={processing}>
            <View style={styles.shutterInner} />
          </Pressable>
          <View style={styles.sideBtn} />
        </View>
      </View>

      {processing && (
        <View style={styles.processing}>
          <ActivityIndicator size="large" color={colors.textInverse} />
          <Text variant="bodyStrong" color="textInverse" style={styles.processingText}>
            {t('scan.aiReading')}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  fullscreen: { flex: 1, backgroundColor: '#000' },
  camera: { ...StyleSheet.absoluteFillObject },
  overlay: { flex: 1, justifyContent: 'space-between', paddingVertical: spacing['3xl'] },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.lg,
    marginTop: spacing.xl,
  },
  closeBtn: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center' },
  frame: {
    marginHorizontal: spacing.xl,
    flex: 1,
    marginVertical: spacing.xl,
    borderWidth: 2,
    borderColor: 'rgba(255,255,255,0.7)',
    borderRadius: radius.lg,
    borderStyle: 'dashed',
  },
  instruction: { marginHorizontal: spacing.xl, marginBottom: spacing.lg },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingHorizontal: spacing.xl,
  },
  sideBtn: { width: 56, height: 56, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center' },
  shutter: {
    width: 76,
    height: 76,
    borderRadius: radius.pill,
    backgroundColor: 'rgba(255,255,255,0.3)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  shutterInner: { width: 60, height: 60, borderRadius: radius.pill, backgroundColor: colors.textInverse },
  permission: { alignItems: 'center', gap: spacing.md, paddingTop: spacing['3xl'] },
  permIcon: {
    width: 80,
    height: 80,
    borderRadius: radius.pill,
    backgroundColor: colors.primarySoft,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.sm,
  },
  permBody: { maxWidth: 280, marginBottom: spacing.lg },
  galleryLink: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginTop: spacing.lg },
  processing: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.md,
  },
  processingText: { marginTop: spacing.sm, textAlign: 'center', maxWidth: 260 },
});
