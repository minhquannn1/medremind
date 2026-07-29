import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Surface container. Ported from `src/components/ui/Card.tsx`.
enum CardTone { surface, primary, accent, warn, success }

const Map<CardTone, Color> _toneBg = {
  CardTone.surface: AppColors.surface,
  CardTone.primary: AppColors.primarySoft,
  CardTone.accent: AppColors.accentSoft,
  CardTone.warn: AppColors.warnSoft,
  CardTone.success: AppColors.successSoft,
};

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onPress,
    this.padded = true,
    this.elevated = true,
    this.tone = CardTone.surface,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onPress;
  final bool padded;
  final bool elevated;
  final CardTone tone;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padded ? const EdgeInsets.all(Spacing.lg) : null,
      decoration: BoxDecoration(
        color: _toneBg[tone],
        borderRadius: BorderRadius.circular(Radii.lg),
        // Only the plain surface tone carries elevation, matching the RN card:
        // tinted cards read as fills, not raised surfaces.
        boxShadow:
            elevated && tone == CardTone.surface ? Shadows.card : null,
      ),
      child: child,
    );

    if (onPress == null) return content;

    return _PressableCard(onPress: onPress!, child: content);
  }
}

/// Reproduces the RN pressed state (slight fade + scale) since Flutter's
/// InkWell ripple would look wrong on these soft clinical surfaces.
class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.onPress, required this.child});

  final VoidCallback onPress;
  final Widget child;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPress,
        child: AnimatedScale(
          scale: _pressed ? 0.99 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            opacity: _pressed ? 0.92 : 1,
            duration: const Duration(milliseconds: 90),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
