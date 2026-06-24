import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/social_button.dart';

/// Écran de connexion.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.loginTitle, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text(context.l10n.loginSubtitle,
                  style: AppTypography.bodyLarge
                      .copyWith(color: palette.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                label: context.l10n.fieldEmailOrPhone,
                hint: 'jean.kossi@email.com',
                initialValue: 'jean.kossi@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: context.l10n.fieldPassword,
                initialValue: '••••••••',
                obscureText: true,
                suffixIcon: Icons.visibility_off_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(context.l10n.forgotPassword,
                      style: AppTypography.caption
                          .copyWith(color: palette.primary)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: context.l10n.actionLogin,
                onPressed: () => context.goNamed(AppRoute.home),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _OrDivider(),
              const SizedBox(height: AppSpacing.xl),
              const Row(
                children: [
                  Expanded(
                    child:
                        SocialButton(label: 'Google', icon: Icons.g_mobiledata),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SocialButton(label: 'Apple', icon: Icons.apple),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Wrap(
                  children: [
                    Text(context.l10n.noAccountYet,
                        style: AppTypography.body
                            .copyWith(color: palette.textSecondary)),
                    GestureDetector(
                      onTap: () => context.pushNamed(AppRoute.register),
                      child: Text(context.l10n.actionRegister,
                          style: AppTypography.bodyStrong
                              .copyWith(color: palette.primary)),
                    ),
                  ],
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(context.l10n.orContinueWith,
              style: AppTypography.caption
                  .copyWith(color: context.palette.textSecondary)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
