import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

/// Écran d'inscription.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(title: Text(context.l10n.registerAppBarTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.registerTitle, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(context.l10n.registerSubtitle,
                  style: AppTypography.bodyLarge
                      .copyWith(color: palette.textSecondary)),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                  label: context.l10n.fieldFullName, hint: 'Jean Kossi'),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: context.l10n.fieldPhone,
                hint: '+228 90 12 34 56',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _BranchField(),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: context.l10n.actionRegister,
                onPressed: () => context.goNamed(AppRoute.home),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                    children: [
                      TextSpan(text: context.l10n.registerTermsPrefix),
                      TextSpan(
                          text: context.l10n.registerTermsLink,
                          style: AppTypography.caption
                              .copyWith(color: palette.primary)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Champ « Branche locale » sous forme de sélecteur (lecture seule).
class _BranchField extends StatelessWidget {
  const _BranchField();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.fieldLocalBranch, style: AppTypography.bodyStrong),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          borderRadius: AppRadius.field,
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: AppRadius.field,
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Église Mère - Lomé',
                      style: AppTypography.bodyLarge),
                ),
                Icon(Icons.keyboard_arrow_down, color: palette.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
