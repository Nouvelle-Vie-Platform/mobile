/// **Le surlignage** : un fond droit derrière le texte, ligne par ligne,
/// comme un surligneur.
///
/// Il a été un trait de marqueur peint, bords dentelés et encre inégale
/// (#250) ; le 28/10/2026 l'utilisateur n'en a plus voulu : « juste un
/// surlignage normal ». La couleur, elle, ne change pas : c'est toujours
/// `bibleHighlightBackground`.
///
/// L'étendue vient du texte lui-même : `getBoxesForSelection` donne un
/// rectangle par ligne traversée, que le surlignage couvre le verset entier
/// ou quelques mots (#252).
library;

import 'package:flutter/material.dart';

/// Peint un fond derrière une partie de [span] : de [from] (comprise) à [to]
/// (**exclue**), décalages de caractère dans le paragraphe — numéro de verset
/// compris, puisqu'il en fait partie.
///
/// À poser autour du `Text` **lui-même** et de rien d'autre : le peintre
/// refait la mise en page du paragraphe à la largeur qu'on lui donne, et un
/// `Row` autour (lettrine, icônes de marge) la fausserait. C'est aussi pour
/// cela qu'il reçoit le même [InlineSpan] que le `Text`, et non le texte brut.
class TextHighlight extends StatelessWidget {
  const TextHighlight({
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
      painter: _HighlightPainter(
        c,
        span,
        from,
        to,
        // La même échelle que le `Text`, qui la prend là aussi : sans elle
        // un réglage d'accessibilité décalait le fond d'un mot.
        MediaQuery.textScalerOf(context),
      ),
      child: child,
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter(
      this.color, this.span, this.from, this.to, this.scaler);

  final Color color;
  final InlineSpan span;
  final int from;
  final int to;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    // Même mise en page que le `Text` au-dessus (même `InlineSpan`, même
    // largeur, même échelle), donc les mêmes rectangles.
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: size.width);
    final paint = Paint()..color = color;
    for (final box in painter.getBoxesForSelection(
      TextSelection(baseOffset: from, extentOffset: to),
    )) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          box.toRect().inflate(1),
          const Radius.circular(2),
        ),
        paint,
      );
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.color != color ||
      old.span != span ||
      old.from != from ||
      old.to != to ||
      old.scaler != scaler;
}
