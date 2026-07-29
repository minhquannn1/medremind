import 'dart:ui' show Locale;

import 'locale_en.dart';
import 'locale_vi.dart';

/// Translation lookup. Ported from `src/i18n/index.ts` (i18next → plain maps).
///
/// The RN app used `t('a.b')` with `{{name}}` interpolation, and screens were
/// written against those exact keys — keeping the same call shape means the
/// ported screens read like the originals.
enum AppLanguage { vi, en }

AppLanguage languageFromCode(String? code) =>
    code == 'en' ? AppLanguage.en : AppLanguage.vi;

String languageCode(AppLanguage lang) => lang.name;

/// Vietnamese is the default: the app's primary audience. Any device locale
/// that is not English falls back to it, matching `detectDeviceLanguage`.
AppLanguage detectDeviceLanguage(Locale locale) =>
    locale.languageCode == 'en' ? AppLanguage.en : AppLanguage.vi;

class Translations {
  const Translations(this.language);

  final AppLanguage language;

  Map<String, String> get _table =>
      language == AppLanguage.en ? localeEn : localeVi;

  /// Looks up [key], substituting `{{name}}` placeholders from [params].
  /// An unknown key returns the key itself so a missing string is obvious in
  /// the UI rather than rendering as blank space.
  String t(String key, {Map<String, Object?>? params}) {
    final raw = _table[key] ?? localeVi[key] ?? key;
    if (params == null || params.isEmpty) return raw;

    var out = raw;
    params.forEach((name, value) {
      out = out.replaceAll('{{$name}}', '${value ?? ''}');
    });
    return out;
  }
}
