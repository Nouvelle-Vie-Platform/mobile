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

    // Au démarrage l'état d'auth est `unknown` → le splash reste affiché et
    // montre le nom de l'église (le `redirect` aiguille ensuite selon l'auth).
    expect(find.text('Maison du Miracle'), findsWidgets);

    // Laisse la résolution de session (currentUser) se terminer pour ne pas
    // laisser de timer en attente ; sans session, l'app file vers /auth.
    await tester.pump(const Duration(milliseconds: 400));
  });
}
