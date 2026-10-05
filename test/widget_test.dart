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
    // montre le **nom de l'application** (le `redirect` aiguille ensuite selon
    // l'auth). C'est `appName`, et non le nom de l'église : l'emblème
    // au-dessus porte déjà celui-ci, gravé dans l'image.
    expect(find.text('Nouvelle Vie'), findsWidgets);

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

  testWidgets(
      'La langue annoncée au serveur est celle que l\'interface a résolue, '
      'et la suit', (tester) async {
    // L'anglais d'abord : le défaut du provider étant le français, un câblage
    // qui ne suivrait pas la résolution passerait inaperçu en français.
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(() {
      ApiClient.instance.onUnauthorized = null;
      ApiClient.instance.interfaceLanguage = null;
    });

    expect(ApiClient.instance.interfaceLanguage, isNull);

    await tester.pumpWidget(const ProviderScope(child: MaisonDuMiracleApp()));
    // Une image pour résoudre la locale, une de plus pour que
    // `_ContentLocaleSync` la recopie (son écriture est différée d'une image).
    await tester.pump();
    await tester.pump();

    expect(ApiClient.instance.interfaceLanguage?.call(), 'en');

    // **Changement de langue en cours de session** : aucun redémarrage, aucun
    // recâblage — le lecteur est relu, et rend la nouvelle résolution.
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    await tester.pump();
    await tester.pump();

    expect(ApiClient.instance.interfaceLanguage?.call(), 'fr');

    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('Le lecteur de langue est débranché au démontage de l\'app',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(() => ApiClient.instance.onUnauthorized = null);

    await tester.pumpWidget(const ProviderScope(child: MaisonDuMiracleApp()));
    await tester.pump();
    expect(ApiClient.instance.interfaceLanguage, isNotNull);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());

    // Un lecteur resté branché sur un conteneur détruit lèverait à chaque
    // requête — rattrapé, mais pour rien.
    expect(ApiClient.instance.interfaceLanguage, isNull);
  });
}
