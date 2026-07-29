import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_text.dart';

/// Ported from `src/components/ui/Button.tsx`.
enum ButtonVariant { primary, secondary, ghost, danger }

enum ButtonSize { sm, md, lg }

class _VariantColors {
  const _VariantColors(this.bg, this.fg, this.border);
  final Color bg;
  final Color fg;
  final Color border;
}

const Map<ButtonVariant, _VariantColors> _variantStyles = {
  ButtonVariant.primary:
      _VariantColors(AppColors.primary, AppColors.textInverse, AppColors.primary),
  ButtonVariant.secondary: _VariantColors(
      AppColors.primarySoft, AppColors.primaryDark, AppColors.primarySoft),
  ButtonVariant.ghost:
      _VariantColors(Colors.transparent, AppColors.primary, Colors.transparent),
  ButtonVariant.danger: _VariantColors(
      AppColors.dangerSoft, AppColors.danger, AppColors.dangerSoft),
};

const Map<ButtonSize, double> _heights = {
  ButtonSize.sm: 40,
  ButtonSize.md: 50,
  ButtonSize.lg: 58,
};

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.icon,
    this.iconRight,
    this.loading = false,
    this.disabled = false,
    this.fullWidth = true,
    this.margin,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final IconData? iconRight;
  final bool loading;
  final bool disabled;
  final bool fullWidth;
  final EdgeInsetsGeometry? margin;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.loading;
    final v = _variantStyles[widget.variant]!;
    final iconSize = widget.size == ButtonSize.sm ? 16.0 : 20.0;

    final child = widget.loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: v.fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: iconSize, color: v.fg),
                const SizedBox(width: Spacing.sm),
              ],
              Flexible(
                child: AppText(
                  widget.label,
                  variant: TextVariant.bodyStrong,
                  style: TextStyle(color: v.fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.iconRight != null) ...[
                const SizedBox(width: Spacing.sm),
                Icon(widget.iconRight, size: iconSize, color: v.fg),
              ],
            ],
          );

    final button = AnimatedOpacity(
      opacity: isDisabled ? 0.45 : (_pressed ? 0.85 : 1),
      duration: const Duration(milliseconds: 90),
      child: AnimatedScale(
        scale: _pressed && !isDisabled ? 0.985 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: _heights[widget.size],
          width: widget.fullWidth ? double.infinity : null,
          margin: widget.margin,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: v.bg,
            border: Border.all(color: v.border),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: child,
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
        onTap: isDisabled ? null : widget.onPressed,
        child: button,
      ),
    );
  }
}
