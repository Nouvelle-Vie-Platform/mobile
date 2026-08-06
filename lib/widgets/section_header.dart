import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// En-tête de section avec titre et lien d'action optionnel (« Voir tout »).
///
/// [accent] permet à une section **habillée par la donnée** (une rubrique de
/// l'accueil, dont le serveur choisit la teinte) de remplacer le bleu de
/// marque. Elle colore la pastille et le lien d'action, **jamais le titre** :
/// une couleur administrable est sûre en aplat — la forme la porte, le texte
/// dessus reste blanc — et ne l'est pas en texte, où le fond adaptatif
/// clair/sombre en avalerait la moitié.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.accent,
    this.actionLabel,
    this.onAction,
  });

  final String title;

  /// Pictogramme optionnel affiché avant le titre (pastille arrondie). Sans
  /// lui mais avec [accent], une pastille pleine tient sa place : une rubrique
  /// du référentiel n'a pas d'icône, elle a une couleur.
  final IconData? icon;

  /// Teinte de la section, à défaut le bleu de marque du thème.
  final Color? accent;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = accent ?? palette.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 17, color: tint),
                ),
                const SizedBox(width: AppSpacing.sm),
              ] else if (accent != null) ...[
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                Text(
                  actionLabel!,
                  style: AppTypography.caption.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: tint),
              ],
            ),
          ),
      ],
    );
  }
}
