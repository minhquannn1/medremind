import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/fields.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/domain/models/models.dart';
import 'package:medremind/ui/features/prescriptions/view_models/medication_detail_view_model.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

/// One medication: schedule, stock and the AI explanation.
/// Ported from `app/medication/[id].tsx`.
class MedicationDetailScreen extends ConsumerStatefulWidget {
  const MedicationDetailScreen({super.key, required this.medicationId});

  final int medicationId;

  @override
  ConsumerState<MedicationDetailScreen> createState() =>
      _MedicationDetailScreenState();
}

class _MedicationDetailScreenState
    extends ConsumerState<MedicationDetailScreen> {
  late final MedicationDetailViewModel _vm = MedicationDetailViewModel(
    medicationId: widget.medicationId,
    language: ref.read(appStateProvider).language.name,
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

  Future<void> _changeTime(ScheduleTime st, String value) async {
    await _vm.changeTime(st, value);
    final t = ref.read(translationsProvider);
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId != null) {
      // The alarm must move with the schedule, or the reminder still fires at
      // the old hour.
      await ref
          .read(notificationSchedulerProvider)
          .syncReminders(patientId, t);
      ref.read(backupSyncProvider).queueBackup(patientId);
    }
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

    final m = _vm.medication;
    if (m == null) {
      return AppScreen(children: [
        AppHeader(title: t.t('medication.info')),
        AppText(t.t('common.none'), color: TextColorKey.textFaint),
      ]);
    }

    final low = _vm.isLowStock;

    return AppScreen(
      onRefresh: _vm.load,
      children: [
        AppHeader(title: t.t('medication.info')),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(m.name, variant: TextVariant.subheading),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  if (m.form != null)
                    AppBadge(
                        label: t.t('medication.forms.${m.form}'),
                        tone: BadgeTone.primary),
                  if (m.dosage != null && m.dosage!.isNotEmpty)
                    AppBadge(label: m.dosage!),
                  if (m.relationToMeal != null)
                    AppBadge(
                      label: switch (m.relationToMeal) {
                        'before' => t.t('dose.beforeMeal'),
                        'after' => t.t('dose.afterMeal'),
                        'with' => t.t('dose.withMeal'),
                        _ => t.t('dose.anytime'),
                      },
                    ),
                ],
              ),
              if (m.takeWith != null && m.takeWith!.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                AppText('${t.t('dose.takeWith')}: ${m.takeWith}',
                    variant: TextVariant.caption,
                    color: TextColorKey.textMuted),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        if (m.quantityRemaining != null) ...[
          AppCard(
            tone: low ? CardTone.warn : CardTone.surface,
            child: Row(
              children: [
                Icon(low ? Icons.warning_amber_outlined : Icons.inventory_2_outlined,
                    color: low ? AppColors.warn : AppColors.primary, size: 20),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: AppText(low
                      ? t.t('medication.lowStock',
                          params: {'count': m.quantityRemaining!.toStringAsFixed(0)})
                      : '${t.t('medication.quantityRemaining')}: '
                          '${m.quantityRemaining!.toStringAsFixed(0)}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],

        SectionHeader(title: t.t('medication.times')),
        ..._vm.times.map((st) => TimeField(
              value: st.time,
              title: t.t('medication.times'),
              presetLabels: {
                'schedule.morning': t.t('schedule.morning'),
                'schedule.noon': t.t('schedule.noon'),
                'schedule.evening': t.t('schedule.evening'),
                'schedule.night': t.t('schedule.night'),
              },
              doneLabel: t.t('common.done'),
              cancelLabel: t.t('common.cancel'),
              onChanged: (v) => _changeTime(st, v),
            )),
        const SizedBox(height: Spacing.md),

        SectionHeader(title: t.t('medication.whatIsItFor')),
        if (_vm.hasExplanation)
          AppCard(
            tone: CardTone.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(t.t('medication.aiExplanation'),
                    variant: TextVariant.caption,
                    color: TextColorKey.primary),
                const SizedBox(height: Spacing.xs),
                AppText(m.explanation!),
                const SizedBox(height: Spacing.sm),
                AppText(t.t('medication.aiDisclaimer'),
                    variant: TextVariant.caption,
                    color: TextColorKey.textFaint),
              ],
            ),
          )
        else ...[
          AppText(t.t('medication.explainPrompt'),
              color: TextColorKey.textMuted),
          const SizedBox(height: Spacing.md),
          if (_vm.explainFailed) ...[
            AppText(t.t('medication.explainError'), color: TextColorKey.danger,
                variant: TextVariant.caption),
            const SizedBox(height: Spacing.sm),
          ],
          AppButton(
            label: _vm.explaining
                ? t.t('medication.explaining')
                : t.t('medication.explainAction'),
            variant: ButtonVariant.secondary,
            icon: Icons.auto_awesome,
            loading: _vm.explaining,
            onPressed: _vm.explain,
          ),
        ],
      ],
    );
  }
}
