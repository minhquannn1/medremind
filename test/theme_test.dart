import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medremind/ui/core/theme/app_theme.dart';
import 'package:medremind/ui/core/theme/tokens.dart';

/// These lock in the settings that stop Material 3 from reading as "Android".
/// Each one has a visible symptom if it regresses, noted in the reason.
void main() {
  final theme = AppTheme.light;

  group('flattened Material surfaces', () {
    test('no surface tint anywhere', () {
      expect(theme.colorScheme.surfaceTint, Colors.transparent,
          reason: 'M3 tints raised surfaces a different shade of the seed');
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.navigationBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
    });

    test('the app bar does not tint as content scrolls under it', () {
      expect(theme.appBarTheme.scrolledUnderElevation, 0,
          reason: 'the most recognisably Android motion in the app');
      expect(theme.appBarTheme.elevation, 0);
    });

    test('nothing is elevated', () {
      expect(theme.navigationBarTheme.elevation, 0);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
    });
  });

  group('no ink ripples', () {
    test('splash and highlight are suppressed', () {
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.splashColor, Colors.transparent);
      expect(theme.highlightColor, Colors.transparent);
    });
  });

  group('page transitions', () {
    test('iOS keeps Cupertino, which is what carries swipe-back', () {
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
        reason: 'a custom builder silently removes the edge-swipe-back '
            'gesture, so iOS users lose the way they normally go back',
      );
    });

    test('Android drops the zoom transition', () {
      final android =
          theme.pageTransitionsTheme.builders[TargetPlatform.android];
      expect(android, isNotNull);
      expect(android, isNot(isA<ZoomPageTransitionsBuilder>()),
          reason: 'zoom is the Android default and reads as Android');
      expect(android, isA<FadeForwardsPageTransitionsBuilder>());
    });
  });

  group('token-driven, not Material defaults', () {
    RoundedRectangleBorder asRounded(ShapeBorder? shape) =>
        shape! as RoundedRectangleBorder;

    test('corner radii come from Radii', () {
      expect(
        asRounded(theme.cardTheme.shape).borderRadius,
        BorderRadius.circular(Radii.lg),
      );
      expect(
        asRounded(theme.dialogTheme.shape).borderRadius,
        BorderRadius.circular(Radii.lg),
      );
      expect(
        asRounded(theme.bottomSheetTheme.shape).borderRadius,
        BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      );
    });

    test('colours come from AppColors', () {
      expect(theme.scaffoldBackgroundColor, AppColors.canvas);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.appBarTheme.backgroundColor, AppColors.canvas);
      expect(theme.navigationBarTheme.backgroundColor, AppColors.surface);
      expect(theme.navigationBarTheme.indicatorColor, AppColors.primarySoft);
      expect(theme.dividerTheme.color, AppColors.border);
    });

    test('the selected tab label uses the primary colour', () {
      final style = theme.navigationBarTheme.labelTextStyle
          ?.resolve({WidgetState.selected});
      expect(style?.color, AppColors.primary);

      final unselected =
          theme.navigationBarTheme.labelTextStyle?.resolve(<WidgetState>{});
      expect(unselected?.color, AppColors.textMuted);
    });
  });
}
