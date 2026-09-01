import 'package:flutter/material.dart';

import 'package:medremind/ui/core/components/app_button.dart';
import 'package:medremind/ui/core/components/app_text.dart';
import 'package:medremind/ui/core/i18n/app_localizations.dart';
import 'package:medremind/ui/core/theme/tokens.dart';
import 'package:medremind/ui/features/welcome/view_models/welcome_view_model.dart';

/// The first-run walkthrough, drawn over the app rather than in front of it.
///
/// The app is already loaded and usable underneath: this is an explanation,
/// not a step to get through, which is the distinction App Review cared about
/// in Guideline 5.1.1(v). Nothing here asks the user for anything.
class WelcomeCarousel extends StatelessWidget {
  const WelcomeCarousel({super.key, required this.vm, required this.t});

  final WelcomeViewModel vm;
  final Translations t;

  static const _icons = [
    Icons.medical_services_outlined,
    Icons.document_scanner_outlined,
    Icons.notifications_active_outlined,
    Icons.insights_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final page = vm.page;

    return Material(
      color: AppColors.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: vm.finish,
                  child: AppText(t.t('welcome.skip'),
                      color: TextColorKey.textMuted),
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icons[vm.index],
                              color: AppColors.primary, size: 34),
                        ),
                        const SizedBox(height: Spacing.xl),
                        AppText(t.t(page.titleKey), variant: TextVariant.title),
                        const SizedBox(height: Spacing.md),
                        AppText(t.t(page.bodyKey),
                            color: TextColorKey.textMuted),
                        if (page.footnoteKey != null) ...[
                          const SizedBox(height: Spacing.lg),
                          AppText(t.t(page.footnoteKey!),
                              variant: TextVariant.caption,
                              color: TextColorKey.textFaint),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < WelcomeViewModel.pages.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: i == vm.index ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == vm.index
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.lg),

              AppButton(
                label: vm.isLast ? t.t('welcome.start') : t.t('welcome.next'),
                size: ButtonSize.lg,
                onPressed: vm.next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
