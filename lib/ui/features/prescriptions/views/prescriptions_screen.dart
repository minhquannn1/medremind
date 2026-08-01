import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/ui/features/prescriptions/view_models/prescriptions_view_model.dart';
import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/features/prescriptions/views/prescription_detail_screen.dart';
import 'package:medremind/ui/features/prescriptions/views/prescription_new_screen.dart';
import 'package:medremind/ui/features/prescriptions/views/scan_screen.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

/// Prescription list. Ported from `app/(tabs)/prescriptions.tsx`.
class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() =>
      _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  late final PrescriptionsViewModel _vm = PrescriptionsViewModel(
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

    return AppScreen(
      onRefresh: _vm.load,
      children: [
        AppText(t.t('prescriptions.title'), variant: TextVariant.title),
        const SizedBox(height: Spacing.lg),

        if (_vm.items.isEmpty)
          EmptyState(
            icon: Icons.description_outlined,
            title: t.t('prescriptions.empty'),
            body: t.t('prescriptions.emptyBody'),
          )
        else
          ..._vm.items.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: AppCard(
                  onPress: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          PrescriptionDetailScreen(prescriptionId: p.id),
                    ));
                    if (mounted) _vm.load();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              _vm.titleFor(p) ?? t.t('prescriptions.new'),
                              variant: TextVariant.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppBadge(
                            label: _vm.isCompleted(p)
                                ? t.t('prescriptions.completed')
                                : t.t('prescriptions.active'),
                            tone: _vm.isCompleted(p)
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
                              params: {'count': _vm.medicationCount(p.id)}),
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
            if (mounted) _vm.load();
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
            if (mounted) _vm.load();
          },
        ),
      ],
    );
  }
}
