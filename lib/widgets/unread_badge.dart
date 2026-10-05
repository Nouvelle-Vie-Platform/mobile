import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// **La pastille des non-lus** (#140) — sur l'onglet Échanges (le total) et sur
/// chaque tuile de conversation.
///
/// Le chiffre est affiché, la phrase est lue (`echangesUnreadBadge`) : un
/// lecteur d'écran qui dirait « douze » sans dire de quoi n'aiderait personne.
/// Au-delà de 99, « 99+ », comme partout. **Zéro ne se rend pas** : une pastille
/// à zéro serait une alerte qui n'alerte de rien.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, this.size = 20});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: context.l10n.echangesUnreadBadge(count),
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.55,
            height: 1,
          ),
        ),
      ),
    );
  }
}
