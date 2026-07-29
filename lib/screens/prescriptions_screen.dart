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
import 'prescription_detail_screen.dart';
import 'prescription_new_screen.dart';
import 'scan_screen.dart';
import '../theme/tokens.dart';

/// Prescription list. Ported from `app/(tabs)/prescriptions.tsx`.
class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() =>
      _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  static const _repo = PrescriptionsRepository();

  List<Prescription> _items = const [];
  final Map<int, int> _medCounts = {};
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
    final items = await _repo.listPrescriptions(patientId);
    final counts = <int, int>{};
    for (final p in items) {
      counts[p.id] = (await _repo.listMedications(p.id)).length;
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _medCounts
        ..clear()
        ..addAll(counts);
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

    return AppScreen(
      onRefresh: _load,
      children: [
        AppText(t.t('prescriptions.title'), variant: TextVariant.title),
        const SizedBox(height: Spacing.lg),

        if (_items.isEmpty)
          EmptyState(
            icon: Icons.description_outlined,
            title: t.t('prescriptions.empty'),
            body: t.t('prescriptions.emptyBody'),
          )
        else
          ..._items.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: AppCard(
                  onPress: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          PrescriptionDetailScreen(prescriptionId: p.id),
                    ));
                    if (mounted) _load();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              [p.doctorName, p.clinic]
                                      .where((s) => s != null && s.isNotEmpty)
                                      .join(' · ')
                                      .isEmpty
                                  ? t.t('prescriptions.new')
                                  : [p.doctorName, p.clinic]
                                      .where((s) => s != null && s.isNotEmpty)
                                      .join(' · '),
                              variant: TextVariant.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      const SizedBox(height: Spacing.xs),
                      AppText(
                        [
                          if (p.issuedDate != null && p.issuedDate!.isNotEmpty)
                            formatDate(p.issuedDate),
                          t.t('prescriptions.medicineCount',
                              params: {'count': _medCounts[p.id] ?? 0}),
                        ].join(' · '),
                        variant: TextVariant.caption,
                        color: TextColorKey.textMuted,
                      ),
                    ],
                  ),
                ),
              )),

        const SizedBox(height: Spacing.lg),
        AppButton(
          label: t.t('prescriptions.scan'),
          icon: Icons.document_scanner_outlined,
          size: ButtonSize.lg,
          onPressed: () async {
            await Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ScanScreen()));
            if (mounted) _load();
          },
        ),
        const SizedBox(height: Spacing.md),
        AppButton(
          label: t.t('prescriptions.addManual'),
          icon: Icons.add,
          variant: ButtonVariant.secondary,
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PrescriptionNewScreen()));
            if (mounted) _load();
          },
        ),
      ],
    );
  }
}
