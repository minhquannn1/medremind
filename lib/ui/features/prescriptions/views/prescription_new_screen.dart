import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_input.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/fields.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/features/prescriptions/view_models/prescription_form_view_model.dart';
import 'package:medremind/domain/models/medication_draft.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

/// Create a prescription, optionally pre-filled from an AI scan.
/// Ported from `app/prescription/new.tsx`.
class PrescriptionNewScreen extends ConsumerStatefulWidget {
  const PrescriptionNewScreen({
    super.key,
    this.prefillMedications,
    this.prefillDoctor,
    this.prefillClinic,
    this.prefillIssuedDate,
    this.rawText,
  });

  final List<MedicationDraft>? prefillMedications;
  final String? prefillDoctor;
  final String? prefillClinic;
  final String? prefillIssuedDate;
  final String? rawText;

  @override
  ConsumerState<PrescriptionNewScreen> createState() =>
      _PrescriptionNewScreenState();
}

class _PrescriptionNewScreenState
    extends ConsumerState<PrescriptionNewScreen> {
  final _doctor = TextEditingController();
  final _clinic = TextEditingController();
  final _notes = TextEditingController();

  late final PrescriptionFormViewModel _vm = PrescriptionFormViewModel(
    patientId: ref.read(appStateProvider).activePatientId,
    initialDrafts: widget.prefillMedications,
  );

  bool get _fromScan =>
      (widget.prefillMedications?.isNotEmpty ?? false) ||
      (widget.rawText?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _doctor.text = widget.prefillDoctor ?? '';
    _clinic.text = widget.prefillClinic ?? '';
    _vm.issuedDate = widget.prefillIssuedDate;
  }

  @override
  void dispose() {
    _doctor.dispose();
    _clinic.dispose();
    _notes.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = ref.read(translationsProvider);
    final id = await _vm.save(
      doctorName: _doctor.text,
      clinic: _clinic.text,
      notes: _notes.text,
    );

    if (!mounted) return;
    if (id == null) {
      final e = _vm.error;
      if (e != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(t.t(e.messageKey, params: e.params)),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ));
      }
      return;
    }

    // New doses need reminders, and the cloud copy needs refreshing.
    final patientId = ref.read(appStateProvider).activePatientId;
    final scheduler = ref.read(notificationSchedulerProvider);
    final granted = await scheduler.requestPermission();
    if (granted && patientId != null) {
      await scheduler.syncReminders(patientId, t);
    }
    if (patientId != null) ref.read(backupSyncProvider).queueBackup(patientId);

    if (!mounted) return;
    if (!granted) {
      // Saved, but alerts will not fire — say so rather than letting the user
      // assume they are covered.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.t('permissions.notificationsBody')),
        duration: const Duration(seconds: 6),
      ));
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _build(t),
    );
  }

  Widget _build(Translations t) {
    return AppScreen(
      children: [
        AppHeader(title: t.t('prescriptions.new')),

        // AI output is reference-only (App Review guideline 1.4.1).
        if (_fromScan)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: AppColors.textMuted),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: AppText(t.t('scan.disclaimer'),
                      variant: TextVariant.caption,
                      color: TextColorKey.textMuted),
                ),
              ],
            ),
          ),

        AppCard(
          child: Column(
            children: [
              AppInput(
                controller: _doctor,
                label: t.t('prescriptions.doctor'),
                icon: Icons.person_outline,
              ),
              AppInput(
                controller: _clinic,
                label: t.t('prescriptions.clinic'),
                icon: Icons.business_outlined,
              ),
              DateField(
                label: t.t('prescriptions.issuedDate'),
                value: _vm.issuedDate,
                maximumDate: DateTime.now(),
                onChanged: _vm.setIssuedDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        if (widget.rawText != null && widget.rawText!.isNotEmpty) ...[
          AppCard(
            tone: CardTone.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(t.t('scan.detectedText'),
                    variant: TextVariant.caption,
                    color: TextColorKey.primary),
                const SizedBox(height: Spacing.xs),
                SelectableText(widget.rawText!),
                const SizedBox(height: Spacing.xs),
                AppText(t.t('scan.detectedTextHint'),
                    variant: TextVariant.caption,
                    color: TextColorKey.textFaint),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],

        SectionHeader(title: t.t('prescriptions.medications')),
        ..._vm.drafts.asMap().entries.map((e) => _MedicationEditor(
              key: ValueKey(e.value.key),
              draft: e.value,
              index: e.key,
              nameError:
                  _vm.isIncomplete(e.value) ? t.t('common.required') : null,
              removable: _vm.drafts.length > 1,
              onRemove: () => _vm.removeDraft(e.value),
              onChanged: () => setState(() {}),
            )),

        AppButton(
          label: t.t('prescriptions.addMedication'),
          variant: ButtonVariant.ghost,
          icon: Icons.add,
          onPressed: _vm.addDraft,
        ),
        const SizedBox(height: Spacing.lg),

        AppInput(
          controller: _notes,
          label: t.t('prescriptions.notes'),
          maxLines: 3,
        ),

        AppButton(
          label: t.t('prescriptions.savePrescription'),
          size: ButtonSize.lg,
          icon: Icons.check,
          loading: _vm.saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _MedicationEditor extends ConsumerStatefulWidget {
  const _MedicationEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.nameError,
    required this.removable,
    required this.onRemove,
    required this.onChanged,
  });

  final MedicationDraft draft;
  final int index;
  final String? nameError;
  final bool removable;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  ConsumerState<_MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends ConsumerState<_MedicationEditor> {
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _duration;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.name);
    _dosage = TextEditingController(text: widget.draft.dosage);
    _duration = TextEditingController(
        text: widget.draft.durationDays?.toString() ?? '');
    _quantity = TextEditingController(
        text: widget.draft.quantityTotal?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _duration.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final d = widget.draft;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText('${t.t('medication.name')} ${widget.index + 1}',
                      variant: TextVariant.label,
                      color: TextColorKey.textMuted),
                ),
                if (widget.removable)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.danger, size: 20),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            AppInput(
              controller: _name,
              placeholder: t.t('medication.namePlaceholder'),
              error: widget.nameError,
              onChanged: (v) {
                d.name = v;
                widget.onChanged();
              },
            ),
            AppInput(
              controller: _dosage,
              label: t.t('medication.dosage'),
              placeholder: t.t('medication.dosagePlaceholder'),
              onChanged: (v) => d.dosage = v,
            ),
            ChipSelect<String>(
              label: t.t('medication.form'),
              value: d.form,
              options: [
                for (final f in const [
                  'tablet',
                  'capsule',
                  'syrup',
                  'drops',
                  'injection',
                  'cream',
                  'other'
                ])
                  ChipOption(value: f, label: t.t('medication.forms.$f')),
              ],
              onChanged: (v) => setState(() => d.form = v),
            ),
            ChipSelect<String>(
              label: t.t('medication.relationToMeal'),
              value: d.relationToMeal,
              options: [
                ChipOption(value: 'before', label: t.t('dose.beforeMeal')),
                ChipOption(value: 'after', label: t.t('dose.afterMeal')),
                ChipOption(value: 'with', label: t.t('dose.withMeal')),
                ChipOption(value: 'anytime', label: t.t('dose.anytime')),
              ],
              onChanged: (v) => setState(() => d.relationToMeal = v),
            ),

            AppText(t.t('medication.times'),
                variant: TextVariant.label, color: TextColorKey.textMuted),
            const SizedBox(height: Spacing.sm),
            ...d.times.asMap().entries.map((e) => Row(
                  children: [
                    Expanded(
                      child: TimeField(
                        value: e.value,
                        title: t.t('medication.times'),
                        presetLabels: {
                          'schedule.morning': t.t('schedule.morning'),
                          'schedule.noon': t.t('schedule.noon'),
                          'schedule.evening': t.t('schedule.evening'),
                          'schedule.night': t.t('schedule.night'),
                        },
                        doneLabel: t.t('common.done'),
                        cancelLabel: t.t('common.cancel'),
                        onChanged: (v) =>
                            setState(() => d.times[e.key] = v),
                      ),
                    ),
                    if (d.times.length > 1)
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: AppColors.textFaint),
                        onPressed: () =>
                            setState(() => d.times.removeAt(e.key)),
                      ),
                  ],
                )),
            AppButton(
              label: t.t('medication.addTime'),
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              icon: Icons.add,
              fullWidth: false,
              onPressed: () => setState(() => d.times.add('12:00')),
            ),
            const SizedBox(height: Spacing.lg),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppInput(
                    controller: _duration,
                    label: t.t('medication.duration'),
                    keyboardType: TextInputType.number,
                    suffix: t.t('common.units.day'),
                    onChanged: (v) => d.durationDays = int.tryParse(v),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: AppInput(
                    controller: _quantity,
                    label: t.t('medication.quantity'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => d.quantityTotal = double.tryParse(v),
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
