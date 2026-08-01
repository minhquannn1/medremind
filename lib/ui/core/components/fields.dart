import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_input.dart';
import 'package:medremind/ui/core/components/app_text.dart';

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

/// A common dose time offered as a one-tap shortcut.
class _Preset {
  const _Preset(this.time, this.labelKey);
  final String time;
  final String labelKey;
}

const List<_Preset> _presets = [
  _Preset('08:00', 'schedule.morning'),
  _Preset('12:00', 'schedule.noon'),
  _Preset('18:00', 'schedule.evening'),
  _Preset('21:00', 'schedule.night'),
];

class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.title,
    this.presetLabels,
    this.doneLabel,
    this.cancelLabel,
  });

  /// "HH:mm" 24-hour string.
  final String value;
  final String? label;
  final ValueChanged<String> onChanged;

  /// Sheet copy, passed in so it stays in the app's language.
  final String? title;
  final Map<String, String>? presetLabels;
  final String? doneLabel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: formatTime(value));

    return AppInput(
      controller: controller,
      label: label,
      icon: Icons.access_time,
      editableLook: false,
      onPressContainer: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: AppColors.surface,
          // The sheet is tall; without this it is capped at half the screen
          // and overflows on short phones or at large text sizes.
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          ),
          builder: (_) => _TimeSheet(
            initial: value,
            title: title,
            presetLabels: presetLabels,
            doneLabel: doneLabel,
            cancelLabel: cancelLabel,
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Bottom sheet with one-tap presets over a large scrolling wheel.
///
/// Replaces the Material dial, which needs a precise drag onto a small target —
/// awkward on a phone, and harder still for the older users this app serves.
class _TimeSheet extends StatefulWidget {
  const _TimeSheet({
    required this.initial,
    this.title,
    this.presetLabels,
    this.doneLabel,
    this.cancelLabel,
  });

  final String initial;
  final String? title;
  final Map<String, String>? presetLabels;
  final String? doneLabel;
  final String? cancelLabel;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    final parts = widget.initial.split(':');
    _hour = (int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8).clamp(0, 23);
    _minute =
        (int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0).clamp(0, 59);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  String get _formatted =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  void _applyPreset(String time) {
    final parts = time.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    setState(() {
      _hour = h;
      _minute = m;
    });
    // Move the wheels too, so the sheet never shows two different answers.
    _hourCtrl.animateToItem(h,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    _minuteCtrl.animateToItem(m,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
    required int selected,
  }) {
    return SizedBox(
      width: 92,
      height: 180,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 44,
        squeeze: 1.1,
        magnification: 1.1,
        useMagnifier: true,
        selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
          background: Color(0x1A0E7C7B),
        ),
        onSelectedItemChanged: onChanged,
        children: List.generate(
          count,
          (i) => Center(
            child: AppText(
              i.toString().padLeft(2, '0'),
              variant: TextVariant.heading,
              color:
                  i == selected ? TextColorKey.primary : TextColorKey.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            Spacing.xl, Spacing.lg, Spacing.xl, Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            const SizedBox(height: Spacing.lg),

            if (widget.title != null)
              AppText(widget.title!, variant: TextVariant.subheading),
            const SizedBox(height: Spacing.md),

            // The chosen time, large enough to read at a glance.
            AppText(_formatted,
                variant: TextVariant.display, color: TextColorKey.primary),
            const SizedBox(height: Spacing.md),

            // One-tap common times — most doses land on one of these.
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              alignment: WrapAlignment.center,
              children: _presets.map((p) {
                final active = _formatted == p.time;
                return GestureDetector(
                  onTap: () => _applyPreset(p.time),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg, vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.canvas,
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: AppText(
                      '${widget.presetLabels?[p.labelKey] ?? ''} ${p.time}'
                          .trim(),
                      variant: TextVariant.label,
                      style: TextStyle(
                        color: active
                            ? AppColors.textInverse
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _wheel(
                  controller: _hourCtrl,
                  count: 24,
                  selected: _hour,
                  onChanged: (i) => setState(() => _hour = i),
                ),
                const AppText(':', variant: TextVariant.heading),
                _wheel(
                  controller: _minuteCtrl,
                  count: 60,
                  selected: _minute,
                  onChanged: (i) => setState(() => _minute = i),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),

            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: widget.cancelLabel ?? 'Cancel',
                    variant: ButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: AppButton(
                    label: widget.doneLabel ?? 'Done',
                    icon: Icons.check,
                    onPressed: () => Navigator.of(context).pop(_formatted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
