import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/theme/app_responsive.dart';

const _key = Key('contenu');

/// Monte [child] à une **taille logique** donnée, densité 1 pour que les
/// nombres tombent juste.
Future<void> _pumpAt(WidgetTester tester, Size logical, Widget child) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logical;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ContentMaxWidth', () {
    testWidgets('téléphone : aucune marge, l\'enfant reste à pleine largeur',
        (tester) async {
      await _pumpAt(
        tester,
        const Size(400, 800),
        const ContentMaxWidth(child: SizedBox.expand(key: _key)),
      );

      expect(tester.getSize(find.byKey(_key)).width, 400);
      expect(tester.getTopLeft(find.byKey(_key)).dx, 0);
    });

    testWidgets('grand écran : contenu borné et centré', (tester) async {
      await _pumpAt(
        tester,
        const Size(1200, 800),
        const ContentMaxWidth(child: SizedBox.expand(key: _key)),
      );

      expect(
        tester.getSize(find.byKey(_key)).width,
        AppBreakpoints.contentMaxWidth,
      );
      expect(
        tester.getTopLeft(find.byKey(_key)).dx,
        (1200 - AppBreakpoints.contentMaxWidth) / 2,
      );
    });

    testWidgets('au seuil exact, la marge ne se déclenche pas', (tester) async {
      await _pumpAt(
        tester,
        const Size(840, 800),
        const ContentMaxWidth(child: SizedBox.expand(key: _key)),
      );

      expect(tester.getSize(find.byKey(_key)).width, 840);
      expect(tester.getTopLeft(find.byKey(_key)).dx, 0);
    });
  });
}
