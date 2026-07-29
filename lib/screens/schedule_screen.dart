import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_card.dart';
import '../components/app_text.dart';
import '../components/layout.dart';
import '../db/repositories/doses_repository.dart';
import '../lib_date.dart';
import '../store/app_state.dart';
import 'appointment_new_screen.dart';
import '../theme/tokens.dart';

/// Daily intake schedule grouped by part of day.
/// Ported from `app/(tabs)/schedule.tsx`.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  static const _doses = DosesRepository();

  List<TodayDose> _items = const [];
  bool _loading = true;

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
    final items = await _doses.getDosesForDay(patientId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    if (_loading) {
      return const AppScreen(
          children: [Center(child: CircularProgressIndicator())]);
    }

    final groups = <PartOfDay, List<TodayDose>>{};
    for (final d in _items) {
      groups.putIfAbsent(partOfDay(d.time), () => []).add(d);
    }

    const order = [
      PartOfDay.morning,
      PartOfDay.noon,
      PartOfDay.evening,
      PartOfDay.night,
    ];

    return AppScreen(
      onRefresh: _load,
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
                if (mounted) _load();
              },
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        if (_items.isEmpty)
          EmptyState(
            icon: Icons.schedule_outlined,
            title: t.t('schedule.noSchedule'),
            body: t.t('home.noDosesTodayBody'),
          )
        else
          ...order.where((p) => groups.containsKey(p)).expand((part) => [
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
