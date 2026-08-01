import 'package:flutter/foundation.dart';

import 'package:medremind/data/repositories/doses_repository.dart';

/// The 30-day dose log.
class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({
    required this.patientId,
    this.doses = const DosesRepository(),
    this.days = 30,
  });

  final int? patientId;
  final DosesRepository doses;
  final int days;

  List<HistoryDay> _history = const [];
  List<HistoryDay> get history => List.unmodifiable(_history);

  bool _loading = true;
  bool get loading => _loading;

  bool _disposed = false;

  /// Adherence for a day as 0..1, or null when nothing was due — the view
  /// draws that as neutral rather than as a failure.
  double? ratioFor(HistoryDay day) =>
      day.total == 0 ? null : day.taken / day.total;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    final id = patientId;
    if (id == null) {
      _loading = false;
      if (!_disposed) notifyListeners();
      return;
    }

    _history = await doses.getDoseHistory(id, days: days);
    _loading = false;
    if (!_disposed) notifyListeners();
  }
}
