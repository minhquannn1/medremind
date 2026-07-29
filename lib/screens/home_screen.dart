import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_card.dart';
import '../components/app_text.dart';
import '../components/controls.dart';
import '../components/layout.dart';
import '../db/repositories/appointments_repository.dart';
import '../db/repositories/doses_repository.dart';
import '../db/repositories/patients_repository.dart';
import '../db/models.dart';
import '../i18n/app_localizations.dart';
import '../lib_date.dart';
import '../store/app_state.dart';
import '../theme/tokens.dart';

/// Today's doses + adherence. Ported from `app/(tabs)/index.tsx`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _doses = DosesRepository();
  static const _patients = PatientsRepository();
  static const _appointments = AppointmentsRepository();

  List<TodayDose> _today = const [];
  AdherenceStat _adherence = const AdherenceStat(taken: 0, total: 0, ratio: 1);
  Patient? _patient;
  Appointment? _nextAppointment;
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

    final today = await _doses.getDosesForDay(patientId);
    final adherence = await _doses.getAdherence(patientId, days: 7);
    final patient = await _patients.getPatient(patientId);
    final upcoming = await _appointments.listUpcomingAppointments(patientId);

    if (!mounted) return;
    setState(() {
      _today = today;
      _adherence = adherence;
      _patient = patient;
      _nextAppointment = upcoming.isEmpty ? null : upcoming.first;
      _loading = false;
    });
  }

  Future<void> _mark(TodayDose dose, DoseStatus status) async {
    await _doses.markDose(dose.id, status);
    final patientId = ref.read(appStateProvider).activePatientId;
    if (patientId != null) {
      ref.read(backupSyncProvider).queueBackup(patientId);
    }
    await _load();
  }

  String _greeting(Translations t) {
    final hour = DateTime.now().hour;
    if (hour < 11) return t.t('home.greetingMorning');
    if (hour < 18) return t.t('home.greetingAfternoon');
    return t.t('home.greetingEvening');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    if (_loading) {
      return const AppScreen(
        children: [Center(child: CircularProgressIndicator())],
      );
    }

    final pending = _today.where((d) => d.status == DoseStatus.pending).toList();
    final ratioLabel = _adherence.total == 0
        ? '—'
        : '${(_adherence.ratio * 100).round()}%';

    return AppScreen(
      onRefresh: _load,
      children: [
        AppText(_greeting(t), color: TextColorKey.textMuted),
        AppText(
          _patient?.fullName ?? t.t('common.appName'),
          variant: TextVariant.title,
        ),
        const SizedBox(height: Spacing.xl),

        // Adherence
        AppCard(
          child: Column(
            children: [
              AppText(t.t('home.adherenceTitle'),
                  variant: TextVariant.label, color: TextColorKey.textMuted),
              const SizedBox(height: Spacing.lg),
              ProgressRing(
                progress: _adherence.ratio,
                label: ratioLabel,
                // Only the short count sits inside the ring; the wording goes
                // below, where it has the full card width to breathe.
                caption: '${_adherence.taken}/${_adherence.total}',
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

        if (_nextAppointment != null) ...[
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
                        '${t.t('appointments.${_nextAppointment!.type}')} · '
                        '${formatDateTime(_nextAppointment!.date)}',
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

        if (_today.isEmpty)
          EmptyState(
            icon: Icons.medication_outlined,
            title: t.t('home.noDosesToday'),
            body: t.t('home.noDosesTodayBody'),
          )
        else if (pending.isEmpty)
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
          ..._today.map((dose) => Padding(
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
