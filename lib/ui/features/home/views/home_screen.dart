import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_card.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/components/controls.dart';
import 'package:medremind/ui/core/components/layout.dart';
import 'package:medremind/data/repositories/doses_repository.dart';
import 'package:medremind/ui/features/home/view_models/home_view_model.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/date_format.dart';
import 'package:medremind/ui/core/app_state.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

/// Today's doses + adherence. Ported from `app/(tabs)/index.tsx`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final HomeViewModel _vm = HomeViewModel(
    patientId: ref.read(appStateProvider).activePatientId,
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

  Future<void> _mark(TodayDose dose, DoseStatus status) async {
    await _vm.mark(dose, status);
    ref.read(doseRevisionProvider.notifier).state++;
  }

  String _greetingText(Translations t) => switch (_vm.greeting) {
        GreetingSlot.morning => t.t('home.greetingMorning'),
        GreetingSlot.afternoon => t.t('home.greetingAfternoon'),
        GreetingSlot.evening => t.t('home.greetingEvening'),
      };

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    // Reload when a dose was confirmed elsewhere (e.g. from a notification).
    ref.listen<int>(doseRevisionProvider, (_, _) => _vm.load());

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

    return AppScreen(
      onRefresh: _vm.load,
      children: [
        // The name is blank until the user chooses to add one under Profile,
        // so the greeting carries the heading on its own rather than shouting
        // a brand name at someone who never told us who they are.
        if (_vm.displayName == null)
          AppText(_greetingText(t), variant: TextVariant.title)
        else ...[
          AppText(_greetingText(t), color: TextColorKey.textMuted),
          AppText(_vm.displayName!, variant: TextVariant.title),
        ],
        const SizedBox(height: Spacing.xl),

        // First launch only. Replaces the onboarding screen as the place the
        // medical disclaimer is shown (App Review guideline 1.4.1).
        if (_vm.showWelcome) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(t.t('onboarding.welcomeTitle'),
                    variant: TextVariant.subheading),
                const SizedBox(height: Spacing.xs),
                AppText(t.t('onboarding.welcomeBody'),
                    color: TextColorKey.textMuted),
                const SizedBox(height: Spacing.md),
                AppText(t.t('onboarding.disclaimer'),
                    variant: TextVariant.caption,
                    color: TextColorKey.textFaint),
                const SizedBox(height: Spacing.md),
                AppButton(
                  label: t.t('onboarding.welcomeAck'),
                  onPressed: _vm.dismissWelcome,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],

        // Adherence
        AppCard(
          child: Column(
            children: [
              AppText(t.t('home.adherenceTitle'),
                  variant: TextVariant.label, color: TextColorKey.textMuted),
              const SizedBox(height: Spacing.lg),
              ProgressRing(
                progress: _vm.adherence.ratio,
                label: _vm.adherenceLabel,
                // Only the short count sits inside the ring; the wording goes
                // below, where it has the full card width to breathe.
                caption: _vm.adherenceCount,
              ),
              const SizedBox(height: Spacing.sm),
              AppText(t.t('home.adherenceCaption'),
                  variant: TextVariant.caption,
                  color: TextColorKey.textMuted,
                  center: true),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xl),

        if (_vm.nextAppointment != null) ...[
          AppCard(
            tone: CardTone.primary,
            child: Row(
              children: [
                const Icon(Icons.event, color: AppColors.primary),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(t.t('home.upcomingAppointment'),
                          variant: TextVariant.label),
                      AppText(
                        '${t.t('appointments.${_vm.nextAppointment!.type}')} · '
                        '${formatDateTime(_vm.nextAppointment!.date)}',
                        variant: TextVariant.caption,
                        color: TextColorKey.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
        ],

        SectionHeader(title: t.t('home.todayDoses')),

        if (_vm.today.isEmpty)
          EmptyState(
            icon: Icons.medication_outlined,
            title: t.t('home.noDosesToday'),
            body: t.t('home.noDosesTodayBody'),
          )
        else if (_vm.allDone)
          AppCard(
            tone: CardTone.success,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: Spacing.md),
                Expanded(child: AppText(t.t('home.allDone'))),
              ],
            ),
          )
        else
          ..._vm.today.map((dose) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: _DoseCard(
                  dose: dose,
                  t: t,
                  onTake: () => _mark(dose, DoseStatus.taken),
                  onSkip: () => _mark(dose, DoseStatus.skipped),
                ),
              )),
      ],
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.dose,
    required this.t,
    required this.onTake,
    required this.onSkip,
  });

  final TodayDose dose;
  final Translations t;
  final VoidCallback onTake;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final done = dose.status != DoseStatus.pending;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(dose.time,
                  variant: TextVariant.bodyStrong,
                  color: done ? TextColorKey.textFaint : TextColorKey.primary),
            ],
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  dose.medicationName,
                  variant: TextVariant.bodyStrong,
                  color: done ? TextColorKey.textFaint : TextColorKey.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dose.dosage != null && dose.dosage!.isNotEmpty)
                  AppText(dose.dosage!,
                      variant: TextVariant.caption,
                      color: TextColorKey.textMuted),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          if (done)
            AppBadge(
              label: switch (dose.status) {
                DoseStatus.taken => t.t('dose.taken'),
                DoseStatus.skipped => t.t('dose.skipped'),
                DoseStatus.missed => t.t('dose.missed'),
                DoseStatus.pending => t.t('dose.pending'),
              },
              tone: dose.status == DoseStatus.taken
                  ? BadgeTone.success
                  : BadgeTone.neutral,
              icon: dose.status == DoseStatus.taken ? Icons.check : null,
            )
          else
            Row(
              children: [
                IconButton(
                  tooltip: t.t('dose.skip'),
                  icon: const Icon(Icons.close, color: AppColors.textFaint),
                  onPressed: onSkip,
                ),
                IconButton(
                  tooltip: t.t('dose.take'),
                  icon: const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 32),
                  onPressed: onTake,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
