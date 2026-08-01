import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/features/prescriptions/view_models/prescription_detail_view_model.dart';
import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/features/prescriptions/views/medication_detail_screen.dart';

/// One prescription with its medications. Ported from `app/prescription/[id].tsx`.
class PrescriptionDetailScreen extends ConsumerStatefulWidget {
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  final int prescriptionId;

  @override
  ConsumerState<PrescriptionDetailScreen> createState() =>
      _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState
    extends ConsumerState<PrescriptionDetailScreen> {
  late final PrescriptionDetailViewModel _vm = PrescriptionDetailViewModel(
    prescriptionId: widget.prescriptionId,
  );

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final t = ref.read(translationsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('common.delete')),
        content: Text(t.t('common.deleteConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.t('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.t('common.delete'),
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _vm.delete();

    // Reminders referenced the deleted medications — rebuild the schedule.
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId != null) {
      await ref
          .read(notificationSchedulerProvider)
          .syncReminders(patientId, t);
      ref.read(backupSyncProvider).queueBackup(patientId);
    }
    if (mounted) Navigator.of(context).pop(true);
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
    if (_vm.loading) {
      return const AppScreen(
          children: [Center(child: CircularProgressIndicator())]);
    }

    final p = _vm.prescription;
    if (p == null) {
      return AppScreen(children: [
        AppHeader(title: t.t('prescriptions.title')),
        AppText(t.t('common.none'), color: TextColorKey.textFaint),
      ]);
    }

    return AppScreen(
      onRefresh: _vm.load,
      children: [
        AppHeader(title: t.t('prescriptions.title')),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      _vm.title ?? t.t('prescriptions.title'),
                      variant: TextVariant.subheading,
                    ),
                  ),
                  AppBadge(
                    label: _vm.isCompleted
                        ? t.t('prescriptions.completed')
                        : t.t('prescriptions.active'),
                    tone: _vm.isCompleted
                        ? BadgeTone.neutral
                        : BadgeTone.success,
                  ),
                ],
              ),
              if (p.issuedDate != null && p.issuedDate!.isNotEmpty) ...[
                const SizedBox(height: Spacing.xs),
                AppText(
                  '${t.t('prescriptions.issuedDate')}: ${formatDate(p.issuedDate)}',
                  variant: TextVariant.caption,
                  color: TextColorKey.textMuted,
                ),
              ],
              if (p.notes != null && p.notes!.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                AppText(p.notes!,
                    variant: TextVariant.caption,
                    color: TextColorKey.textMuted),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        SectionHeader(title: t.t('prescriptions.medications')),
        ..._vm.medications.map((m) {
          final times = _vm.timesFor(m.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: AppCard(
              onPress: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MedicationDetailScreen(medicationId: m.id),
                ));
                if (mounted) _vm.load();
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(m.name, variant: TextVariant.bodyStrong),
                        const SizedBox(height: 2),
                        AppText(
                          [
                            if (m.dosage != null && m.dosage!.isNotEmpty)
                              m.dosage!,
                            if (times.isNotEmpty) times.join(' · '),
                          ].join(' · '),
                          variant: TextVariant.caption,
                          color: TextColorKey.textMuted,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: Spacing.lg),
        AppButton(
          label: _vm.isCompleted
              ? t.t('prescriptions.active')
              : t.t('prescriptions.completed'),
          variant: ButtonVariant.secondary,
          icon: Icons.check_circle_outline,
          onPressed: _vm.toggleStatus,
        ),
        const SizedBox(height: Spacing.md),
        AppButton(
          label: t.t('common.delete'),
          variant: ButtonVariant.danger,
          icon: Icons.delete_outline,
          onPressed: _delete,
        ),
      ],
    );
  }
}
