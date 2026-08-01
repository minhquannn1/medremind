import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/features/schedule/view_models/schedule_view_model.dart';
import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/features/schedule/views/appointment_new_screen.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

/// Daily intake schedule grouped by part of day.
/// Ported from `app/(tabs)/schedule.tsx`.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late final ScheduleViewModel _vm = ScheduleViewModel(
    patientId: ref.read(appStateProvider).activePatientId,
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

    final groups = _vm.groupedDoses;

    return AppScreen(
      onRefresh: _vm.load,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(t.t('schedule.title'), variant: TextVariant.title),
            IconButton(
              icon: const Icon(Icons.event_available_outlined,
                  color: AppColors.primary),
              tooltip: t.t('appointments.add'),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AppointmentNewScreen()));
                if (mounted) _vm.load();
              },
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        // Appointments were saveable but had nowhere to appear, so a booked
        // revisit simply vanished.
        if (_vm.upcoming.isNotEmpty) ...[
          SectionHeader(title: t.t('appointments.upcoming')),
          ..._vm.upcoming.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: AppCard(
                  tone: CardTone.primary,
                  child: Row(
                    children: [
                      Icon(
                        a.type == 'refill'
                            ? Icons.local_pharmacy_outlined
                            : Icons.event_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(t.t('appointments.${a.type}'),
                                variant: TextVariant.bodyStrong),
                            AppText(
                              [
                                formatDateTime(a.date),
                                if (a.note != null && a.note!.isNotEmpty)
                                  a.note!,
                              ].join(' · '),
                              variant: TextVariant.caption,
                              color: TextColorKey.textMuted,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.textFaint),
                        tooltip: t.t('common.delete'),
                        onPressed: () async {
                          await _vm.deleteAppointment(a.id);
                        },
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: Spacing.lg),
        ],

        if (_vm.isEmpty)
          EmptyState(
            icon: Icons.schedule_outlined,
            title: t.t('schedule.noSchedule'),
            body: t.t('home.noDosesTodayBody'),
          )
        else if (groups.isNotEmpty)
          ...groups.keys.expand((part) => [
                SectionHeader(title: t.t('schedule.${part.name}')),
                ...groups[part]!.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: AppCard(
                        child: Row(
                          children: [
                            AppText(d.time,
                                variant: TextVariant.bodyStrong,
                                color: TextColorKey.primary),
                            const SizedBox(width: Spacing.lg),
                            Expanded(
                              child: AppText(
                                d.medicationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (d.dosage != null && d.dosage!.isNotEmpty)
                              AppText(d.dosage!,
                                  variant: TextVariant.caption,
                                  color: TextColorKey.textMuted),
                          ],
                        ),
                      ),
                    )),
              ]),
      ],
    );
  }
}
