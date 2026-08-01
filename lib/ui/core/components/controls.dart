import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/core/components/app_text.dart';

/// Badge, chip select, segmented control and progress ring.
/// Ported from `src/components/ui/{Badge,ChipSelect,SegmentedControl,ProgressRing}.tsx`.

enum BadgeTone { neutral, primary, success, warn, danger, accent }

class _ToneColors {
  const _ToneColors(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

const Map<BadgeTone, _ToneColors> _badgeTones = {
  BadgeTone.neutral: _ToneColors(AppColors.canvas, AppColors.textMuted),
  BadgeTone.primary: _ToneColors(AppColors.primarySoft, AppColors.primaryDark),
  BadgeTone.success: _ToneColors(AppColors.successSoft, AppColors.success),
  BadgeTone.warn: _ToneColors(AppColors.warnSoft, AppColors.warn),
  BadgeTone.danger: _ToneColors(AppColors.dangerSoft, AppColors.danger),
  BadgeTone.accent: _ToneColors(AppColors.accentSoft, AppColors.accent),
};

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = _badgeTones[tone]!;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: t.fg),
            const SizedBox(width: 4),
          ],
          AppText(label,
              variant: TextVariant.caption, style: TextStyle(color: t.fg)),
        ],
      ),
    );
  }
}

class ChipOption<T> {
  const ChipOption({required this.value, required this.label});
  final T value;
  final String label;
}

class ChipSelect<T> extends StatelessWidget {
  const ChipSelect({
    super.key,
    this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String? label;
  final List<ChipOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: AppText(label!,
                  variant: TextVariant.label, color: TextColorKey.textMuted),
            ),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: options.map((opt) {
              final active = opt.value == value;
              return Semantics(
                button: true,
                selected: active,
                child: GestureDetector(
                  onTap: () => onChanged(opt.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: Spacing.sm, horizontal: Spacing.lg),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.canvas,
                      border: Border.all(
                        color: active ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: AppText(
                      opt.label,
                      variant: TextVariant.label,
                      style: TextStyle(
                        color: active
                            ? AppColors.textInverse
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<ChipOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: options.map((opt) {
          final active = opt.value == value;
          return Expanded(
            child: Semantics(
              button: true,
              selected: active,
              child: GestureDetector(
                onTap: () => onChanged(opt.value),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    boxShadow: active ? Shadows.card : null,
                  ),
                  child: AppText(
                    opt.label,
                    variant: TextVariant.label,
                    style: TextStyle(
                      color:
                          active ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Circular adherence indicator. Replaces the react-native-svg version with
/// a CustomPainter — no extra dependency needed.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 132,
    this.stroke = 12,
    this.label,
    this.caption,
    this.color = AppColors.primary,
    this.trackColor = AppColors.primarySoft,
  });

  /// 0..1
  final double progress;
  final double size;
  final double stroke;
  final String? label;
  final String? caption;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0, 1).toDouble(),
              stroke: stroke,
              color: color,
              trackColor: trackColor,
            ),
          ),
          // Clamp the centre content to the square that fits inside the ring
          // (side = inner diameter / sqrt2). Without this a long caption runs
          // out over the stroke and past the circle.
          SizedBox(
            width: (size - stroke * 2) / math.sqrt2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null)
                  AppText(label!,
                      variant: TextVariant.title,
                      color: TextColorKey.primary,
                      center: true,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (caption != null)
                  AppText(caption!,
                      variant: TextVariant.caption,
                      color: TextColorKey.textMuted,
                      center: true,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double stroke;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, r, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2, // start at 12 o'clock, like the RN rotate(-90)
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.stroke != stroke;
}
