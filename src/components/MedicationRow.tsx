import { View, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';
import { Text, Card, Badge } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import type { Medication, ScheduleTime } from '@/db/schema';

interface MedicationRowProps {
  medication: Medication;
  times: ScheduleTime[];
  onPress?: () => void;
  lowStockThreshold?: number;
}

const formIcon: Record<string, keyof typeof Ionicons.glyphMap> = {
  tablet: 'ellipse',
  capsule: 'medical',
  syrup: 'flask',
  drops: 'water',
  injection: 'fitness',
  cream: 'bandage',
};

export function MedicationRow({
  medication,
  times,
  onPress,
  lowStockThreshold = 5,
}: MedicationRowProps) {
  const { t } = useTranslation();
  const remaining = medication.quantityRemaining;
  const total = medication.quantityTotal;
  const isLow = remaining != null && remaining <= lowStockThreshold;
  const stockRatio = total && total > 0 && remaining != null ? remaining / total : null;

  return (
    <Card style={styles.card} onPress={onPress}>
      <View style={styles.head}>
        <View style={styles.icon}>
          <Ionicons
            name={formIcon[medication.form ?? ''] ?? 'medical'}
            size={20}
            color={colors.primary}
          />
        </View>
        <View style={styles.flex}>
          <Text variant="bodyStrong" numberOfLines={1}>
            {medication.name}
          </Text>
          {medication.dosage && (
            <Text variant="caption" color="textMuted">
              {medication.dosage}
            </Text>
          )}
        </View>
        {onPress && <Ionicons name="chevron-forward" size={18} color={colors.textFaint} />}
      </View>

      <View style={styles.times}>
        {times.map((tm) => (
          <View key={tm.id} style={styles.timeChip}>
            <Ionicons name="time-outline" size={13} color={colors.textMuted} />
            <Text variant="caption" color="textMuted">
              {tm.time}
            </Text>
          </View>
        ))}
      </View>

      {(remaining != null || medication.durationDays) && (
        <View style={styles.footer}>
          {remaining != null && (
            <View style={styles.stock}>
              {stockRatio != null && (
                <View style={styles.bar}>
                  <View
                    style={[
                      styles.barFill,
                      { width: `${Math.max(4, stockRatio * 100)}%` },
                      isLow && styles.barFillLow,
                    ]}
                  />
                </View>
              )}
              <Text variant="caption" color={isLow ? 'danger' : 'textMuted'}>
                {t('medication.quantityRemaining')}: {remaining}
                {total != null ? ` / ${total}` : ''}
              </Text>
            </View>
          )}
          {isLow && <Badge label={t('home.refillAlert')} tone="danger" icon="alert-circle" />}
        </View>
      )}
    </Card>
  );
}

const styles = StyleSheet.create({
  card: { marginBottom: spacing.md, gap: spacing.md },
  head: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  flex: { flex: 1 },
  icon: {
    width: 40,
    height: 40,
    borderRadius: radius.md,
    backgroundColor: colors.primarySoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  times: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  timeChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: colors.canvas,
    paddingVertical: 4,
    paddingHorizontal: spacing.sm,
    borderRadius: radius.sm,
  },
  footer: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.md },
  stock: { flex: 1, gap: 4 },
  bar: { height: 6, borderRadius: radius.pill, backgroundColor: colors.canvas, overflow: 'hidden' },
  barFill: { height: 6, borderRadius: radius.pill, backgroundColor: colors.primary },
  barFillLow: { backgroundColor: colors.danger },
});
