import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Squelette de chargement d'une **liste de cartes**.
///
/// Pourquoi un squelette plutôt qu'un `CircularProgressIndicator` centré : la
/// forme de la liste est connue avant même que les données n'arrivent. Peindre
/// tout de suite cette silhouette évite le saut de mise en page (le contenu
/// remplace des blocs de même gabarit) et annonce *ce qui* charge, pas
/// seulement *que* ça charge.
///
/// Générique par construction : ni le mot « événement » ni la moindre notion
/// d'agenda n'apparaît ici. Le gabarit se règle par [itemCount], [leading]
/// (pastille de tête : date, vignette ou avatar) et [lines].
///
/// L'animation est un fondu lent et continu. Conséquence pour les tests : le
/// widget **ne se stabilise jamais**, donc `pumpAndSettle` expirerait — utiliser
/// `pump()`. L'animation est coupée quand le système demande de réduire les
/// animations (`MediaQuery.disableAnimations`).
class AppListSkeleton extends StatefulWidget {
  const AppListSkeleton({
    super.key,
    this.itemCount = 3,
    this.leading = true,
    this.lines = 2,
    this.padding = EdgeInsets.zero,
  });

  /// Nombre de cartes fantômes empilées.
  final int itemCount;

  /// Affiche une pastille carrée en tête de carte (date, vignette, avatar…).
  final bool leading;

  /// Nombre de barres de texte sous le titre fantôme.
  final int lines;

  final EdgeInsetsGeometry padding;

  /// Durée d'un aller simple du fondu (l'aller-retour dure le double).
  static const Duration pulseDuration = Duration(milliseconds: 900);

  @override
  State<AppListSkeleton> createState() => _AppListSkeletonState();
}

class _AppListSkeletonState extends State<AppListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppListSkeleton.pulseDuration,
  );

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // État purement local et éphémère (une animation) : `StatefulWidget`, pas
    // de provider ni de `ValueNotifier` fabriqué dans `build()`.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.itemCount < 0 ? 0 : widget.itemCount;

    return Semantics(
      label: context.l10n.stateLoading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: widget.padding,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              // Fondu sobre : le bloc respire entre deux gris très proches,
              // jamais jusqu'à la disparition (ça clignoterait).
              final alpha = 0.10 + 0.10 * _pulse.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _SkeletonCard(
                      alpha: alpha,
                      leading: widget.leading,
                      lines: widget.lines,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Une carte fantôme : même habillage verre dépoli que le contenu réel, garni
/// de formes grisées au gabarit d'une carte de liste.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.alpha,
    required this.leading,
    required this.lines,
  });

  final double alpha;
  final bool leading;
  final int lines;

  @override
  Widget build(BuildContext context) {
    // Largeurs décroissantes : une liste réelle n'a pas des lignes égales.
    const widths = <double>[0.55, 0.38, 0.30];

    return AppCard(
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading) ...[
            _SkeletonShape(
              alpha: alpha,
              width: 56,
              height: 60,
              radius: AppRadius.md,
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonShape(
                  alpha: alpha,
                  height: 16,
                  widthFactor: 0.72,
                  radius: AppRadius.sm,
                ),
                for (var i = 0; i < lines; i++) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _SkeletonShape(
                    alpha: alpha,
                    height: 10,
                    widthFactor: widths[i % widths.length],
                    radius: AppRadius.sm,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rectangle grisé. La teinte dérive de la palette adaptative : elle reste
/// lisible en clair comme en sombre, sans couleur codée en dur.
class _SkeletonShape extends StatelessWidget {
  const _SkeletonShape({
    required this.alpha,
    required this.height,
    required this.radius,
    this.width,
    this.widthFactor,
  });

  final double alpha;
  final double height;
  final double radius;
  final double? width;
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    final shape = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.textSecondary.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    if (widthFactor == null) return shape;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: shape,
    );
  }
}
