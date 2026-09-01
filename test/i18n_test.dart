import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/i18n/locale_en.dart';
import 'package:medremind/ui/core/i18n/locale_vi.dart';

void main() {
  group('locale coverage', () {
    test('English and Vietnamese define exactly the same keys', () {
      final viKeys = localeVi.keys.toSet();
      final enKeys = localeEn.keys.toSet();

      expect(
        viKeys.difference(enKeys),
        isEmpty,
        reason: 'these keys exist in Vietnamese but are missing in English',
      );
      expect(
        enKeys.difference(viKeys),
        isEmpty,
        reason: 'these keys exist in English but are missing in Vietnamese',
      );
    });

    test('no string is left empty', () {
      for (final entry in localeVi.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: 'vi: ${entry.key}');
      }
      for (final entry in localeEn.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: 'en: ${entry.key}');
      }
    });

    test('placeholders match between the two languages', () {
      final placeholder = RegExp(r'\{\{(\w+)\}\}');
      for (final key in localeVi.keys) {
        final viNames =
            placeholder.allMatches(localeVi[key]!).map((m) => m[1]).toSet();
        final enNames =
            placeholder.allMatches(localeEn[key]!).map((m) => m[1]).toSet();
        expect(viNames, enNames,
            reason: 'placeholder mismatch for "$key" — one language would '
                'render a literal {{...}} to the user');
      }
    });

    test('covers every section the RN app had', () {
      const sections = [
        'common',
        'tabs',
        'auth',
        'welcome',
        'home',
        'dose',
        'prescriptions',
        'medication',
        'schedule',
        'profile',
        'appointments',
        'lifestyle',
        'history',
        'doctor',
        'reminders',
        'permissions',
        'scan',
        'settings',
      ];
      for (final s in sections) {
        expect(
          localeVi.keys.any((k) => k.startsWith('$s.')),
          isTrue,
          reason: 'missing whole section: $s',
        );
      }
    });
  });

  group('Translations.t', () {
    test('returns the string for the active language', () {
      expect(const Translations(AppLanguage.vi).t('common.save'), 'Lưu');
      expect(const Translations(AppLanguage.en).t('common.save'), 'Save');
    });

    test('substitutes named placeholders', () {
      final vi = const Translations(AppLanguage.vi)
          .t('reminders.doseBody', params: {'medication': 'Panadol', 'dosage': '1 viên'});
      expect(vi, 'Panadol — 1 viên');

      final en = const Translations(AppLanguage.en)
          .t('medication.lowStock', params: {'count': 3});
      expect(en, 'Running low (3 left)');
    });

    test('leaves no placeholder behind when a param is supplied', () {
      final s = const Translations(AppLanguage.vi)
          .t('prescriptions.medicineCount', params: {'count': 4});
      expect(s.contains('{{'), isFalse);
      expect(s, '4 loại thuốc');
    });

    test('an unknown key returns the key so the gap is visible', () {
      expect(const Translations(AppLanguage.vi).t('nope.missing'),
          'nope.missing');
    });

    test('falls back to Vietnamese rather than showing a raw key', () {
      // Every key exists in both today; the fallback still must not crash.
      expect(const Translations(AppLanguage.en).t('common.appName'), 'Medoly');
    });
  });

  group('language detection', () {
    test('English device locale selects English', () {
      expect(detectDeviceLanguage(const Locale('en', 'US')), AppLanguage.en);
    });

    test('Vietnamese and anything else default to Vietnamese', () {
      expect(detectDeviceLanguage(const Locale('vi', 'VN')), AppLanguage.vi);
      expect(detectDeviceLanguage(const Locale('fr', 'FR')), AppLanguage.vi);
    });

    test('round-trips through the stored setting code', () {
      expect(languageFromCode('en'), AppLanguage.en);
      expect(languageFromCode('vi'), AppLanguage.vi);
      expect(languageFromCode(null), AppLanguage.vi);
      expect(languageCode(AppLanguage.en), 'en');
      expect(languageCode(AppLanguage.vi), 'vi');
    });
  });
}
