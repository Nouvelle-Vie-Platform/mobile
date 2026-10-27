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
///
/// **Au mot** (#252), c'est l'**étendue** qui change, pas le dessin :
/// [MarkerWordHighlight] peint les mêmes bandes dentelées, mais une par
/// rectangle que le texte occupe réellement — `getBoxesForSelection` les
/// donne, une par ligne traversée. L'interligne déduite ne suffisait plus :
/// un mot commence et finit quelque part sur sa ligne.
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

/// Peint le trait de marqueur derrière **quelques mots** de [span] (#252) :
/// de [from] (comprise) à [to] (**exclue**), décalages de caractère dans le
/// paragraphe — numéro de verset compris, puisqu'il en fait partie.
///
/// À poser autour du `Text` **lui-même** et de rien d'autre : le peintre
/// refait la mise en page du paragraphe à la largeur qu'on lui donne, et un
/// `Row` autour (lettrine, icônes de marge) la fausserait. C'est aussi pour
/// cela qu'il reçoit le même [InlineSpan] que le `Text`, et non le texte brut.
class MarkerWordHighlight extends StatelessWidget {
  const MarkerWordHighlight({
    super.key,
    required this.color,
    required this.span,
    required this.from,
    required this.to,
    required this.child,
  });

  final Color? color;
  final InlineSpan span;
  final int from;
  final int to;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = color;
    if (c == null || to <= from) return child;
    return CustomPaint(
      painter: _MarkerPainter(
        c,
        0,
        0,
        words: (
          span: span,
          from: from,
          to: to,
          // La même échelle que le `Text`, qui la prend là aussi : sans elle
          // un réglage d'accessibilité décalait les bandes d'un mot.
          scaler: MediaQuery.textScalerOf(context),
        ),
      ),
      child: child,
    );
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter(this.color, this.lineHeight, this.top, {this.words});

  final Color color;
  final double lineHeight;
  final double top;

  /// Posé par [MarkerWordHighlight] : le paragraphe entier et les bornes du
  /// surlignage **dedans** ([to] exclue). Nul, le trait couvre chaque ligne
  /// d'un bord à l'autre, comme depuis #250.
  final ({InlineSpan span, int from, int to, TextScaler scaler})? words;

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
  Path _band(double left, double width, double y, double height, int seed) {
    const steps = 14;
    const tail = 0.16;
    double top(int s) {
      final x = s / steps;
      final edge = height * 0.13 * _noise(seed, s);
      final out = x <= 1 - tail ? 0.0 : (x - (1 - tail)) / tail;
      return y + edge + (height * 0.86 - edge) * out * out;
    }

    double bottom(int s) => y + height * (0.82 + 0.18 * _noise(seed, s + 31));

    final path = Path()..moveTo(left, top(0));
    for (var s = 1; s <= steps; s++) {
      path.lineTo(left + width * s / steps, top(s));
    }
    for (var s = steps; s >= 0; s--) {
      path.lineTo(left + width * s / steps, bottom(s));
    }
    return path..close();
  }

  /// Les deux passages d'un trait, de [left] sur [width] : le second plus
  /// court et décalé, pour que les deux translucides se superposent et donnent
  /// les traînées d'encre inégale des références.
  void _stroke(
    Canvas canvas,
    Paint paint,
    double left,
    double width,
    double y,
    double height,
    int seed,
  ) {
    canvas.drawPath(_band(left, width, y, height, seed), paint);
    canvas.drawPath(
      _band(left, width * (0.72 + 0.26 * _noise(seed, 7)), y + height * 0.18,
          height * 0.62, seed + 101),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      // Le feutre ne laisse pas d'arête nette : un flou d'un demi-pixel suffit
      // à ôter l'aspect « forme vectorielle ».
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.7);
    final selection = words;
    if (selection != null) {
      // **Au mot** : le texte dit lui-même où il se trouve. Même mise en page
      // que le `Text` au-dessus (même `InlineSpan`, même largeur, même échelle
      // de police), donc les mêmes rectangles — un par ligne traversée.
      final painter = TextPainter(
        text: selection.span,
        textDirection: TextDirection.ltr,
        textScaler: selection.scaler,
      )..layout(maxWidth: size.width);
      final boxes = painter.getBoxesForSelection(
        TextSelection(
          baseOffset: selection.from,
          extentOffset: selection.to,
        ),
      );
      for (final (i, box) in boxes.indexed) {
        _stroke(canvas, paint, box.left, box.right - box.left, box.top,
            box.bottom - box.top, i);
      }
      painter.dispose();
      return;
    }
    final lines = (size.height - top) ~/ lineHeight;
    for (var i = 0; i <= lines; i++) {
      final y = top + i * lineHeight;
      if (y + lineHeight * 0.4 > size.height) break;
      _stroke(canvas, paint, 0, size.width, y, lineHeight, i);
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.color != color ||
      old.lineHeight != lineHeight ||
      old.top != top ||
      old.words != words;
}
