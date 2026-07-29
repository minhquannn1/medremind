import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_text.dart';

/// Screen scaffold, header, divider, section header and empty state.
/// Ported from `src/components/ui/{Screen,Header,Divider,SectionHeader,EmptyState}.tsx`.

enum ScreenBackground { canvas, surface, primary }

class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.children,
    this.scroll = true,
    this.padded = true,
    this.onRefresh,
    this.background = ScreenBackground.canvas,
    this.bottomBar,
  });

  final List<Widget> children;
  final bool scroll;
  final bool padded;
  final Future<void> Function()? onRefresh;
  final ScreenBackground background;
  final Widget? bottomBar;

  Color get _bg {
    switch (background) {
      case ScreenBackground.primary:
        return AppColors.primary;
      case ScreenBackground.surface:
        return AppColors.surface;
      case ScreenBackground.canvas:
        return AppColors.canvas;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padded
          ? const EdgeInsets.only(
              left: Spacing.xl,
              right: Spacing.xl,
              top: Spacing.lg,
            )
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    Widget body;
    if (scroll) {
      final scrollView = SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: Spacing.xxxl),
        child: content,
      );
      body = onRefresh == null
          ? scrollView
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: onRefresh!,
              child: scrollView,
            );
    } else {
      body = content;
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: bottomBar,
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final VoidCallback? onBack;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left,
                    size: 26, color: AppColors.text),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: AppText(
              title,
              variant: TextVariant.subheading,
              center: true,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          SizedBox(
            width: 36,
            height: 36,
            child: actionIcon != null && onAction != null
                ? IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(actionIcon, size: 24, color: AppColors.primary),
                    onPressed: onAction,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.spaced = true});

  final bool spaced;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: spaced
          ? const EdgeInsets.symmetric(vertical: Spacing.lg)
          : EdgeInsets.zero,
      color: AppColors.border,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md, top: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: AppText(title,
                variant: TextVariant.subheading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm, vertical: Spacing.xs),
                child: AppText(actionLabel!,
                    variant: TextVariant.label, color: TextColorKey.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryFaint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: Spacing.lg),
          AppText(title, variant: TextVariant.subheading, center: true),
          if (body != null) ...[
            const SizedBox(height: Spacing.sm),
            AppText(body!, color: TextColorKey.textMuted, center: true),
          ],
          if (action != null) ...[
            const SizedBox(height: Spacing.xl),
            action!,
          ],
        ],
      ),
    );
  }
}
