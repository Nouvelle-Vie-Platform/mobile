/// **Le bandeau de mise à jour** — informatif, fermable, jamais bloquant.
///
/// Ce qu'un test doit rappeler ici, et qui ne se voit nulle part ailleurs :
/// **l'application n'a jamais été publiée**. Tant qu'aucun seuil n'est réglé
/// depuis le portail, ce bandeau ne doit s'afficher pour **personne** — un
/// bandeau « mettez à jour » sur la toute première version serait le plus
/// mauvais premier contact possible, et il n'y aurait même pas de fiche de
/// magasin où aller.
///
/// Quatre règles y sont verrouillées : pas de seuil, pas de bandeau ; sous le
/// seuil, il paraît ; il n'enferme rien ; et il se ferme sans revenir dans la
/// même session.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/app_version.dart';
import 'package:maison_du_miracle/data/store_launcher.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/state/app_update_providers.dart';
import 'package:maison_du_miracle/state/app_version_providers.dart';
import 'package:maison_du_miracle/widgets/app_update_banner.dart';

import '../helpers/pump_screen.dart';

final _fr = AppLocalizationsFr();

/// Monte le bandeau seul, avec la version installée et le seuil qu'on veut.
///
/// `appVersionReaderProvider` et `appUpdateThresholdProvider` passent par
/// `overrides` : aucun des deux n'est posé par `pumpScreen`, il n'y a donc pas
/// de double surcharge — ce que Riverpod 3 refuserait.
Future<RecordingStoreLauncher> pumpBanner(
  WidgetTester tester, {
  String? installed = '1.0.0',
  String? threshold,
}) async {
  final launcher = RecordingStoreLauncher();
  await pumpScreen(
    tester,
    const Scaffold(body: AppUpdateBanner()),
    overrides: [
      appVersionReaderProvider.overrideWithValue(
        FixedAppVersionReader(
          installed == null
              ? null
              : AppVersionInfo(version: installed, build: '1'),
        ),
      ),
      appUpdateThresholdProvider.overrideWithValue(threshold),
      storeLauncherProvider.overrideWithValue(launcher),
    ],
  );
  return launcher;
}

void main() {
  testWidgets('aucun seuil réglé : le bandeau ne s\'affiche pour personne',
      (tester) async {
    await pumpBanner(tester, installed: '1.0.0');

    expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);
    expect(find.text(_fr.appUpdateBody), findsNothing);
  });

  testWidgets('le défaut du dépôt est « aucun seuil » — repli de la tranche',
      (tester) async {
    // Sans `appUpdateThresholdProvider` surchargé : c'est l'état réel de la
    // production tant que la tranche 3 (#81) n'a pas livré la source.
    await pumpScreen(
      tester,
      const Scaffold(body: AppUpdateBanner()),
      overrides: [
        appVersionReaderProvider.overrideWithValue(
          const FixedAppVersionReader(
            AppVersionInfo(version: '1.0.0', build: '1'),
          ),
        ),
      ],
    );

    expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);
  });

  testWidgets('sous le seuil : le bandeau paraît, et il n\'enferme rien',
      (tester) async {
    await pumpBanner(tester, installed: '1.0.0', threshold: '1.4.0');

    expect(find.byKey(AppUpdateBanner.bannerKey), findsOneWidget);
    expect(find.text(_fr.appUpdateBody), findsOneWidget);
    // **Non bloquant, et c'est ce qui le distingue d'une mise à jour forcée** :
    // il n'occupe qu'une bande, il ne couvre pas l'écran, et il porte sa propre
    // sortie. Rien de ce qu'il dessine ne capte un geste hors de sa surface.
    final screen = tester.getSize(find.byType(Scaffold));
    final banner = tester.getSize(find.byKey(AppUpdateBanner.bannerKey));
    expect(banner.height, lessThan(screen.height / 3));
    expect(find.byKey(AppUpdateBanner.dismissKey), findsOneWidget);
    expect(find.byKey(AppUpdateBanner.actionKey), findsOneWidget);
  });

  testWidgets('au seuil ou au-dessus : rien', (tester) async {
    await pumpBanner(tester, installed: '1.4.0', threshold: '1.4.0');
    expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);

    await pumpBanner(tester, installed: '1.10.0', threshold: '1.9.0');
    // `1.10.0` est postérieure à `1.9.0` : la comparaison est numérique, pas
    // alphabétique. L'inverse afficherait un bandeau à qui est déjà à jour.
    expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);
  });

  testWidgets('version locale inconnaissable : rien', (tester) async {
    await pumpBanner(tester, installed: null, threshold: '1.4.0');

    // On n'invite pas à quitter une version qu'on ne sait pas nommer.
    expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);
  });

  testWidgets('seuil illisible : rien', (tester) async {
    await pumpBanner(tester, installed: '1.0.0', threshold: '1.0.0-rc1');

    // Un seuil recopié de travers dans le portail ne décide de rien.
    expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);
  });

  testWidgets('le bouton renvoie au magasin, et ne ferme pas le bandeau',
      (tester) async {
    final launcher =
        await pumpBanner(tester, installed: '1.0.0', threshold: '1.4.0');

    await tester.tap(find.byKey(AppUpdateBanner.actionKey));
    await tester.pump();

    expect(launcher.opened, 1);
    // On part vers une autre application et on revient : retrouver
    // l'invitation est juste tant que la mise à jour n'est pas faite.
    expect(find.byKey(AppUpdateBanner.bannerKey), findsOneWidget);
  });

  testWidgets('il se ferme, et ne revient pas dans la même session',
      (tester) async {
    await pumpBanner(tester, installed: '1.0.0', threshold: '1.4.0');

    await tester.tap(find.byKey(AppUpdateBanner.dismissKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);

    // **Et il ne revient pas** : le seuil n'a pas bougé, la version non plus,
    // et pourtant plus rien ne s'affiche. Une reconstruction ne le ramène pas.
    await tester.pump(const Duration(minutes: 5));
    expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);
  });

  group('la comparaison de versions', () {
    test('compare segment par segment, en nombres', () {
      expect(compareAppVersions('1.9.0', '1.10.0'), isNegative);
      expect(compareAppVersions('1.10.0', '1.9.0'), isPositive);
      expect(compareAppVersions('1.4.0', '1.4.0'), 0);
      // Longueurs inégales : complétées par des zéros.
      expect(compareAppVersions('1.4', '1.4.0'), 0);
      expect(compareAppVersions('1.4', '1.4.1'), isNegative);
      // Le build ne décide de rien : deux builds d'une même version sont le
      // même palier pour quelqu'un qu'on invite à monter.
      expect(compareAppVersions('1.4.0+12', '1.4.0+99'), 0);
    });

    test('rend null sur ce qui ne se compare pas', () {
      expect(compareAppVersions('1.0.0-rc1', '1.4.0'), isNull);
      expect(compareAppVersions('1.4.0', 'bientôt'), isNull);
      expect(compareAppVersions('', '1.4.0'), isNull);
    });
  });
}
