import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_button.dart';
import '../components/app_input.dart';
import '../components/controls.dart';
import '../components/fields.dart';
import '../components/layout.dart';
import '../db/repositories/appointments_repository.dart';
import '../store/app_state.dart';

/// Schedule a revisit or refill reminder. Ported from `app/appointment/new.tsx`.
class AppointmentNewScreen extends ConsumerStatefulWidget {
  const AppointmentNewScreen({super.key});

  @override
  ConsumerState<AppointmentNewScreen> createState() =>
      _AppointmentNewScreenState();
}

class _AppointmentNewScreenState
    extends ConsumerState<AppointmentNewScreen> {
  static const _repo = AppointmentsRepository();

  final _note = TextEditingController();
  String _type = 'revisit';
  String? _date;
  String _time = '09:00';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = ref.read(translationsProvider);
    final date = _date;
    if (date == null) {
      setState(() => _error = t.t('common.required'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final day = DateTime.parse(date);
    final parts = _time.split(':');
    final when = DateTime(
      day.year,
      day.month,
      day.day,
      int.tryParse(parts.first) ?? 9,
      int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );

    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId == null) return;

    final id = await _repo.createAppointment(
      patientId: patientId,
      type: _type,
      date: when.toUtc().toIso8601String(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    // Only schedule an alert for a future appointment — a past one would fire
    // immediately.
    final scheduler = ref.read(notificationSchedulerProvider);
    if (when.isAfter(DateTime.now()) && await scheduler.requestPermission()) {
      await scheduler.scheduleAppointmentReminder(
        // Offset keeps appointment ids clear of the dose-reminder range.
        id: 0x40000000 | (id & 0x3FFFFFFF),
        title: t.t('reminders.appointmentTitle'),
        body: '${t.t('appointments.$_type')}'
            '${_note.text.trim().isEmpty ? '' : ' · ${_note.text.trim()}'}',
        when: when,
        t: t,
      );
    }

    ref.read(backupSyncProvider).queueBackup(patientId);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return AppScreen(
      children: [
        AppHeader(title: t.t('appointments.add')),

        ChipSelect<String>(
          label: t.t('appointments.title'),
          value: _type,
          options: [
            ChipOption(value: 'revisit', label: t.t('appointments.revisit')),
            ChipOption(value: 'refill', label: t.t('appointments.refill')),
          ],
          onChanged: (v) => setState(() => _type = v),
        ),

        DateField(
          label: t.t('appointments.date'),
          value: _date,
          minimumDate: DateTime.now().subtract(const Duration(days: 1)),
          hint: _error,
          onChanged: (v) => setState(() => _date = v),
        ),

        TimeField(
          label: t.t('medication.times'),
          value: _time,
          onChanged: (v) => setState(() => _time = v),
        ),

        AppInput(
          controller: _note,
          label: t.t('prescriptions.notes'),
          maxLines: 2,
        ),

        AppButton(
          label: t.t('common.save'),
          size: ButtonSize.lg,
          icon: Icons.check,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
