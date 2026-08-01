import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/ui/features/dose_confirm/view_models/dose_confirm_view_model.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

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
  late final DoseConfirmViewModel _vm = DoseConfirmViewModel(
    patientId: ref.read(appStateProvider).activePatientId,
    medicationId: widget.medicationId,
    time: widget.time,
    backupSync: ref.read(backupSyncProvider),
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

  Future<void> _mark(DoseStatus status) async {
    final recorded = await _vm.mark(status);
    if (!recorded || !mounted) return;
    // Tell the home tab its figures are stale before returning to it.
    ref.read(doseRevisionProvider.notifier).state++;
    Navigator.of(context).pop();
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
        children: [Center(child: CircularProgressIndicator())],
      );
    }

    final dose = _vm.dose;

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

    final alreadyDone = _vm.alreadyResolved;

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
            loading: _vm.saving,
            onPressed: () => _mark(DoseStatus.taken),
          ),
          const SizedBox(height: Spacing.md),
          AppButton(
            label: t.t('dose.skip'),
            variant: ButtonVariant.ghost,
            disabled: _vm.saving,
            onPressed: () => _mark(DoseStatus.skipped),
          ),
        ],
      ],
    );
  }
}
