import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_text.dart';

/// Ported from `src/components/ui/Input.tsx`.
///
/// When [onPressContainer] is set the field becomes a tappable read-only
/// surface (used by the date and time pickers), exactly like the RN version.
class AppInput extends StatelessWidget {
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
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool autocorrect;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final isTappable = onPressContainer != null;

    final field = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: BoxDecoration(
        color: editableLook ? AppColors.surface : AppColors.canvas,
        border: Border.all(
          color: error != null ? AppColors.danger : AppColors.border,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.textFaint),
            const SizedBox(width: Spacing.sm),
          ],
          Expanded(
            child: IgnorePointer(
              ignoring: isTappable,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                obscureText: obscureText,
                maxLines: obscureText ? 1 : maxLines,
                onChanged: onChanged,
                autocorrect: autocorrect,
                autofillHints: autofillHints,
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
                  hintText: placeholder,
                  hintStyle: textStyleFor(TextVariant.body)
                      .copyWith(color: AppColors.textFaint),
                ),
              ),
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: Spacing.sm),
            AppText(suffix!, color: TextColorKey.textFaint),
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
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: AppText(label!,
                  variant: TextVariant.label, color: TextColorKey.textMuted),
            ),
          if (isTappable)
            GestureDetector(
              onTap: onPressContainer,
              // The inner TextField is wrapped in IgnorePointer, so without an
              // opaque behavior a tap landing on the text itself hits nothing
              // and the picker never opens.
              behavior: HitTestBehavior.opaque,
              child: field,
            )
          else
            field,
          if (error != null || hint != null)
            Padding(
              padding: const EdgeInsets.only(
                  top: Spacing.xs, left: Spacing.xs),
              child: AppText(
                error ?? hint!,
                variant: TextVariant.caption,
                color:
                    error != null ? TextColorKey.danger : TextColorKey.textFaint,
              ),
            ),
        ],
      ),
    );
  }
}
