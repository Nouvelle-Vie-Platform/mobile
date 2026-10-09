import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// **Le cadran de qualité** (#184) : des pastilles posées sur un arc, et un
/// curseur en arc dessous. Composition reprise d'une maquette de référence.
///
/// **Sans magasin** : il reçoit les valeurs, le choix et un rappel, rien
/// d'autre. Les trois onglets de la page Qualité le partagent, et la radio n'a
/// pas le même type de valeur que l'écoute — d'où le paramètre de type.
///
/// Géométrie :
/// - **les pastilles** tournent sur un cercle de rayon `0,52 × largeur` dont
///   le sommet porte le choix ; chaque voisine est décalée de 32°. Le choix
///   est 1,6 fois plus grand et porte son nom ; au-delà de deux crans une
///   pastille s'efface, et celles du bord sont coupées par l'écran ;
/// - **le curseur** est un arc de cercle tendu d'un bord à l'autre (corde =
///   largeur − 2 × marge, flèche [_sliderSag]). Les valeurs y sont réparties
///   à intervalles égaux ; le trait plein va du bord gauche à la poignée.
///
/// Les deux lisent **la même position animée** (l'indice du choix, en
/// réel) : ils ne peuvent pas se désaccorder. L'animation dure 250 ms, et
/// rien quand le système demande de couper les animations.
class QualityArc<T> extends StatelessWidget {
  const QualityArc({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.onSelected,
    required this.semanticsLabel,
    this.keyOf,
    this.sliderKey,
  });

  /// Dans l'ordre de l'arc, de gauche à droite.
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final IconData Function(T value) iconOf;
  final ValueChanged<T> onSelected;

  /// Le nom du curseur pour les lecteurs d'écran.
  final String semanticsLabel;

  /// Clé de test de chaque pastille.
  final Key Function(T value)? keyOf;
  final Key? sliderKey;

  static const double _small = 60;
  static const double _big = 96;
  static const double _step = 32 * math.pi / 180;
  static const double _sliderHeight = 76;
  static const double _sliderMargin = 28;
  static const double _sliderSag = 40;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: index.toDouble()),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, position, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pastilles(width, position),
              _slider(context, width, position, index),
            ],
          ),
        );
      },
    );
  }

  Widget _pastilles(double width, double position) {
    final radius = width * 0.52;
    const top = _big / 2 + 8;
    final height = top + radius * (1 - math.cos(2 * _step)) + _small / 2 + 8;

    // Le choix se peint en dernier, donc par-dessus ses voisines.
    final order = List.generate(values.length, (i) => i)
      ..sort((a, b) =>
          (b - position).abs().compareTo((a - position).abs()));

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          for (final i in order)
            _placed(i - position, width, radius, top, values[i]),
        ],
      ),
    );
  }

  Widget _placed(double d, double width, double radius, double top, T value) {
    final distance = d.abs();
    final size = _big + (_small - _big) * distance.clamp(0.0, 1.0);
    final angle = d * _step;
    final x = width / 2 + radius * math.sin(angle);
    final y = top + radius * (1 - math.cos(angle));
    final opacity = (3 - distance).clamp(0.0, 1.0);
    final labelOpacity = (1 - distance * 2).clamp(0.0, 1.0);

    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        ignoring: opacity == 0,
        child: Opacity(
          opacity: opacity,
          child: _Pastille(
            key: keyOf?.call(value),
            size: size,
            icon: iconOf(value),
            label: labelOf(value),
            labelOpacity: labelOpacity,
            selected: value == selected,
            onTap: () => onSelected(value),
          ),
        ),
      ),
    );
  }

  Widget _slider(
      BuildContext context, double width, double position, int index) {
    final palette = context.palette;
    final geometry = _ArcGeometry(width);
    final last = values.length - 1;
    final t = last == 0 ? 0.0 : position / last;

    void selectAt(Offset local) {
      final i = (geometry.fractionAt(local) * last).round();
      if (i != index) onSelected(values[i]);
    }

    return Semantics(
      container: true,
      slider: true,
      label: semanticsLabel,
      value: labelOf(selected),
      increasedValue: index < last ? labelOf(values[index + 1]) : null,
      decreasedValue: index > 0 ? labelOf(values[index - 1]) : null,
      onIncrease:
          index < last ? () => onSelected(values[index + 1]) : null,
      onDecrease: index > 0 ? () => onSelected(values[index - 1]) : null,
      child: GestureDetector(
        key: sliderKey,
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => selectAt(details.localPosition),
        onHorizontalDragStart: (details) => selectAt(details.localPosition),
        onHorizontalDragUpdate: (details) =>
            selectAt(details.localPosition),
        child: CustomPaint(
          size: Size(width, _sliderHeight),
          painter: _ArcPainter(
            geometry: geometry,
            fraction: t,
            track: palette.border,
          ),
        ),
      ),
    );
  }
}

