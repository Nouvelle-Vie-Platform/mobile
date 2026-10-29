import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';

import '../helpers/pump_screen.dart';

final _fr = AppLocalizationsFr();

/// **Une base illisible n'est pas un réseau absent**, et l'accueil disait
/// pourtant « vérifiez votre connexion internet » dans les deux cas.
///
/// Les quatre lectures de `_MediathequeHome` viennent du **magasin**, jamais du
/// réseau : leur échec ne se répare par aucun geste de connexion. Le 29/10/2026
/// ce message a coûté une enquête — la base de l'app web ne s'ouvrait pas, et
/// l'écran envoyait le fidèle vérifier son wifi.
///
/// Ce test tient les deux moitiés : la phrase juste **paraît**, et la phrase
/// réseau **ne paraît pas**. La seconde assertion est celle qui compte : c'est
/// elle qui rougirait si quelqu'un remettait le message générique.
void main() {
  testWidgets('une lecture du magasin en échec ne parle pas de connexion',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      const Scaffold(body: HomeScreen()),
      overrides: [
        latestTeachingsProvider.overrideWith(
          (ref) => Stream.error(StateError('base illisible')),
        ),
      ],
    );
    await tester.pump();

    expect(find.text(_fr.stateErrorStoreMessage), findsOneWidget);
    expect(find.text(_fr.stateErrorMessage), findsNothing);
  });
}
