import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('Inscription')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Créer votre compte', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text('Rejoignez notre communauté.',
                  style: AppTypography.bodyLarge
                      .copyWith(color: palette.textSecondary)),
              const SizedBox(height: AppSpacing.xl),
              const AppTextField(label: 'Nom complet', hint: 'Jean Kossi'),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(
                label: 'Téléphone',
                hint: '+228 90 12 34 56',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _BranchField(),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'S\'inscrire',
                onPressed: () => context.goNamed(AppRoute.home),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                    children: [
                      const TextSpan(
                          text: 'En créant un compte, vous acceptez nos '),
                      TextSpan(
                          text: 'Conditions d\'utilisation.',
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
        Text('Branche locale', style: AppTypography.bodyStrong),
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
