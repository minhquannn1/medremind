// Only for CupertinoPageTransitionsBuilder — no Cupertino *widgets* are used,
// so the primitives in lib/components stay single-platform.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// The app's ThemeData, built entirely from `tokens.dart`.
///
/// Material 3's defaults are what read as "Android" regardless of the OS the
/// app runs on: tonal elevation, the surface tint that washes over a surface
/// as content scrolls under it, ink ripples, the zoom page transition and
/// M3's own corner radii. Each of those is flattened here so the "soft
/// clinical" design system shows through instead of Material's, on both
/// platforms — without Cupertino widgets or any Platform branching, which
/// would double the primitives to maintain.
///
/// Page transitions are the one thing left per-platform, using Flutter's own
/// builders. That is not a branch in the design system: PageTransitionsTheme
/// is keyed by platform by design, and iOS's builder is what supplies the
/// edge-swipe-back gesture.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
    ).copyWith(
      // M3 derives elevation overlays from this; matching the surface keeps
      // raised widgets from turning a different shade of teal.
      surfaceTint: Colors.transparent,
      error: AppColors.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,

      // Ripples are a Material signature. Cards and buttons carry their own
      // press feedback (scale + opacity) in lib/components.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,

      // Flutter's own builders, one per platform. iOS keeps Cupertino's,
      // because it carries the edge-swipe-back gesture as well as the slide —
      // a custom transition silently removes swiping back, which iOS users
      // reach for before they look for the button. Android gets M3's current
      // fade-forwards instead of the older zoom, which is the transition that
      // reads most distinctly as "Android".
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        // Without this the bar tints as content scrolls beneath it — the most
        // recognisably "Android" motion in the whole app.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.text,
        centerTitle: true,
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: FontSizes.xs,
            fontWeight:
                selected ? FontWeights.semibold : FontWeights.medium,
            color: selected ? AppColors.primary : AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.primary : AppColors.textMuted,
          );
        }),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),

      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        titleTextStyle: const TextStyle(
          fontSize: FontSizes.lg,
          fontWeight: FontWeights.semibold,
          color: AppColors.text,
        ),
        contentTextStyle: const TextStyle(
          fontSize: FontSizes.base,
          height: LineHeights.normal,
          color: AppColors.textMuted,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: const TextStyle(
          fontSize: FontSizes.sm,
          color: AppColors.textInverse,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primarySoft
                : AppColors.border),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: Colors.transparent,
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionHandleColor: AppColors.primary,
      ),

      datePickerTheme: DatePickerThemeData(
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
    );
  }
}
