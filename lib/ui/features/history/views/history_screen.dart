import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

/// 30-day dose log grouped by day. Ported from `app/history.tsx`.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<HistoryDay> _days = const [];
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
    final days =
        await const DosesRepository().getDoseHistory(patientId, days: 30);
    if (!mounted) return;
    setState(() {
      _days = days;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return AppScreen(
      onRefresh: _load,
      children: [
        AppHeader(title: t.t('history.title')),
        AppText(t.t('history.subtitle'), color: TextColorKey.textMuted),
        const SizedBox(height: Spacing.lg),

        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_days.isEmpty)
          EmptyState(
            icon: Icons.history,
            title: t.t('history.empty'),
            body: t.t('history.emptyBody'),
          )
        else
          ..._days.map((day) {
            final ratio = day.total == 0 ? null : day.taken / day.total;
            return Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(day.date, variant: TextVariant.bodyStrong),
                        AppBadge(
                          label: '${day.taken}/${day.total}',
                          tone: ratio == null
                              ? BadgeTone.neutral
                              : ratio >= 0.8
                                  ? BadgeTone.success
                                  : ratio >= 0.5
                                      ? BadgeTone.warn
                                      : BadgeTone.danger,
                        ),
                      ],
                    ),
                    const AppDivider(spaced: false),
                    const SizedBox(height: Spacing.sm),
                    ...day.doses.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              AppText(d.time,
                                  variant: TextVariant.caption,
                                  color: TextColorKey.textMuted),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: AppText(d.medicationName,
                                    variant: TextVariant.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              AppText(
                                switch (d.status) {
                                  DoseStatus.taken => t.t('dose.taken'),
                                  DoseStatus.skipped => t.t('dose.skipped'),
                                  DoseStatus.missed => t.t('dose.missed'),
                                  DoseStatus.pending => t.t('dose.pending'),
                                },
                                variant: TextVariant.caption,
                                color: d.status == DoseStatus.taken
                                    ? TextColorKey.success
                                    : TextColorKey.textFaint,
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
