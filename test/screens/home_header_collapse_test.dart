import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/vocabulary.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/widgets/home/radio_cta_pill.dart';

import '../helpers/pump_screen.dart';

/// L'en-tête de l'accueil se replie quand on descend, jusqu'à s'arrêter juste
/// sous le bouton radio, et se déplie dès qu'on remonte (décision du
/// 06/10/2026).
void main() {
  double headerHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(HomeScreen.headerKey)).height;

  double radioBottom(WidgetTester tester) =>
      tester.getBottomLeft(find.byType(RadioCtaPill)).dy;

  Future<void> pumpHome(WidgetTester tester,
      {VocabularyOverrides? vocabulary}) async {
    // Un écran court, pour que la liste de l'accueil défile sans contenu forgé.
    tester.view.physicalSize = const Size(390, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, const Scaffold(body: HomeScreen()),
        vocabulary: vocabulary);
    // La mesure de la hauteur repliée se fait après le premier rendu.
    await tester.pump();
  }

  Future<void> scroll(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(ListView).first, Offset(0, dy));
    await tester.pump();
  }

  testWidgets('au repos, l’en-tête est déplié, avec sa marge sous le bouton',
      (tester) async {
    await pumpHome(tester);
    final height = headerHeight(tester);
    expect(height, 256, reason: 'hauteur du corps, sans barre d’état en test');
    expect(height - radioBottom(tester), greaterThan(40),
        reason: 'la marge où paraît l’église reste sous le bouton');
  });

  testWidgets(
      'une bénédiction de trois lignes, réglée au portail, agrandit l’en-tête',
      (tester) async {
    await pumpHome(
      tester,
      vocabulary: const VocabularyOverrides(labels: {
        'homeBlessing': {
          'fr': 'Que la paix du Seigneur soit avec vous en ce jour, dans vos '
              'maisons, vos familles et vos cœurs, et que sa lumière guide '
              'chacun de vos pas jusqu’au soir.',
        },
      }),
    );
    await tester.pump();

    expect(find.textContaining('Que la paix du Seigneur'), findsOneWidget);
    expect(headerHeight(tester), greaterThan(256),
        reason: 'l’en-tête grandit au lieu de rogner la place de l’église');
    expect(headerHeight(tester) - radioBottom(tester), greaterThan(40),
        reason: 'la marge sous le bouton est gardée');
  });

  testWidgets(
      'descendre le replie jusqu’à juste sous le bouton radio, pas plus',
      (tester) async {
    await pumpHome(tester);
    final expanded = headerHeight(tester);

    await scroll(tester, -40);
    final partial = headerHeight(tester);
    expect(partial, lessThan(expanded));
    expect(partial, closeTo(expanded - 40, 2),
        reason: 'le repli suit le défilement point pour point');

    await scroll(tester, -600);
    final collapsed = headerHeight(tester);
    expect(collapsed, greaterThan(radioBottom(tester)),
        reason: 'le bouton radio reste entièrement visible');
    expect(collapsed - radioBottom(tester), lessThanOrEqualTo(12),
        reason: 'l’en-tête s’arrête juste sous le bouton');

    await scroll(tester, -300);
    expect(headerHeight(tester), collapsed, reason: 'il ne se replie pas plus');
  });

  testWidgets('remonter le déplie aussitôt, où qu’on soit dans la page',
      (tester) async {
    await pumpHome(tester);
    final expanded = headerHeight(tester);
    await scroll(tester, -600);
    final collapsed = headerHeight(tester);
    expect(collapsed, lessThan(expanded));

    // Un petit geste vers le bas, loin du haut de la liste.
    await scroll(tester, 30);
    expect(headerHeight(tester), greaterThan(collapsed),
        reason: 'il commence à se déplier dès qu’on remonte');

    await scroll(tester, 2000);
    expect(headerHeight(tester), expanded,
        reason: 'revenu en haut, il est entièrement déplié');
  });
}
