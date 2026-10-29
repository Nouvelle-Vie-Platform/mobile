/// **Le bandeau d'installation de l'app web** — et surtout : les cas où il ne
/// paraît pas.
///
/// Il n'est pas décoratif. Sans installation, Chrome n'accorde pas le stockage
/// durable — mesuré le 29/10/2026 sur un Android 6 / Chrome 106 :
/// `navigator.storage.persist()` répond *non* avant, *oui* après —, donc pas de
/// téléchargement hors ligne. Ce bandeau est le seul endroit de l'application
/// qui propose l'installation, Chrome ayant rangé la sienne dans un menu que
/// personne n'ouvre.
///
/// Quatre règles y sont verrouillées : rien à offrir ⇒ rien ; une offre
/// *prompt* donne un bouton qui ouvre vraiment la boîte du navigateur ; iOS
/// n'a **pas** de bouton (Safari n'offre aucune boîte, et un bouton qui
/// n'ouvre rien est une promesse que personne ne tient) ; et une offre qui
/// arrive **après** le démarrage fait paraître le bandeau — c'est le cas réel,
/// `beforeinstallprompt` étant émis quand Chrome le décide.
///
/// S'y ajoute depuis #283 **le moment de la permission d'annonces** : dans la
/// foulée d'une installation acceptée, et à ce moment-là seulement.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/install/install_prompt.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/state/install_providers.dart';
import 'package:maison_du_miracle/state/push_providers.dart';
import 'package:maison_du_miracle/widgets/install_banner.dart';

import '../helpers/pump_screen.dart';

final _fr = AppLocalizationsFr();

/// Un double pilotable : l'offre de départ, puis celles qu'on pousse.
class FakeInstallPrompt implements InstallPrompt {
  FakeInstallPrompt(this._offer, {this.accepts = false});

  InstallOffer _offer;
  final StreamController<InstallOffer> _changes =
      StreamController<InstallOffer>.broadcast();

  /// Ce que le navigateur répond à la boîte d'installation.
  final bool accepts;

  /// Ce que `show()` a reçu, pour prouver que le bouton atteint bien le
  /// navigateur et ne se contente pas de fermer le bandeau.
  int shown = 0;

  @override
  InstallOffer get offer => _offer;

  @override
  Stream<InstallOffer> get changes => _changes.stream;

  @override
  Future<bool> show() async {
    shown++;
    return accepts;
  }

  /// L'arrivée tardive de `beforeinstallprompt`.
  void emit(InstallOffer offer) {
    _offer = offer;
    _changes.add(offer);
  }
}

/// Le compteur de demandes de permission — le double de ce que `main.dart`
/// surcharge sur le web.
class AskCounter {
  int asked = 0;

  Future<void> call() async => asked++;
}

Future<FakeInstallPrompt> pumpBanner(
  WidgetTester tester, {
  InstallOffer offer = InstallOffer.none,
  bool accepts = false,
  AskCounter? permission,
}) async {
  final prompt = FakeInstallPrompt(offer, accepts: accepts);
  await pumpScreen(
    tester,
    const Scaffold(body: InstallBanner()),
    overrides: [
      installPromptProvider.overrideWithValue(prompt),
      if (permission != null)
        pushPermissionProvider.overrideWithValue(permission.call),
    ],
  );
  return prompt;
}

