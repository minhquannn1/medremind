import 'package:intl/intl.dart';

/// Date helpers. Ported from `src/lib/date.ts` (dayjs → Dart DateTime + intl).
///
/// The database stores ISO strings, so every helper here takes/returns the
/// same string shapes the RN app used.

String nowIso() => DateTime.now().toUtc().toIso8601String();

String todayDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Normalises an "HH:mm" string. Invalid input is returned unchanged so a bad
/// row never crashes a list render.
String formatTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hhmm;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return DateFormat('dd/MM/yyyy').format(d.toLocal());
}

String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
}

int? ageFromDob(String? dob) {
  if (dob == null || dob.isEmpty) return null;
  final birth = DateTime.tryParse(dob);
  if (birth == null) return null;
  final now = DateTime.now();
  var age = now.year - birth.year;
  final hadBirthday =
      now.month > birth.month || (now.month == birth.month && now.day >= birth.day);
  if (!hadBirthday) age -= 1;
  return age < 0 ? null : age;
}

/// Build a DateTime for a given date + "HH:mm" time string.
DateTime dateAtTime(DateTime date, String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  return DateTime(date.year, date.month, date.day, h, m);
}

enum PartOfDay { morning, noon, evening, night }

/// Bucket an "HH:mm" time into a part-of-day key.
PartOfDay partOfDay(String hhmm) {
  final h = int.tryParse(hhmm.split(':').first) ?? 0;
  if (h < 11) return PartOfDay.morning;
  if (h < 14) return PartOfDay.noon;
  if (h < 18) return PartOfDay.evening;
  return PartOfDay.night;
}
