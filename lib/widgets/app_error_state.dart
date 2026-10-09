import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_card.dart';

/// État « échec de chargement » partagé des écrans asynchrones.
///
/// Toute sa raison d'être tient dans un contraste : **un écran vide parce que
/// le réseau a coupé ne doit jamais ressembler à un écran légitimement vide**.
/// Trois différences délibérées avec `AppEmptyState`, visibles avant même la
/// lecture : la carte est teintée en rouge d'alerte (et non neutre), le
/// pictogramme est un signal de connexion coupée dans une pastille rouge (et
/// non une icône grise), et il y a un **bouton** — donc quelque chose à faire,
/// alors qu'un état vide ne propose rien.
///
/// La cause est donnée en langage humain : jamais un code HTTP brut, jamais un
/// `toString()` d'exception. L'appelant traduit son erreur en message avant de
/// la passer ici (voir les clés `stateError*`).
///
/// Aucune notion métier dans son API : des textes et un callback.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.onRetry,
    this.title,
    this.message,
    this.retryLabel,
    this.icon = Icons.wifi_off_rounded,
    this.onDark = false,
  });

  /// Rappelé au clic sur « Réessayer ». Un état d'erreur sans porte de sortie
  /// n'en est pas un : le callback est obligatoire.
  final VoidCallback onRetry;

  /// À défaut, un titre générique (`stateErrorTitle`).
  final String? title;

  /// Cause lisible ; à défaut, le message réseau générique
  /// (`stateErrorMessage`).
  final String? message;

  /// À défaut, « Réessayer » (`stateRetry`).
  final String? retryLabel;

  final IconData icon;

  /// **Sur une scène sombre** (les lecteurs plein écran) : pas de carte rose
  /// posée sur l'image, mais le texte blanc et le rond translucide de
  /// `ContentAbsenceView(onDark: true)` — les états d'un même écran parlent
  /// le même langage. La carte claire jurait sur le fond de l'antenne.
  final bool onDark;

  /// Clé du bouton d'action, pour le cibler depuis les tests.
  static const Key retryKey = Key('app_error_state_retry');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    if (onDark) {
      const primary = Colors.white;
      final secondary = Colors.white.withValues(alpha: 0.75);
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title ?? l10n.stateErrorTitle,
              textAlign: TextAlign.center,
              style: AppTypography.h4.copyWith(color: primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message ?? l10n.stateErrorMessage,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Une pilule en contour translucide : sur une image, un bouton
            // plein et blanc pèserait plus que le message qu'il accompagne.
            OutlinedButton.icon(
              key: retryKey,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(retryLabel ?? l10n.stateRetry),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.45)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                textStyle: AppTypography.bodyStrong,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      color: palette.dangerBg,
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.30)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.danger),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title ?? l10n.stateErrorTitle,
            textAlign: TextAlign.center,
            style: AppTypography.h5.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message ?? l10n.stateErrorMessage,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: retryKey,
            label: retryLabel ?? l10n.stateRetry,
            icon: Icons.refresh,
            variant: AppButtonVariant.outline,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
