import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      backgroundColor: palette.surface,
      appBar: AppBar(backgroundColor: palette.surface),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Heureux de vous revoir !', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text('Connectez-vous pour continuer.',
                  style: AppTypography.bodyLarge
                      .copyWith(color: palette.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              const AppTextField(
                label: 'Email ou numéro',
                hint: 'jean.kossi@email.com',
                initialValue: 'jean.kossi@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(
                label: 'Mot de passe',
                initialValue: '••••••••',
                obscureText: true,
                suffixIcon: Icons.visibility_off_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text('Mot de passe oublié ?',
                      style: AppTypography.caption
                          .copyWith(color: palette.primary)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Se connecter',
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
                    Text('Pas encore de compte ? ',
                        style: AppTypography.body
                            .copyWith(color: palette.textSecondary)),
                    GestureDetector(
                      onTap: () => context.pushNamed(AppRoute.register),
                      child: Text('S\'inscrire',
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
          child: Text('Ou continuer avec',
              style: AppTypography.caption
                  .copyWith(color: context.palette.textSecondary)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
