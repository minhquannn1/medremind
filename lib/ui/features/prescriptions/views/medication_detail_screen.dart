import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/fields.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/domain/models/models.dart';
import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/ai_scanner_service.dart';
import 'package:medremind/ui/core/app_state.dart';
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
  static const _repo = PrescriptionsRepository();

  Medication? _medication;
  List<ScheduleTime> _times = const [];
  bool _loading = true;
  bool _explaining = false;
  String? _explainError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await _repo.getMedication(widget.medicationId);
    final times = await _repo.listScheduleTimes(widget.medicationId);
    if (!mounted) return;
    setState(() {
      _medication = m;
      _times = times..sort((a, b) => a.time.compareTo(b.time));
      _loading = false;
    });
  }

  Future<void> _changeTime(ScheduleTime st, String value) async {
    await _repo.updateScheduleTime(st.id, value);
    final t = ref.read(translationsProvider);
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId != null) {
      // The alarm must move with the schedule, or the reminder still fires
      // at the old hour.
      await ref
          .read(notificationSchedulerProvider)
          .syncReminders(patientId, t);
      ref.read(backupSyncProvider).queueBackup(patientId);
    }
    await _load();
  }

  Future<void> _explain() async {
    final m = _medication;
    if (m == null) return;
    final t = ref.read(translationsProvider);
    final lang = ref.read(appStateProvider).language.name;

    setState(() {
      _explaining = true;
      _explainError = null;
    });

    final text =
        await const AiScannerApi().explainMedication(m.name, lang: lang);

    if (!mounted) return;
    if (text == null) {
      setState(() {
        _explaining = false;
        _explainError = t.t('medication.explainError');
      });
      return;
    }

    await _repo.updateMedicationExplanation(m.id, text, lang);
    if (!mounted) return;
    setState(() => _explaining = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    if (_loading) {
      return const AppScreen(
          children: [Center(child: CircularProgressIndicator())]);
    }

    final m = _medication;
    if (m == null) {
      return AppScreen(children: [
        AppHeader(title: t.t('medication.info')),
        AppText(t.t('common.none'), color: TextColorKey.textFaint),
      ]);
    }

    final low = m.quantityRemaining != null &&
        m.quantityTotal != null &&
        m.quantityTotal! > 0 &&
        m.quantityRemaining! <= m.quantityTotal! * 0.2;

    return AppScreen(
      onRefresh: _load,
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
        ..._times.map((st) => TimeField(
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
        if (m.explanation != null && m.explanation!.isNotEmpty)
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
          if (_explainError != null) ...[
            AppText(_explainError!, color: TextColorKey.danger,
                variant: TextVariant.caption),
            const SizedBox(height: Spacing.sm),
          ],
          AppButton(
            label: _explaining
                ? t.t('medication.explaining')
                : t.t('medication.explainAction'),
            variant: ButtonVariant.secondary,
            icon: Icons.auto_awesome,
            loading: _explaining,
            onPressed: _explain,
          ),
        ],
      ],
    );
  }
}
