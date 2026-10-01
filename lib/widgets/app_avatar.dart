import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Avatar circulaire affichant les initiales sur un fond coloré.
///
/// Faute de photo dans la maquette, on génère une couleur stable à partir
/// du nom et on affiche les initiales.
/// Il en existe une seconde forme, [AppAvatar.neutral], **sans nom du tout** :
/// voir son en-tête.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
  }) : _neutral = false;

  /// **Un avatar qui ne désigne personne** (#96) — ni initiale, ni teinte dérivée
  /// d'un nom : une silhouette sur un gris de palette.
  ///
  /// Il existe pour l'**auteur retiré** d'un message (ADR-0032), et il est
  /// délibérément un constructeur **sans paramètre `name`** plutôt qu'un drapeau
  /// de plus. `docs/messagerie-groupe.md` §5 avertit qu'il ne faut pas passer
  /// « Membre retiré » à `AppAvatar(name:)` : on en tirerait les initiales « MR »
  /// et une couleur dérivée de la **longueur du libellé**, c'est-à-dire deux
  /// marqueurs d'identité fabriqués de toutes pièces et **identiques pour tous**
  /// les auteurs retirés. Un avertissement se rate ; une signature qui n'accepte
  /// pas de nom ne se rate pas.
  ///
  /// Passer la chaîne vide aurait donné « ? », ce qui est au moins vrai — mais un
  /// point d'interrogation se lit « je ne sais pas qui c'est », là où le fait est
  /// « cette personne est partie ».
  const AppAvatar.neutral({super.key, this.size = 44, this.color})
      : name = '',
        _neutral = true;

  final String name;
  final double size;
  final Color? color;

  final bool _neutral;

  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFFE0709A),
    Color(0xFFE6A100),
    Color(0xFF7A5AF8),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ??
        (_neutral ? _neutralColor : _palette[name.length % _palette.length]);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: _neutral
          ? Icon(
              Icons.person_outline,
              color: Colors.white,
              size: size * 0.52,
            )
          : Text(
              _initials,
              style: AppTypography.bodyStrong.copyWith(
                color: Colors.white,
                fontSize: size * 0.36,
              ),
            ),
    );
  }

  /// Le gris de l'avatar neutre : **hors de la palette**, pour qu'il ne puisse
  /// jamais être pris pour la teinte d'un nom.
  static const Color _neutralColor = Color(0xFF8A94A6);
}
