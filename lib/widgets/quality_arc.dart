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
/// - **les pastilles sont fixes** : chacune reste au-dessus de son cran du
///   curseur, le long de la normale à l'arc. Quand la poignée arrive à son
///   niveau, elle grossit (×1,7) et porte son nom ; les autres reprennent
///   leur petite taille sur place ;
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

  /// Le pictogramme d'un choix, dessiné en blanc à la taille donnée.
  final Widget Function(T value, double size) iconOf;
  final ValueChanged<T> onSelected;

  /// Le nom du curseur pour les lecteurs d'écran.
  final String semanticsLabel;

  /// Clé de test de chaque pastille.
  final Key Function(T value)? keyOf;
  final Key? sliderKey;

  static const double _small = 60;
  static const double _big = 104;
  static const double _sliderHeight = 76;
  static const double _sliderMargin = 28;
  static const double _sliderSag = 40;

  /// Distance entre le cran du curseur et le centre de sa pastille, le long
  /// de la normale à l'arc : les pastilles suivent la courbe, au-dessus.
  static const double _lift = 84;

  /// Hauteur réservée aux pastilles au-dessus du curseur.
  static const double _zone = _lift + _big / 2 - 4;

  /// La fraction d'arc du cran [i] : les crans sont au milieu de parts
  /// égales, jamais aux bouts — une grande pastille au bord sortirait de
  /// l'écran.
  double _stop(double i) => (i + 0.5) / values.length;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final geometry = _ArcGeometry(width);
        return TweenAnimationBuilder<double>(
          tween: Tween(end: index.toDouble()),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, position, _) => SizedBox(
            width: width,
            height: _zone + _sliderHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: _zone,
                  height: _sliderHeight,
                  child: _slider(context, geometry, position, index),
                ),
                // **Les pastilles ne bougent pas** : chacune reste au-dessus
                // de son cran, et c'est sa taille qui suit la poignée. Le
                // choix se peint en dernier, donc par-dessus ses voisines.
                for (final i in _paintOrder(position))
                  _placed(i, position, geometry),
              ],
            ),
          ),
        );
      },
    );
  }

  List<int> _paintOrder(double position) =>
      List.generate(values.length, (i) => i)
        ..sort((a, b) => (b - position).abs().compareTo((a - position).abs()));

  Widget _placed(int i, double position, _ArcGeometry geometry) {
    final distance = (i - position).abs();
    final grow = (1 - distance).clamp(0.0, 1.0);
    final size = _small + (_big - _small) * grow;
    final onArc = geometry.pointAt(_stop(i.toDouble()));
    final normal = (onArc - geometry.center) / geometry.radius;
    final center = onArc + normal * _lift + const Offset(0, _zone);
    final value = values[i];

    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: _Pastille(
        key: keyOf?.call(value),
        size: size,
        glyph: (size) => iconOf(value, size),
        label: labelOf(value),
        labelOpacity: (grow * 2 - 1).clamp(0.0, 1.0),
        selected: value == selected,
        onTap: () => onSelected(value),
      ),
    );
  }

  Widget _slider(
    BuildContext context,
    _ArcGeometry geometry,
    double position,
    int index,
  ) {
    final palette = context.palette;
    final last = values.length - 1;

    void selectAt(Offset local) {
      final f = geometry.fractionAt(local);
      final i = (f * values.length - 0.5).round().clamp(0, last);
      if (i != index) onSelected(values[i]);
    }

    return Semantics(
      container: true,
      slider: true,
      label: semanticsLabel,
      value: labelOf(selected),
      increasedValue: index < last ? labelOf(values[index + 1]) : null,
      decreasedValue: index > 0 ? labelOf(values[index - 1]) : null,
      onIncrease: index < last ? () => onSelected(values[index + 1]) : null,
      onDecrease: index > 0 ? () => onSelected(values[index - 1]) : null,
      child: GestureDetector(
        key: sliderKey,
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => selectAt(details.localPosition),
        onHorizontalDragStart: (details) => selectAt(details.localPosition),
        onHorizontalDragUpdate: (details) => selectAt(details.localPosition),
        child: CustomPaint(
          size: Size(geometry.width, _sliderHeight),
          painter: _ArcPainter(
            geometry: geometry,
            fraction: _stop(position),
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
  _ArcGeometry(this.width)
      : center = Offset(
          width / 2,
          QualityArc._sliderMargin / 2 + _radiusFor(width),
        ),
        radius = _radiusFor(width),
        halfAngle = math.asin(_chord(width) / 2 / _radiusFor(width));

  static double _chord(double width) => width - 2 * QualityArc._sliderMargin;

  /// Le rayon du cercle qui passe par les deux bouts de la corde et par le
  /// sommet, [QualityArc._sliderSag] plus haut.
  static double _radiusFor(double width) {
    final half = _chord(width) / 2;
    const sag = QualityArc._sliderSag;
    return (half * half + sag * sag) / (2 * sag);
  }

  final double width;
  final Offset center;
  final double radius;
  final double halfAngle;

  Offset pointAt(double fraction) {
    final phi = -halfAngle + 2 * halfAngle * fraction;
    return center + Offset(radius * math.sin(phi), -radius * math.cos(phi));
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

  static const double _stroke = 14;

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
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final dash = 5 / geometry.radius;
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
    canvas.drawCircle(handle, 15, Paint()..color = Colors.white);
    canvas.drawCircle(
      handle,
      15,
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
    required this.glyph,
    required this.label,
    required this.labelOpacity,
    required this.selected,
    required this.onTap,
  });

  final double size;
  final Widget Function(double size) glyph;
  final String label;
  final double labelOpacity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Le choix porte son nom DANS sa bulle, sous le pictogramme : le rond
    // plein rétrécit et remonte à mesure que le nom paraît.
    final inner = size * (0.64 - 0.14 * labelOpacity);
    final lift = size * 0.12 * labelOpacity;

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
                  color: palette.surface.withValues(alpha: 0.55),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.9),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment(0, -lift / (size / 2)),
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
                child: Center(child: glyph(inner * 0.5)),
              ),
            ),
            if (labelOpacity > 0)
              Positioned(
                bottom: size * 0.14,
                left: 4,
                right: 4,
                child: Opacity(
                  opacity: labelOpacity,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
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

/// **Trois barres de signal, dont [level] pleines** — le pictogramme des
/// paliers fixes. Les icônes Material d'une seule barre se lisent comme un
/// point à cette taille ; ici les barres vides restent visibles en filigrane,
/// et « une sur trois » se comprend d'un coup d'œil.
class SignalLevelGlyph extends StatelessWidget {
  const SignalLevelGlyph({super.key, required this.level, required this.size});

  /// 1, 2 ou 3.
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _SignalPainter(level),
      );
}

class _SignalPainter extends CustomPainter {
  _SignalPainter(this.level);

  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = size.width * 0.22;
    final gap = (size.width - 3 * bar) / 2;
    for (var i = 0; i < 3; i++) {
      final height = size.height * (0.4 + 0.3 * i);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (bar + gap),
          size.height - height,
          bar,
          height,
        ),
        Radius.circular(bar / 3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: i < level ? 1 : 0.32),
      );
    }
  }

  @override
  bool shouldRepaint(_SignalPainter old) => old.level != level;
}
