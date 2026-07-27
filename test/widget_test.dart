import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maison_du_miracle/app.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';

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

  testWidgets('Le 401 global est câblé au montage de l\'app', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(() => ApiClient.instance.onUnauthorized = null);

    expect(ApiClient.instance.onUnauthorized, isNull);

    await tester.pumpWidget(const ProviderScope(child: MaisonDuMiracleApp()));
    await tester.pump();

    // `ApiClient` ignore Riverpod et go_router : c'est l'app qui lui fournit
    // la réaction au 401 (repasser l'état d'auth à « déconnecté »).
    expect(ApiClient.instance.onUnauthorized, isNotNull);

    await tester.pump(const Duration(milliseconds: 400));
  });
}
