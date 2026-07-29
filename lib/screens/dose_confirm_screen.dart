import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_text.dart';
import '../components/layout.dart';
import '../db/repositories/doses_repository.dart';
import '../store/app_state.dart';
import '../theme/tokens.dart';

/// Opened by tapping a dose reminder: confirm the dose in one tap, then land
/// back on the home screen with the adherence figures already updated.
class DoseConfirmScreen extends ConsumerStatefulWidget {
  const DoseConfirmScreen({
    super.key,
    required this.medicationId,
    required this.time,
  });

  final int medicationId;
  final String time; // HH:mm

  @override
  ConsumerState<DoseConfirmScreen> createState() => _DoseConfirmScreenState();
}

class _DoseConfirmScreenState extends ConsumerState<DoseConfirmScreen> {
  static const _doses = DosesRepository();

  TodayDose? _dose;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final today = await _doses.getDosesForDay(patientId);
    TodayDose? match;
    for (final d in today) {
      if (d.medicationId == widget.medicationId && d.time == widget.time) {
        match = d;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _dose = match;
      _loading = false;
    });
  }

  Future<void> _mark(DoseStatus status) async {
    final dose = _dose;
    if (dose == null) return;

    setState(() => _saving = true);
    await _doses.markDose(dose.id, status);

    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId != null) {
      ref.read(backupSyncProvider).queueBackup(patientId);
    }
    // Tell the already-built home screen its figures are stale.
    ref.read(doseRevisionProvider.notifier).state++;

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    if (_loading) {
      return const AppScreen(
        children: [Center(child: CircularProgressIndicator())],
      );
    }

    final dose = _dose;

    // The reminder can outlive its dose — a finished course, or a prescription
    // deleted after the alert was scheduled.
    if (dose == null) {
      return AppScreen(
        children: [
          AppHeader(title: t.t('home.todayDoses')),
          EmptyState(
            icon: Icons.medication_outlined,
            title: t.t('home.noDosesToday'),
            body: t.t('home.noDosesTodayBody'),
          ),
        ],
      );
    }

    final alreadyDone = dose.status != DoseStatus.pending;

    return AppScreen(
      children: [
        AppHeader(title: t.t('home.todayDoses')),
        const SizedBox(height: Spacing.xl),

        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: alreadyDone ? AppColors.successSoft : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              alreadyDone ? Icons.check_circle : Icons.medication_outlined,
              size: 48,
              color: alreadyDone ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: Spacing.xl),

        AppText(dose.time, variant: TextVariant.display,
            color: TextColorKey.primary, center: true),
        const SizedBox(height: Spacing.sm),
        AppText(dose.medicationName,
            variant: TextVariant.heading, center: true),
        if (dose.dosage != null && dose.dosage!.isNotEmpty) ...[
          const SizedBox(height: Spacing.xs),
          AppText(dose.dosage!, color: TextColorKey.textMuted, center: true),
        ],
        if (dose.relationToMeal != null) ...[
          const SizedBox(height: Spacing.xs),
          AppText(
            switch (dose.relationToMeal) {
              'before' => t.t('dose.beforeMeal'),
              'after' => t.t('dose.afterMeal'),
              'with' => t.t('dose.withMeal'),
              _ => t.t('dose.anytime'),
            },
            variant: TextVariant.caption,
            color: TextColorKey.textFaint,
            center: true,
          ),
        ],
        if (dose.takeWith != null && dose.takeWith!.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          AppCard(
            tone: CardTone.warn,
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 20, color: AppColors.warn),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: AppText('${t.t('dose.takeWith')}: ${dose.takeWith}'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Spacing.xxl),

        if (alreadyDone)
          AppCard(
            tone: CardTone.success,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: AppText(
                    dose.status == DoseStatus.taken
                        ? t.t('dose.markedTaken')
                        : t.t('dose.skipped'),
                  ),
                ),
              ],
            ),
          )
        else ...[
          AppButton(
            label: t.t('dose.take'),
            icon: Icons.check,
            size: ButtonSize.lg,
            loading: _saving,
            onPressed: () => _mark(DoseStatus.taken),
          ),
          const SizedBox(height: Spacing.md),
          AppButton(
            label: t.t('dose.skip'),
            variant: ButtonVariant.ghost,
            disabled: _saving,
            onPressed: () => _mark(DoseStatus.skipped),
          ),
        ],
      ],
    );
  }
}
