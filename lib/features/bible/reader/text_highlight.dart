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
/// ou quelques mots (#252). Le paragraphe est remis en page **comme `Text`
/// le fait** — style hérité compris : sans lui, la police par défaut du
/// système, plus étroite, donnait des bandes qui s'arrêtaient avant la fin
/// de chaque ligne (constaté le 28/10/2026).
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

  /// Le paragraphe tel que `Text.rich` le met en page sous [context] : style
  /// hérité fusionné, gras d'accessibilité, échelle, interligne.
  static TextPainter _painterFor(BuildContext context, InlineSpan span) {
    final inherited = DefaultTextStyle.of(context);
    var style = inherited.style;
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return TextPainter(
      text: TextSpan(style: style, children: [span]),
      textAlign: inherited.textAlign ?? TextAlign.start,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textWidthBasis: inherited.textWidthBasis,
      textHeightBehavior: inherited.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
  }

  /// Les rectangles surlignés pour un paragraphe large de [width] — ceux que
  /// le peintre remplit.
  @visibleForTesting
  List<TextBox> boxesIn(BuildContext context, double width) {
    final painter = _painterFor(context, span)..layout(maxWidth: width);
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: from, extentOffset: to),
    );
    painter.dispose();
    return boxes;
  }

  @override
  Widget build(BuildContext context) {
    final c = color;
    if (c == null || to <= from) return child;
    return CustomPaint(
      painter: _HighlightPainter(c, (width) => boxesIn(context, width)),
      child: child,
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter(this.color, this.boxes);

  final Color color;
  final List<TextBox> Function(double width) boxes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final box in boxes(size.width)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          box.toRect().inflate(1),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  // La fonction change à chaque construction : on repeint avec le widget.
  @override
  bool shouldRepaint(_HighlightPainter old) => true;
}
