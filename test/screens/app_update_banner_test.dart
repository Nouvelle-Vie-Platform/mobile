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
///
/// ## Deux chemins jusqu'au seuil, et les deux sont couverts ici
///
/// Les cas de comparaison se montent en surchargeant
/// `appUpdateThresholdProvider` directement : c'est le bandeau **seul**, et le
/// seuil y est une valeur. Depuis #91 il existe un second chemin, celui de la
/// production : le seuil descend par la collection répliquée
/// `device_settings`, et le provider le lit du magasin. Le groupe
/// « depuis le magasin » monte ce chemin-là par le paramètre nommé
/// [pumpScreen.updateThreshold] — jamais par une seconde surcharge du même
/// provider, que Riverpod 3 refuserait. Le voyage lui-même (manifeste, page,
/// curseur, 404) est gardé par `test/sync/device_settings_collection_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/app_version.dart';
import 'package:maison_du_miracle/data/store_launcher.dart';
import 'package:maison_du_miracle/data/update/app_reloader.dart';
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
/// [reloader] monte le cas du **web** : `appReloaderProvider` rend `null`
/// partout ailleurs, et `kIsWeb` étant une constante de compilation, c'est le
/// seul moyen d'éprouver ce chemin sous `flutter test`.
Future<RecordingStoreLauncher> pumpBanner(
  WidgetTester tester, {
  String? installed = '1.0.0',
  String? threshold,
  AppReloader? reloader,
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
      appReloaderProvider.overrideWithValue(reloader),
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
    // Sans `appUpdateThresholdProvider` surchargé : le provider lit le magasin,
    // et le magasin n'a rien reçu. C'est l'état réel de **tout premier
    // lancement**, et celui d'un serveur en retard d'une version dont la
    // collection a pris un 404. Le seuil est alors absent, et le bandeau se
    // tait — c'est la décision explicite de #80, et #91 ne l'a pas desserrée :
    // il a seulement branché la source.
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

    // Et c'est bien « Mettre à jour » qu'on lit : le libellé du magasin.
    expect(find.text(_fr.appUpdateAction), findsOneWidget);
    expect(find.text(_fr.appUpdateReload), findsNothing);

    await tester.tap(find.byKey(AppUpdateBanner.actionKey));
    await tester.pump();

    expect(launcher.opened, 1);
    // On part vers une autre application et on revient : retrouver
    // l'invitation est juste tant que la mise à jour n'est pas faite.
    expect(find.byKey(AppUpdateBanner.bannerKey), findsOneWidget);
  });

  testWidgets('sur le web, le bouton recharge — et n\'ouvre aucun magasin',
      (tester) async {
    // **Le cœur de la tranche.** Il n'y a pas de magasin dans un navigateur :
    // un bouton qui en ouvrirait un rendrait le seuil réglé au portail sans
    // aucun effet sur l'app web, et un correctif urgent n'y arriverait jamais.
    final reloader = RecordingAppReloader();
    final launcher = await pumpBanner(
      tester,
      installed: '1.0.0',
      threshold: '1.4.0',
      reloader: reloader,
    );

    expect(find.text(_fr.appUpdateReload), findsOneWidget);
    // « Mettre à jour » a disparu : on ne quitte rien, et le dire évite de
    // faire attendre un détour par une autre application.
    expect(find.text(_fr.appUpdateAction), findsNothing);

    await tester.tap(find.byKey(AppUpdateBanner.actionKey));
    await tester.pump();

    expect(reloader.reloaded, 1);
    expect(launcher.opened, 0);
    // Comme ailleurs : le bandeau ne se ferme pas de lui-même. Ici c'est le
    // rechargement qui l'emporte, la version ayant monté.
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

  group('depuis le magasin — le chemin de la production (#91)', () {
    /// Monte le bandeau **sans** surcharger `appUpdateThresholdProvider` : le
    /// seuil arrive par la collection `device_settings`, comme en production.
    ///
    /// [threshold] passe par le paramètre nommé de `pumpScreen`, qui surcharge
    /// le flux du magasin. Une seconde surcharge du même provider serait refusée
    /// par Riverpod 3 — c'est pour ça que ce n'est pas un `Override` de plus.
    Future<void> pumpFromStore(
      WidgetTester tester, {
      required String installed,
      String? threshold,
    }) =>
        pumpScreen(
          tester,
          const Scaffold(body: AppUpdateBanner()),
          updateThreshold: threshold,
          overrides: [
            appVersionReaderProvider.overrideWithValue(
              FixedAppVersionReader(
                AppVersionInfo(version: installed, build: '1'),
              ),
            ),
            storeLauncherProvider.overrideWithValue(RecordingStoreLauncher()),
          ],
        );

    testWidgets('un seuil servi fait paraître le bandeau sous ce seuil',
        (tester) async {
      // Le bandeau était écrit, testé, et ne s'affichait pour personne : son
      // seuil rendait `null` en dur. C'est **ce test-ci** qui prouve que la
      // collection le rouvre.
      await pumpFromStore(tester, installed: '1.0.0', threshold: '1.4.0');

      expect(find.byKey(AppUpdateBanner.bannerKey), findsOneWidget);
      expect(find.text(_fr.appUpdateBody), findsOneWidget);
    });

    testWidgets('et pas au-dessus de ce seuil', (tester) async {
      await pumpFromStore(tester, installed: '1.4.0', threshold: '1.4.0');
      expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);

      await pumpFromStore(tester, installed: '1.10.0', threshold: '1.9.0');
      // La comparaison reste numérique de bout en bout : `1.10.0` est
      // postérieure à `1.9.0`, et le chemin du magasin ne la change pas.
      expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);
    });

    testWidgets('aucun seuil servi : aucun bandeau', (tester) async {
      // Les trois états du serveur qui mènent ici, et ils arrivent pour de
      // vrai : magasin jamais rempli (premier lancement), collection sautée
      // (404 d'un serveur en retard d'une version), seuil retiré au portail. Le
      // repli est le même dans les trois cas, et jamais l'inverse.
      await pumpFromStore(tester, installed: '1.0.0');

      expect(find.byKey(AppUpdateBanner.bannerKey), findsNothing);
      expect(find.text(_fr.appUpdateBody), findsNothing);
    });
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
