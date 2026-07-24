import { View, Pressable, StyleSheet, Image } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTranslation } from 'react-i18next';
import { Text, Card, Badge } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import type { TodayDose } from '@/db/repositories/doses';

interface DoseCardProps {
  dose: TodayDose;
  onTake: () => void;
  onSkip?: () => void;
}

const formIcon: Record<string, keyof typeof Ionicons.glyphMap> = {
  tablet: 'ellipse',
  capsule: 'medical',
  syrup: 'flask',
  drops: 'water',
  injection: 'fitness',
  cream: 'bandage',
};

export function DoseCard({ dose, onTake, onSkip }: DoseCardProps) {
  const { t } = useTranslation();
  const taken = dose.status === 'taken';
  const skipped = dose.status === 'skipped';

  const mealLabel =
    dose.relationToMeal && dose.relationToMeal !== 'anytime'
      ? t(`dose.${dose.relationToMeal}Meal`)
      : null;

  return (
    <Card style={[styles.card, taken && styles.cardDone]}>
      <View style={styles.timeCol}>
        <Text variant="bodyStrong" color={taken ? 'textFaint' : 'primary'}>
          {dose.time}
        </Text>
        {dose.imageUri ? (
          <Image
            source={{ uri: dose.imageUri }}
            style={[styles.photoDot, taken && styles.cardDone]}
            resizeMode="cover"
          />
        ) : (
          <View style={[styles.iconDot, taken && styles.iconDotDone]}>
            <Ionicons
              name={formIcon[dose.form ?? ''] ?? 'medical'}
              size={16}
              color={taken ? colors.textFaint : colors.primary}
            />
          </View>
        )}
      </View>

      <View style={styles.info}>
        <Text variant="bodyStrong" style={taken ? styles.struck : undefined} numberOfLines={1}>
          {dose.medicationName}
        </Text>
        {dose.dosage && (
          <Text variant="caption" color="textMuted">
            {dose.dosage}
          </Text>
        )}
        <View style={styles.tags}>
          {mealLabel && <Badge label={mealLabel} tone="neutral" />}
          {skipped && <Badge label={t('dose.skipped')} tone="warn" />}
        </View>
      </View>

      {taken ? (
        <View style={styles.takenBtn}>
          <Ionicons name="checkmark-circle" size={32} color={colors.success} />
        </View>
      ) : (
        <View style={styles.actions}>
          {onSkip && (
            <Pressable onPress={onSkip} hitSlop={8} style={styles.skipBtn}>
              <Ionicons name="close" size={20} color={colors.textFaint} />
            </Pressable>
          )}
          <Pressable onPress={onTake} hitSlop={8} style={styles.checkBtn} accessibilityLabel={t('dose.take')}>
            <Ionicons name="checkmark" size={22} color={colors.textInverse} />
          </Pressable>
        </View>
      )}
    </Card>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginBottom: spacing.md,
  },
  cardDone: { opacity: 0.7 },
  timeCol: { alignItems: 'center', gap: spacing.xs, width: 48 },
  iconDot: {
    width: 32,
    height: 32,
    borderRadius: radius.pill,
    backgroundColor: colors.primarySoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconDotDone: { backgroundColor: colors.canvas },
  photoDot: { width: 32, height: 32, borderRadius: radius.pill },
  info: { flex: 1, gap: 2 },
  struck: { textDecorationLine: 'line-through', color: colors.textFaint },
  tags: { flexDirection: 'row', gap: spacing.xs, marginTop: 4, flexWrap: 'wrap' },
  actions: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  skipBtn: {
    width: 40,
    height: 40,
    borderRadius: radius.pill,
    backgroundColor: colors.canvas,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkBtn: {
    width: 44,
    height: 44,
    borderRadius: radius.pill,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  takenBtn: { width: 44, alignItems: 'center', justifyContent: 'center' },
});
