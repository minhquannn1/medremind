import 'package:flutter/material.dart';

import 'package:medremind/ui/core/theme/tokens.dart';

/// Typography scale. Ported from `src/components/ui/Text.tsx`.
///
/// RN expressed lineHeight in absolute pixels (fontSize * multiplier); Flutter's
/// TextStyle.height is a multiplier, so the multipliers carry over directly.
enum TextVariant {
  display,
  title,
  heading,
  subheading,
  body,
  bodyStrong,
  label,
  caption,
}

enum TextColorKey {
  text,
  textMuted,
  textFaint,
  textInverse,
  primary,
  accent,
  danger,
  success,
  warn,
}

const Map<TextColorKey, Color> _colorMap = {
  TextColorKey.text: AppColors.text,
  TextColorKey.textMuted: AppColors.textMuted,
  TextColorKey.textFaint: AppColors.textFaint,
  TextColorKey.textInverse: AppColors.textInverse,
  TextColorKey.primary: AppColors.primary,
  TextColorKey.accent: AppColors.accent,
  TextColorKey.danger: AppColors.danger,
  TextColorKey.success: AppColors.success,
  TextColorKey.warn: AppColors.warn,
};

TextStyle textStyleFor(TextVariant variant) {
  switch (variant) {
    case TextVariant.display:
      return const TextStyle(
        fontSize: FontSizes.display,
        fontWeight: FontWeights.bold,
        height: LineHeights.tight,
        letterSpacing: -0.5,
      );
    case TextVariant.title:
      return const TextStyle(
        fontSize: FontSizes.xxxl,
        fontWeight: FontWeights.bold,
        height: LineHeights.tight,
        letterSpacing: -0.4,
      );
    case TextVariant.heading:
      return const TextStyle(
        fontSize: FontSizes.xxl,
        fontWeight: FontWeights.bold,
        height: LineHeights.snug,
        letterSpacing: -0.3,
      );
    case TextVariant.subheading:
      return const TextStyle(
        fontSize: FontSizes.xl,
        fontWeight: FontWeights.semibold,
        height: LineHeights.snug,
      );
    case TextVariant.body:
      return const TextStyle(
        fontSize: FontSizes.base,
        fontWeight: FontWeights.regular,
        height: LineHeights.normal,
      );
    case TextVariant.bodyStrong:
      return const TextStyle(
        fontSize: FontSizes.base,
        fontWeight: FontWeights.semibold,
        height: LineHeights.normal,
      );
    case TextVariant.label:
      return const TextStyle(
        fontSize: FontSizes.sm,
        fontWeight: FontWeights.semibold,
        height: LineHeights.snug,
        letterSpacing: 0.2,
      );
    case TextVariant.caption:
      return const TextStyle(
        fontSize: FontSizes.xs,
        fontWeight: FontWeights.medium,
        height: LineHeights.snug,
        letterSpacing: 0.2,
      );
  }
}

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.variant = TextVariant.body,
    this.color = TextColorKey.text,
    this.center = false,
    this.maxLines,
    this.overflow,
    this.style,
  });

  final String data;
  final TextVariant variant;
  final TextColorKey color;
  final bool center;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = textStyleFor(variant).copyWith(color: _colorMap[color]);
    return Text(
      data,
      textAlign: center ? TextAlign.center : null,
      maxLines: maxLines,
      overflow: overflow,
      style: style == null ? base : base.merge(style),
    );
  }
}