void main() {
  testWidgets('rien à offrir : aucun bandeau — le cas du mobile natif',
      (tester) async {
    await pumpBanner(tester);

    expect(find.byKey(InstallBanner.bannerKey), findsNothing);
    expect(find.text(_fr.installBannerBody), findsNothing);
  });

  testWidgets(
      'une invite disponible : le bandeau dit pourquoi, et le bouton '
      'ouvre la boîte du navigateur', (tester) async {
    final prompt = await pumpBanner(tester, offer: InstallOffer.prompt);

    expect(find.byKey(InstallBanner.bannerKey), findsOneWidget);
    expect(find.text(_fr.installBannerBody), findsOneWidget);

    await tester.tap(find.byKey(InstallBanner.actionKey));
    await tester.pump();

    expect(prompt.shown, 1);
    // Le bandeau reste : c'est l'offre qui retombera à `none` une fois
    // l'installation faite, et un refus ne change rien.
    expect(find.byKey(InstallBanner.bannerKey), findsOneWidget);
  });

  testWidgets('sur iPhone : le geste est expliqué, et il n\'y a PAS de bouton',
      (tester) async {
    await pumpBanner(tester, offer: InstallOffer.manualIos);

    expect(find.byKey(InstallBanner.bannerKey), findsOneWidget);
    expect(find.text(_fr.installBannerIosBody), findsOneWidget);
    expect(find.text(_fr.installBannerBody), findsNothing);
    // Absence, jamais grisage : Safari n'offre aucune boîte à déclencher.
    expect(find.byKey(InstallBanner.actionKey), findsNothing);
  });

  testWidgets('l\'invite arrivée APRÈS le démarrage fait paraître le bandeau',
      (tester) async {
    final prompt = await pumpBanner(tester);
    expect(find.byKey(InstallBanner.bannerKey), findsNothing);

    prompt.emit(InstallOffer.prompt);
    // Deux images : la première laisse l'événement du flux atteindre le
    // provider, la seconde repeint le bandeau avec la nouvelle offre.
    await tester.pump();
    await tester.pump();

    expect(find.byKey(InstallBanner.bannerKey), findsOneWidget);
  });

  testWidgets('« plus tard » le ferme, et il ne revient pas dans la session',
      (tester) async {
    final prompt = await pumpBanner(tester, offer: InstallOffer.prompt);

    await tester.tap(find.byKey(InstallBanner.dismissKey));
    await tester.pump();
    expect(find.byKey(InstallBanner.bannerKey), findsNothing);

    // Même une offre renouvelée ne le rouvre pas : « plus tard » est un choix,
    // pas un report jusqu'au prochain événement.
    prompt.emit(InstallOffer.prompt);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(InstallBanner.bannerKey), findsNothing);
  });

  group('la permission d\'annonces, dans la foulée de l\'installation (#283)',
      () {
    testWidgets('installation acceptée : la permission est demandée',
        (tester) async {
      final permission = AskCounter();
      final prompt = await pumpBanner(
        tester,
        offer: InstallOffer.prompt,
        accepts: true,
        permission: permission,
      );

      await tester.tap(find.byKey(InstallBanner.actionKey));
      await tester.pump();

      expect(prompt.shown, 1);
      expect(
        permission.asked,
        1,
        reason:
            'c\'est l\'instant de plus forte intention, et le seul : sur le '
            'web un refus de notification est quasi définitif',
      );
    });

    testWidgets('installation refusée : on ne demande RIEN', (tester) async {
      final permission = AskCounter();
      final prompt = await pumpBanner(
        tester,
        offer: InstallOffer.prompt,
        permission: permission,
      );

      await tester.tap(find.byKey(InstallBanner.actionKey));
      await tester.pump();

      expect(prompt.shown, 1);
      expect(
        permission.asked,
        0,
        reason: 'enchaîner une seconde boîte sur un refus brûlerait l\'unique '
            'chance d\'obtenir la permission',
      );
    });

    testWidgets(
        'sans push sur cette plateforme : le bouton installe quand même',
        (tester) async {
      // Le cas du mobile natif et de tout test : `pushPermissionProvider` rend
      // `null`, et l'installation ne doit pas en dépendre.
      final prompt = await pumpBanner(
        tester,
        offer: InstallOffer.prompt,
        accepts: true,
      );

      await tester.tap(find.byKey(InstallBanner.actionKey));
      await tester.pump();

      expect(prompt.shown, 1);
    });
  });
}