/// L'arc du curseur : un cercle dont on ne garde que la calotte, posée sur
/// toute la largeur. φ se mesure depuis le sommet, positif vers la droite.
class _ArcGeometry {
  _ArcGeometry(double width)
      : center = Offset(
          width / 2,
          QualityArc._sliderMargin / 2 + _radiusFor(width),
        ),
        radius = _radiusFor(width),
        halfAngle = math.asin(_chord(width) / 2 / _radiusFor(width));

  static double _chord(double width) =>
      width - 2 * QualityArc._sliderMargin;

  /// Le rayon du cercle qui passe par les deux bouts de la corde et par le
  /// sommet, [QualityArc._sliderSag] plus haut.
  static double _radiusFor(double width) {
    final half = _chord(width) / 2;
    const sag = QualityArc._sliderSag;
    return (half * half + sag * sag) / (2 * sag);
  }

  final Offset center;
  final double radius;
  final double halfAngle;

  Offset pointAt(double fraction) {
    final phi = -halfAngle + 2 * halfAngle * fraction;
    return center +
        Offset(radius * math.sin(phi), -radius * math.cos(phi));
  }

  /// La fraction d'arc la plus proche d'un point touché, bornée à [0, 1].
  double fractionAt(Offset local) {
    final delta = local - center;
    final phi = math.atan2(delta.dx, -delta.dy);
    return ((phi + halfAngle) / (2 * halfAngle)).clamp(0.0, 1.0);
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.geometry,
    required this.fraction,
    required this.track,
  });

  final _ArcGeometry geometry;
  final double fraction;
  final Color track;

  static const double _stroke = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: geometry.center,
      radius: geometry.radius,
    );
    // L'angle du canevas part de l'axe x ; le nôtre part du sommet.
    final start = -math.pi / 2 - geometry.halfAngle;
    final sweep = 2 * geometry.halfAngle;
    final filled = sweep * fraction;

    // Le reste de l'arc, en tirets clairs.
    final dashes = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final dash = 6 / geometry.radius;
    final end = start + sweep;
    for (var a = start + filled + 2 * dash; a < end; a += 2 * dash) {
      canvas.drawArc(rect, a, dash, false, dashes);
    }

    // Le trait plein, du clair au bleu de marque.
    final fill = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB4C6F4), AppColors.primary],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, filled, false, fill);

    // La poignée : un rond blanc cerclé, sur une ombre douce.
    final handle = geometry.pointAt(fraction);
    canvas.drawCircle(
      handle + const Offset(0, 3),
      14,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(handle, 13, Paint()..color = Colors.white);
    canvas.drawCircle(
      handle,
      13,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.geometry.radius != geometry.radius;
}

/// Une pastille : un rond de verre clair, et dedans un rond plein au dégradé
/// de marque portant un pictogramme blanc. Le nom n'apparaît que sous le
/// choix ([labelOpacity] > 0), en débord sous le rond.
class _Pastille extends StatelessWidget {
  const _Pastille({
    super.key,
    required this.size,
    required this.icon,
    required this.label,
    required this.labelOpacity,
    required this.selected,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final String label;
  final double labelOpacity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final inner = size * 0.64;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surface.withValues(alpha: 0.7),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: inner,
                height: inner,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B7FE0), AppColors.primary],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: inner * 0.5),
              ),
            ),
            if (labelOpacity > 0)
              Positioned(
                top: size + 6,
                left: -40,
                right: -40,
                child: Opacity(
                  opacity: labelOpacity,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
