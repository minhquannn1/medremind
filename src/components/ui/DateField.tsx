import { useState } from 'react';
import { Platform } from 'react-native';
import DateTimePicker, {
  DateTimePickerEvent,
} from '@react-native-community/datetimepicker';
import { Input } from './Input';
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
  const [show, setShow] = useState(false);

  const handleChange = (event: DateTimePickerEvent, selected?: Date) => {
    if (Platform.OS === 'android') setShow(false);
    if (event.type === 'set' && selected) {
      onChange(dayjs(selected).toISOString());
    }
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
        onPressContainer={() => setShow(true)}
      />
      {show && (
        <DateTimePicker
          value={value ? new Date(value) : new Date()}
          mode={mode}
          display={Platform.OS === 'ios' ? 'spinner' : 'default'}
          onChange={handleChange}
          maximumDate={maximumDate}
          minimumDate={minimumDate}
        />
      )}
    </>
  );
}
