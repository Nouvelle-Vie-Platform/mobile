/// **Le surlignage au marqueur** (#250) : la bande peinte derrière un verset.
///
/// Le rectangle arrondi plat ne rendait pas l'allure des références : ce qu'on
/// y voit est un **trait de marqueur**, bords irréguliers, encre inégale, qui
/// déborde des deux côtés de l'écran. D'où une peinture et non une
/// `BoxDecoration` — la couleur, elle, ne change pas : c'est toujours
/// `bibleHighlightBackground`.
///
/// Le peintre ne sait pas découper le texte en lignes ; il s'appuie sur
/// l'interligne du lecteur, qui est **le même pour tout le verset** (une seule
/// `TextStyle`, numéro compris, et c'est pour cela que le numéro a la taille du
/// texte). Les lignes sont donc déduites de la hauteur, et chaque bande est
/// pleine largeur — comme sur les références, où le trait court jusqu'au bord,
/// quelle que soit la longueur de la phrase.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Peint un trait de marqueur derrière [child], une bande par ligne de texte.
///
/// [color] à `null` : rien n'est peint (et [MarkerHighlight] disparaît de
/// l'arbre — les tests lisent la couleur par ce widget).
class MarkerHighlight extends StatelessWidget {
  const MarkerHighlight({
    super.key,
    required this.color,
    required this.lineHeight,
    required this.padding,
    required this.child,
  });

  final Color? color;

  /// La hauteur d'une ligne de texte (`fontSize × height` du lecteur).
  final double lineHeight;

  /// La marge intérieure : le peintre doit savoir où commence la première
  /// ligne, et la bande, elle, déborde jusqu'aux bords.
  final EdgeInsets padding;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = color;
    final inner = Padding(padding: padding, child: child);
    if (c == null) return inner;
    return CustomPaint(
      painter: _MarkerPainter(c, lineHeight, padding.top),
      child: inner,
    );
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter(this.color, this.lineHeight, this.top);

  final Color color;
  final double lineHeight;
  final double top;

  /// Un bruit stable : la même bande est repeinte à l'identique d'une image à
  /// l'autre (sinon le trait grésillait à chaque défilement).
  double _noise(int a, int b) {
    final v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// Le contour d'une bande : bord haut à peine ondulé, bord bas franchement
  /// dentelé, et une **sortie de feutre** — sur les derniers pour-cent de la
  /// largeur le haut plonge vers le bas, sans quoi la bande se terminait sur
  /// une arête verticale nette qui trahissait la forme vectorielle.
  Path _band(double width, double y, double height, int seed) {
    const steps = 14;
    const tail = 0.16;
    double top(int s) {
      final x = s / steps;
      final edge = height * 0.13 * _noise(seed, s);
      final out = x <= 1 - tail ? 0.0 : (x - (1 - tail)) / tail;
      return y + edge + (height * 0.86 - edge) * out * out;
    }

    double bottom(int s) => y + height * (0.82 + 0.18 * _noise(seed, s + 31));

    final path = Path()..moveTo(0, top(0));
    for (var s = 1; s <= steps; s++) {
      path.lineTo(width * s / steps, top(s));
    }
    for (var s = steps; s >= 0; s--) {
      path.lineTo(width * s / steps, bottom(s));
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lines = (size.height - top) ~/ lineHeight;
    final paint = Paint()
      ..color = color
      // Le feutre ne laisse pas d'arête nette : un flou d'un demi-pixel suffit
      // à ôter l'aspect « forme vectorielle ».
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.7);
    for (var i = 0; i <= lines; i++) {
      final y = top + i * lineHeight;
      if (y + lineHeight * 0.4 > size.height) break;
      canvas.drawPath(_band(size.width, y, lineHeight, i), paint);
      // Un second passage, plus court et décalé : les deux translucides se
      // superposent et donnent les traînées d'encre inégale des références.
      canvas.drawPath(
        _band(size.width * (0.72 + 0.26 * _noise(i, 7)), y + lineHeight * 0.18,
            lineHeight * 0.62, i + 101),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.color != color || old.lineHeight != lineHeight || old.top != top;
}
