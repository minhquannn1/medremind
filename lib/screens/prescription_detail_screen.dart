import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_text.dart';
import '../components/controls.dart';
import '../components/layout.dart';
import '../db/models.dart';
import '../db/repositories/prescriptions_repository.dart';
import '../lib_date.dart';
import '../store/app_state.dart';
import '../theme/tokens.dart';
import 'medication_detail_screen.dart';

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
  static const _repo = PrescriptionsRepository();

  Prescription? _prescription;
  List<Medication> _medications = const [];
  final Map<int, List<ScheduleTime>> _times = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _repo.getPrescription(widget.prescriptionId);
    final meds = await _repo.listMedications(widget.prescriptionId);
    final times = <int, List<ScheduleTime>>{};
    for (final m in meds) {
      times[m.id] = await _repo.listScheduleTimes(m.id);
    }
    if (!mounted) return;
    setState(() {
      _prescription = p;
      _medications = meds;
      _times
        ..clear()
        ..addAll(times);
      _loading = false;
    });
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

    await _repo.deletePrescription(widget.prescriptionId);

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

  Future<void> _toggleStatus() async {
    final p = _prescription;
    if (p == null) return;
    await _repo.updatePrescriptionStatus(
      p.id,
      p.status == 'active' ? 'completed' : 'active',
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    if (_loading) {
      return const AppScreen(
          children: [Center(child: CircularProgressIndicator())]);
    }

    final p = _prescription;
    if (p == null) {
      return AppScreen(children: [
        AppHeader(title: t.t('prescriptions.title')),
        AppText(t.t('common.none'), color: TextColorKey.textFaint),
      ]);
    }

    final title = [p.doctorName, p.clinic]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return AppScreen(
      onRefresh: _load,
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
                      title.isEmpty ? t.t('prescriptions.title') : title,
                      variant: TextVariant.subheading,
                    ),
                  ),
                  AppBadge(
                    label: p.status == 'completed'
                        ? t.t('prescriptions.completed')
                        : t.t('prescriptions.active'),
                    tone: p.status == 'completed'
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
        ..._medications.map((m) {
          final times = (_times[m.id] ?? const <ScheduleTime>[])
              .map((s) => s.time)
              .toList()
            ..sort();
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: AppCard(
              onPress: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MedicationDetailScreen(medicationId: m.id),
                ));
                if (mounted) _load();
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
          label: p.status == 'completed'
              ? t.t('prescriptions.active')
              : t.t('prescriptions.completed'),
          variant: ButtonVariant.secondary,
          icon: Icons.check_circle_outline,
          onPressed: _toggleStatus,
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
