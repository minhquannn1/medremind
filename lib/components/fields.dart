import 'package:flutter/material.dart';

import '../lib_date.dart';
import '../theme/tokens.dart';
import 'app_input.dart';

/// Date and time pickers rendered as tappable read-only inputs.
/// Ported from `src/components/ui/{DateField,TimeField}.tsx`.

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minimumDate,
    this.maximumDate,
    this.hint,
  });

  /// ISO date string, or null when unset.
  final String? value;
  final String label;
  final ValueChanged<String?> onChanged;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final controller =
        TextEditingController(text: value == null ? '' : formatDate(value));

    return AppInput(
      controller: controller,
      label: label,
      hint: hint,
      icon: Icons.calendar_today_outlined,
      placeholder: 'dd/mm/yyyy',
      editableLook: false,
      onPressContainer: () async {
        final initial = DateTime.tryParse(value ?? '') ?? DateTime.now();
        final first = minimumDate ?? DateTime(1900);
        final last = maximumDate ?? DateTime(2100);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial.isBefore(first)
              ? first
              : (initial.isAfter(last) ? last : initial),
          firstDate: first,
          lastDate: last,
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context)
                  .colorScheme
                  .copyWith(primary: AppColors.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(DateTime(picked.year, picked.month, picked.day)
              .toIso8601String());
        }
      },
    );
  }
}

class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
  });

  /// "HH:mm" 24-hour string.
  final String value;
  final String? label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: formatTime(value));

    return AppInput(
      controller: controller,
      label: label,
      icon: Icons.access_time,
      editableLook: false,
      onPressContainer: () async {
        final parts = value.split(':');
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8,
            minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
          ),
          builder: (context, child) => MediaQuery(
            // The app stores 24-hour strings; forcing 24h keeps the picker and
            // the stored value in the same format on every locale.
            data: MediaQuery.of(context)
                .copyWith(alwaysUse24HourFormat: true),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context)
                    .colorScheme
                    .copyWith(primary: AppColors.primary),
              ),
              child: child!,
            ),
          ),
        );
        if (picked != null) {
          onChanged('${picked.hour.toString().padLeft(2, '0')}:'
              '${picked.minute.toString().padLeft(2, '0')}');
        }
      },
    );
  }
}
