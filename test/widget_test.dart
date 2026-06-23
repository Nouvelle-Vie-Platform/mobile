import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maison_du_miracle/app.dart';

void main() {
  testWidgets('L\'application démarre sur le splash', (tester) async {
    // Force la locale française (sinon le test résout l'anglais par défaut).
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      const ProviderScope(child: MaisonDuMiracleApp()),
    );
    await tester.pump();

    // Le splash affiche le nom et la baseline de l'église.
    expect(find.text('Maison du Miracle'), findsWidgets);
  });
}
