import 'package:flutter/material.dart';

/// Design tokens — "soft clinical" direction.
/// Calm, trustworthy teal primary with warm accents, generous rhythm,
/// soft depth. Single source of truth for color / spacing / type / radius.
///
/// Ported 1:1 from the React Native `src/theme/tokens.ts`.
class Palette {
  // Brand — teal conveys health, calm, trust
  static const teal900 = Color(0xFF0A4F4E);
  static const teal700 = Color(0xFF0E7C7B);
  static const teal500 = Color(0xFF16A6A4);
  static const teal300 = Color(0xFF7CD0CE);
  static const teal100 = Color(0xFFD6F0EF);
  static const teal50 = Color(0xFFEEF8F8);

  // Warm accent — encouragement, highlights
  static const coral600 = Color(0xFFE8674C);
  static const coral400 = Color(0xFFF2937E);
  static const coral100 = Color(0xFFFCE3DC);

  // Amber — refill / attention
  static const amber600 = Color(0xFFD98A0B);
  static const amber100 = Color(0xFFFBEFD3);

  // Status
  static const green600 = Color(0xFF2E9E5B);
  static const green100 = Color(0xFFD9F2E3);
  static const red600 = Color(0xFFD64545);
  static const red100 = Color(0xFFF8DCDC);

  // Neutrals (warm-tinted grays)
  static const ink900 = Color(0xFF16201F);
  static const ink700 = Color(0xFF35413F);
  static const ink500 = Color(0xFF5C6967);
  static const ink400 = Color(0xFF8A9694);
  static const ink300 = Color(0xFFB9C2C0);
  static const ink200 = Color(0xFFDCE3E1);
  static const ink100 = Color(0xFFEDF1F0);
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF4F7F6);
  static const white = Color(0xFFFFFFFF);
}

class AppColors {
  static const primary = Palette.teal700;
  static const primaryDark = Palette.teal900;
  static const primaryBright = Palette.teal500;
  static const primarySoft = Palette.teal100;
  static const primaryFaint = Palette.teal50;

  static const accent = Palette.coral600;
  static const accentSoft = Palette.coral100;

  static const warn = Palette.amber600;
  static const warnSoft = Palette.amber100;

  static const success = Palette.green600;
  static const successSoft = Palette.green100;
  static const danger = Palette.red600;
  static const dangerSoft = Palette.red100;

  static const text = Palette.ink900;
  static const textMuted = Palette.ink500;
  static const textFaint = Palette.ink400;
  static const textInverse = Palette.white;

  static const border = Palette.ink200;
  static const borderStrong = Palette.ink300;

  static const surface = Palette.surface;
  static const canvas = Palette.canvas;
  static const overlay = Color(0x73102019); // rgba(16, 32, 31, 0.45)
}

class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double xxxxl = 64;
}

class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double xl = 28;
  static const double pill = 999;
}

class FontSizes {
  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  static const double xxxl = 34;
  static const double display = 44;
}

class FontWeights {
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
  static const bold = FontWeight.w700;
}

class LineHeights {
  static const double tight = 1.15;
  static const double snug = 1.3;
  static const double normal = 1.5;
  static const double relaxed = 1.65;
}

class Shadows {
  /// Soft, low-spread elevation for clinical calm.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x140A4F4E), // teal900 @ 8%
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x240A4F4E), // teal900 @ 14%
      offset: Offset(0, 10),
      blurRadius: 24,
    ),
  ];
}
