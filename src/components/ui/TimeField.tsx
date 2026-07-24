import { useState } from 'react';
import { Platform, Pressable, StyleSheet } from 'react-native';
import DateTimePicker, {
  DateTimePickerEvent,
} from '@react-native-community/datetimepicker';
import { Ionicons } from '@expo/vector-icons';
import { Text } from './Text';
import { colors, radius, spacing } from '@/theme';
import { dayjs } from '@/lib/date';

interface TimeFieldProps {
  value: string; // HH:mm
  onChange: (hhmm: string) => void;
  onRemove?: () => void;
}

export function TimeField({ value, onChange, onRemove }: TimeFieldProps) {
  const [show, setShow] = useState(false);

  const handleChange = (event: DateTimePickerEvent, selected?: Date) => {
    if (Platform.OS === 'android') setShow(false);
    if (event.type === 'set' && selected) {
      onChange(dayjs(selected).format('HH:mm'));
    }
  };

  const baseDate = dayjs(value, 'HH:mm');

  return (
    <>
      <Pressable style={styles.chip} onPress={() => setShow(true)}>
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
        <DateTimePicker
          value={baseDate.isValid() ? baseDate.toDate() : new Date()}
          mode="time"
          is24Hour
          display={Platform.OS === 'ios' ? 'spinner' : 'default'}
          onChange={handleChange}
        />
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
});
