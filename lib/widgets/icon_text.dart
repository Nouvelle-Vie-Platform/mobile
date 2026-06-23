import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// Ligne « icône + texte » réutilisée pour les méta-infos
/// (date, heure, lieu, auteur…).
class IconText extends StatelessWidget {
  const IconText({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.style,
  });

  final IconData icon;
  final String label;

  /// Couleur explicite ; par défaut, le texte secondaire adaptatif.
  final Color? color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: style ?? AppTypography.caption.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}
