import { useState } from 'react';
import { Platform, StyleSheet, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import DateTimePicker, {
  DateTimePickerEvent,
} from '@react-native-community/datetimepicker';
import { Input } from './Input';
import { Button } from './Button';
import { colors, radius, spacing } from '@/theme';
import { formatDate, dayjs } from '@/lib/date';

interface DateFieldProps {
  label?: string;
  value: string | null; // ISO date
  onChange: (iso: string) => void;
  mode?: 'date' | 'datetime';
  maximumDate?: Date;
  minimumDate?: Date;
  locale?: string;
  placeholder?: string;
}

export function DateField({
  label,
  value,
  onChange,
  mode = 'date',
  maximumDate,
  minimumDate,
  locale = 'vi',
  placeholder,
}: DateFieldProps) {
  const { t } = useTranslation();
  const [show, setShow] = useState(false);
  // iOS renders an inline wheel that never dismisses itself, so the pending
  // selection is held here until the user confirms. Android uses its own dialog.
  const [draft, setDraft] = useState<Date | null>(null);

  const open = () => {
    setDraft(value ? new Date(value) : new Date());
    setShow(true);
  };

  const handleChange = (event: DateTimePickerEvent, selected?: Date) => {
    if (Platform.OS === 'android') {
      setShow(false);
      if (event.type === 'set' && selected) onChange(dayjs(selected).toISOString());
      return;
    }
    if (selected) setDraft(selected);
  };

  const confirm = () => {
    onChange(dayjs(draft ?? new Date()).toISOString());
    setShow(false);
  };

  const display =
    mode === 'datetime'
      ? value
        ? dayjs(value).locale(locale).format('DD/MM/YYYY HH:mm')
        : ''
      : value
        ? formatDate(value, locale)
        : '';

  return (
    <>
      <Input
        label={label}
        value={display}
        placeholder={placeholder}
        icon="calendar-outline"
        onPressContainer={open}
      />
      {show && (
        <View style={Platform.OS === 'ios' ? styles.sheet : undefined}>
          <DateTimePicker
            value={draft ?? (value ? new Date(value) : new Date())}
            mode={mode}
            display={Platform.OS === 'ios' ? 'spinner' : 'default'}
            onChange={handleChange}
            maximumDate={maximumDate}
            minimumDate={minimumDate}
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
  sheet: {
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    padding: spacing.md,
    marginBottom: spacing.md,
    gap: spacing.sm,
  },
});
