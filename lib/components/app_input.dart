import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_text.dart';

/// Ported from `src/components/ui/Input.tsx`.
///
/// When [onPressContainer] is set the field becomes a tappable read-only
/// surface (used by the date and time pickers), exactly like the RN version.
class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    this.controller,
    this.label,
    this.error,
    this.hint,
    this.icon,
    this.suffix,
    this.placeholder,
    this.onPressContainer,
    this.editableLook = true,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.obscureToggle = false,
    this.revealLabel,
    this.hideLabel,
    this.maxLines = 1,
    this.onChanged,
    this.autocorrect = true,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;
  final String? error;
  final String? hint;
  final IconData? icon;
  final String? suffix;
  final String? placeholder;
  final VoidCallback? onPressContainer;
  final bool editableLook;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;

  /// Adds an eye button that reveals the text. Only meaningful together with
  /// [obscureText] — a password the user cannot re-read is easy to mistype,
  /// especially on a phone keyboard.
  final bool obscureToggle;

  /// Accessibility labels for that button, supplied by the caller so they stay
  /// in the app's language.
  final String? revealLabel;
  final String? hideLabel;

  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool autocorrect;
  final Iterable<String>? autofillHints;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late bool _obscured = widget.obscureText;

  @override
  void didUpdateWidget(AppInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-hide if the field switches back to a password field.
    if (widget.obscureText != oldWidget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTappable = widget.onPressContainer != null;
    final showToggle = widget.obscureToggle && widget.obscureText;

    final field = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: EdgeInsets.only(
        left: Spacing.lg,
        // The icon button carries its own padding; without this the field
        // would look lopsided next to a plain one.
        right: showToggle ? Spacing.xs : Spacing.lg,
      ),
      decoration: BoxDecoration(
        color: widget.editableLook ? AppColors.surface : AppColors.canvas,
        border: Border.all(
          color: widget.error != null ? AppColors.danger : AppColors.border,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: AppColors.textFaint),
            const SizedBox(width: Spacing.sm),
          ],
          Expanded(
            child: IgnorePointer(
              ignoring: isTappable,
              child: TextField(
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                obscureText: _obscured,
                maxLines: widget.obscureText ? 1 : widget.maxLines,
                onChanged: widget.onChanged,
                autocorrect: widget.autocorrect,
                autofillHints: widget.autofillHints,
                enabled: !isTappable,
                style: textStyleFor(TextVariant.body)
                    .copyWith(color: AppColors.text),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: Spacing.md),
                  hintText: widget.placeholder,
                  hintStyle: textStyleFor(TextVariant.body)
                      .copyWith(color: AppColors.textFaint),
                ),
              ),
            ),
          ),
          if (showToggle)
            IconButton(
              icon: Icon(
                _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
              tooltip: _obscured ? widget.revealLabel : widget.hideLabel,
              onPressed: () => setState(() => _obscured = !_obscured),
            )
          else if (widget.suffix != null) ...[
            const SizedBox(width: Spacing.sm),
            AppText(widget.suffix!, color: TextColorKey.textFaint),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        // Hug the content: an input must never claim leftover vertical space
        // when it sits in a Column that has room to spare.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: AppText(
                widget.label!,
                variant: TextVariant.label,
                color: TextColorKey.textMuted,
              ),
            ),
          if (isTappable)
            GestureDetector(
              onTap: widget.onPressContainer,
              // The inner TextField is wrapped in IgnorePointer, so without an
              // opaque behavior a tap landing on the text itself hits nothing
              // and the picker never opens.
              behavior: HitTestBehavior.opaque,
              child: field,
            )
          else
            field,
          if (widget.error != null || widget.hint != null)
            Padding(
              padding:
                  const EdgeInsets.only(top: Spacing.xs, left: Spacing.xs),
              child: AppText(
                widget.error ?? widget.hint!,
                variant: TextVariant.caption,
                color: widget.error != null
                    ? TextColorKey.danger
                    : TextColorKey.textFaint,
              ),
            ),
        ],
      ),
    );
  }
}
