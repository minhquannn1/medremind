import 'package:medremind/data/repositories/prescriptions_repository.dart';
import 'package:medremind/data/services/ai_scanner_service.dart';

/// Editable medication rows used by the new-prescription screen.
/// Ported from `src/features/prescription/draft.ts`.
class MedicationDraft {
  MedicationDraft({
    required this.key,
    this.name = '',
    this.form = 'tablet',
    this.dosage = '',
    this.relationToMeal = 'anytime',
    this.takeWith = '',
    this.durationDays,
    this.startDate,
    this.quantityTotal,
    this.notes = '',
    this.explanation,
    List<String>? times,
  }) : times = times ?? ['08:00'];

  final String key;
  String name;
  String form;
  String dosage;
  String relationToMeal;
  String takeWith;
  int? durationDays;
  String? startDate;
  double? quantityTotal;
  String notes;
  String? explanation;
  List<String> times;

  static int _seq = 0;

  factory MedicationDraft.empty() =>
      MedicationDraft(key: 'draft-${_seq++}');

  /// Maps one AI-scanned medication into an editable row. Times fall back to
  /// a sensible spread when the prescription only says "N times a day".
  factory MedicationDraft.fromScan(ScannedMedication m) {
    var times = m.times.where((t) => t.trim().isNotEmpty).toList();
    if (times.isEmpty) {
      times = switch (m.frequencyPerDay ?? 1) {
        2 => ['08:00', '20:00'],
        3 => ['08:00', '13:00', '20:00'],
        4 => ['07:00', '12:00', '17:00', '22:00'],
        _ => ['08:00'],
      };
    }
    return MedicationDraft(
      key: 'draft-${_seq++}',
      name: m.name,
      form: m.form ?? 'tablet',
      dosage: m.dosage ?? '',
      relationToMeal: m.relationToMeal ?? 'anytime',
      takeWith: m.takeWith ?? '',
      durationDays: m.durationDays,
      quantityTotal: m.quantityTotal,
      notes: m.notes ?? '',
      explanation: m.uses,
      times: times,
    );
  }

  MedicationInput toInput() => MedicationInput(
        name: name.trim(),
        form: form,
        dosage: dosage.trim().isEmpty ? null : dosage.trim(),
        relationToMeal: relationToMeal,
        takeWith: takeWith.trim().isEmpty ? null : takeWith.trim(),
        durationDays: durationDays,
        startDate: startDate,
        quantityTotal: quantityTotal,
        notes: notes.trim().isEmpty ? null : notes.trim(),
        explanation: explanation,
        explanationLang: explanation == null ? null : 'vi',
        times: times
            .map((t) => MedicationTimeInput(time: t))
            .toList(growable: false),
      );
}
