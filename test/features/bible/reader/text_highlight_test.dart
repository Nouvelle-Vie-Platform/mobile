// Le surlignage suit le texte affiché, au pixel (28/10/2026) : remis en page
// sans le style hérité, il prenait la police par défaut, plus étroite, et ses
// bandes s'arrêtaient avant la fin de chaque ligne.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/reader/text_highlight.dart';

void main() {
  testWidgets('les bandes sont celles du paragraphe, style hérité compris',
      (tester) async {
    const span = TextSpan(
      children: [
        TextSpan(text: '2 ', style: TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(
          text: 'Et tes frères aussi, la tribu de Lévi, tribu de ton père, '
              'fais-les approcher de toi.',
        ),
      ],
    );
    final end = span.toPlainText().length;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            // Ce que le lecteur hérite et que le span ne dit pas.
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 18, letterSpacing: 3),
              child: const TextHighlight(
                color: Colors.green,
                span: span,
                from: 0,
                to: 1000,
                child: Text.rich(span),
              ),
            ),
          ),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    final shown = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: end),
    );
    final highlight = tester.widget<TextHighlight>(find.byType(TextHighlight));
    final painted = highlight.boxesIn(
      tester.element(find.byType(TextHighlight)),
      paragraph.size.width,
    );

    expect(shown.length, greaterThan(1), reason: 'plusieurs lignes');
    expect(painted.map((b) => b.toRect()), shown.map((b) => b.toRect()));
  });
}
