import { useCallback, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { Ionicons } from '@expo/vector-icons';

import { Screen, Header, Text, Card, Badge, EmptyState } from '@/components/ui';
import { colors, radius, spacing } from '@/theme';
import { useAppStore } from '@/store/appStore';
import { getDoseHistory, type HistoryDay, type DoseStatus } from '@/db/repositories/doses';
import { formatDate } from '@/lib/date';

const STATUS_META: Record<DoseStatus, { icon: keyof typeof Ionicons.glyphMap; color: string }> = {
  taken: { icon: 'checkmark-circle', color: colors.success },
  skipped: { icon: 'remove-circle', color: colors.textMuted },
  missed: { icon: 'close-circle', color: colors.danger },
  pending: { icon: 'ellipse-outline', color: colors.textFaint },
};

export default function History() {
  const { t } = useTranslation();
  const { activePatientId, language } = useAppStore();
  const [days, setDays] = useState<HistoryDay[]>([]);
  const [loaded, setLoaded] = useState(false);

  const load = useCallback(async () => {
    if (!activePatientId) return;
    setDays(await getDoseHistory(activePatientId, 30));
    setLoaded(true);
  }, [activePatientId]);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  return (
    <Screen>
      <Header title={t('history.title')} />
      <Text variant="caption" color="textFaint" style={styles.subtitle}>
        {t('history.subtitle')}
      </Text>

      {loaded && days.length === 0 ? (
        <EmptyState icon="time-outline" title={t('history.empty')} message={t('history.emptyBody')} />
      ) : (
        days.map((day) => (
          <View key={day.date} style={styles.daySection}>
            <View style={styles.dayHeader}>
              <Text variant="bodyStrong">{formatDate(day.date, language)}</Text>
              <Badge
                label={`${day.taken}/${day.total}`}
                tone={day.taken === day.total ? 'success' : day.taken === 0 ? 'danger' : 'warn'}
              />
            </View>
            <Card padded={false}>
              {day.doses.map((dose, i) => {
                const meta = STATUS_META[dose.status];
                return (
                  <View
                    key={dose.id}
                    style={[styles.doseRow, i > 0 && styles.doseRowBorder]}
                  >
                    <Ionicons name={meta.icon} size={20} color={meta.color} />
                    <View style={styles.flex}>
                      <Text variant="body">{dose.medicationName}</Text>
                      <Text variant="caption" color="textFaint">
                        {dose.time} · {t(`dose.${dose.status}`)}
                      </Text>
                    </View>
                  </View>
                );
              })}
            </Card>
          </View>
        ))
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  subtitle: { marginBottom: spacing.lg },
  daySection: { marginBottom: spacing.lg },
  dayHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: spacing.sm,
  },
  doseRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.md,
  },
  doseRowBorder: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: colors.border },
  flex: { flex: 1 },
});
