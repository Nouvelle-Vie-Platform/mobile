import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Les deux façons dont une liste asynchrone peut légitimement ne rien montrer.
///
/// La distinction n'est pas cosmétique : elle répond à deux questions
/// différentes de l'utilisateur.
enum AppEmptyStateVariant {
  /// « Il n'y a rien ici » — la source a répondu, elle affirme le vide.
  /// Rendu : bloc centré, pictogramme, titre, explication.
  nothing,

  /// « Il n'y a plus rien **au-delà** » — l'utilisateur a atteint la borne
  /// d'horizon au-delà de laquelle la source n'affirme plus rien. C'est une
  /// fin de parcours, pas une absence : rendu discret en pied de liste
  /// (filets de part et d'autre d'un libellé), sans bloc plein cadre.
  endOfRange,
}

/// État « vide » partagé des écrans asynchrones.
///
/// Volontairement **neutre** : gris, sans bouton, sans teinte d'alerte. C'est
/// ce qui le sépare au premier coup d'œil de `AppErrorState`, qui est teinté
/// et porte une action. Un écran vide dit « il n'y a rien de prévu » ; il ne
/// doit jamais pouvoir se lire « je n'ai pas pu charger ».
///
/// Aucune notion métier dans son API : on lui passe des textes et une variante.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.variant = AppEmptyStateVariant.nothing,
  });

  /// Libellé principal, déjà localisé par l'appelant.
  final String title;

  /// Explication facultative sous le titre.
  final String? message;

  /// Pictogramme ; à défaut, celui de la variante.
  final IconData? icon;

  final AppEmptyStateVariant variant;

  IconData get _icon =>
      icon ??
      switch (variant) {
        AppEmptyStateVariant.nothing => Icons.inbox_outlined,
        AppEmptyStateVariant.endOfRange => Icons.outlined_flag,
      };

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppEmptyStateVariant.nothing => _buildNothing(context),
      AppEmptyStateVariant.endOfRange => _buildEndOfRange(context),
    };
  }

  Widget _buildNothing(BuildContext context) {
    final palette = context.palette;
    return AppCard(
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
              color: palette.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 28, color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.h5.copyWith(color: palette.textPrimary),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEndOfRange(BuildContext context) {
    final palette = context.palette;
    final divider = Expanded(
      child: Divider(color: palette.divider, thickness: 1),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              divider,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, size: 15, color: palette.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      title,
                      style: AppTypography.caption.copyWith(
                        color: palette.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              divider,
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: palette.textSecondary.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
