import { useState } from 'react';
import { Platform, Pressable, StyleSheet, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import DateTimePicker, {
  DateTimePickerEvent,
} from '@react-native-community/datetimepicker';
import { Ionicons } from '@expo/vector-icons';
import { Text } from './Text';
import { Button } from './Button';
import { colors, radius, spacing } from '@/theme';
import { dayjs } from '@/lib/date';

interface TimeFieldProps {
  value: string; // HH:mm
  onChange: (hhmm: string) => void;
  onRemove?: () => void;
}

export function TimeField({ value, onChange, onRemove }: TimeFieldProps) {
  const { t } = useTranslation();
  const [show, setShow] = useState(false);
  // See DateField: the iOS wheel stays on screen until the user confirms.
  const [draft, setDraft] = useState<Date | null>(null);

  const baseDate = dayjs(value, 'HH:mm');

  const open = () => {
    setDraft(baseDate.isValid() ? baseDate.toDate() : new Date());
    setShow(true);
  };

  const handleChange = (event: DateTimePickerEvent, selected?: Date) => {
    if (Platform.OS === 'android') {
      setShow(false);
      if (event.type === 'set' && selected) onChange(dayjs(selected).format('HH:mm'));
      return;
    }
    if (selected) setDraft(selected);
  };

  const confirm = () => {
    onChange(dayjs(draft ?? new Date()).format('HH:mm'));
    setShow(false);
  };

  return (
    <>
      <Pressable style={styles.chip} onPress={open}>
        <Ionicons name="time-outline" size={16} color={colors.primary} />
        <Text variant="bodyStrong" color="primary">
          {value}
        </Text>
        {onRemove && (
          <Pressable onPress={onRemove} hitSlop={8} style={styles.remove}>
            <Ionicons name="close-circle" size={18} color={colors.textFaint} />
          </Pressable>
        )}
      </Pressable>
      {show && (
        <View style={Platform.OS === 'ios' ? styles.sheet : undefined}>
          <DateTimePicker
            value={draft ?? (baseDate.isValid() ? baseDate.toDate() : new Date())}
            mode="time"
            is24Hour
            display={Platform.OS === 'ios' ? 'spinner' : 'default'}
            onChange={handleChange}
          />
          {Platform.OS === 'ios' && (
            <Button label={t('common.done')} icon="checkmark" onPress={confirm} />
          )}
        </View>
      )}
    </>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    backgroundColor: colors.primarySoft,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    borderRadius: radius.pill,
  },
  remove: { marginLeft: 2 },
  sheet: {
    width: '100%',
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    padding: spacing.md,
    marginTop: spacing.sm,
    gap: spacing.sm,
  },
});
