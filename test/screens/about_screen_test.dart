import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/app_version.dart';
import 'package:maison_du_miracle/data/repositories/legal_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/about_screen.dart';
import 'package:maison_du_miracle/state/app_version_providers.dart';
import 'package:maison_du_miracle/state/legal_providers.dart';
import 'package:maison_du_miracle/theme/app_palette.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/brand_logo.dart';
import 'package:maison_du_miracle/widgets/content_absence.dart';
import 'package:maison_du_miracle/widgets/legal_document_body.dart';

import '../helpers/pump_screen.dart';

/// L'écran « À propos » — `/about`.
///
/// Ce qui se vérifie ici est le **partage** entre les deux moitiés de l'écran :
/// l'entête est local et ne dépend de rien, le corps vient du portail et peut
/// manquer. Un écran qui masquerait tout devant un magasin vide passerait
/// pourtant l'essentiel des autres tests de ce dossier.

const _fixedVersion = AppVersionInfo(version: '1.0.0', build: '1');

LegalDocument _about({List<LegalSection>? sections}) => LegalDocument(
      kind: LegalDocumentKind.about,
      version: 2,
      sections: sections ??
          const [
            LegalSection(
              key: 'mission',
              heading: {'fr': 'Notre mission'},
              body: {'fr': 'Annoncer la **bonne nouvelle**.'},
            ),
          ],
    );

void main() {
  Future<void> pumpAbout(
    WidgetTester tester, {
    List<LegalDocument> documents = const [],
    AppVersionInfo? version = _fixedVersion,
  }) =>
      pumpScreen(
        tester,
        const AboutScreen(),
        overrides: [
          legalRepositoryProvider.overrideWithValue(
            InMemoryLegalRepository(documents: documents),
          ),
          appVersionReaderProvider.overrideWithValue(
            FixedAppVersionReader(version),
          ),
        ],
      );

  group('L\'entête local', () {
    testWidgets(
      'il s\'affiche SANS document en magasin — seul le corps manque',
      (tester) async {
        // C'est le seul des trois écrans documentaires qui ait quelque chose à
        // montrer sans le serveur. « Pas de contenu, pas de section », jamais
        // « pas de contenu, pas d'écran ».
        await pumpAbout(tester);

        expect(find.byKey(AboutScreen.headerKey), findsOneWidget);
        expect(find.byType(BrandLogo), findsOneWidget);
        expect(find.text('Église Évangélique Nouvelle Vie'), findsOneWidget);
        expect(find.text('Version 1.0.0 (1)'), findsOneWidget);

        // Seul le corps manque, et il manque en silence : pas d'écran
        // d'absence, l'écran n'est pas vide.
        expect(find.byType(LegalDocumentBody), findsNothing);
        expect(find.byType(ContentAbsenceView), findsNothing);
      },
    );

    testWidgets('la version vient du lecteur, jamais d\'une constante', (
      tester,
    ) async {
      // Le numéro décrit le binaire installé : il ne peut venir ni du serveur
      // ni d'une chaîne écrite dans le source.
      await pumpAbout(
        tester,
        version: const AppVersionInfo(version: '2.4.1', build: '187'),
      );

      expect(find.text('Version 2.4.1 (187)'), findsOneWidget);
      expect(find.text('Version 1.0.0 (1)'), findsNothing);
    });

    testWidgets('version inconnaissable : la ligne disparaît, pas l\'écran', (
      tester,
    ) async {
      // Le lecteur rend `null` quand le canal de plugin ne répond pas. Une
      // absence se dessine comme une absence — jamais « Version inconnue »,
      // qui ressemblerait à une donnée.
      await pumpAbout(tester, version: null);

      expect(find.byKey(AboutScreen.versionKey), findsNothing);
      expect(find.byKey(AboutScreen.headerKey), findsOneWidget);
      expect(find.textContaining('Version'), findsNothing);
    });
  });

  group('Le corps servi', () {
    testWidgets('il se rend par `LegalDocumentBody`, sous l\'entête', (
      tester,
    ) async {
      await pumpAbout(tester, documents: [_about()]);

      expect(find.byType(LegalDocumentBody), findsOneWidget);
      expect(find.text('Notre mission'), findsOneWidget);
      // L'entête ne s'efface pas devant le corps : les deux cohabitent.
      expect(find.byKey(AboutScreen.headerKey), findsOneWidget);
      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    });

    testWidgets('l\'écran lit le genre `about`, pas un autre', (tester) async {
      await pumpAbout(
        tester,
        documents: [
          LegalDocument(
            kind: LegalDocumentKind.terms,
            version: 1,
            sections: const [
              LegalSection(
                key: 'objet',
                heading: {'fr': 'Objet'},
                body: {'fr': 'Le service.'},
              ),
            ],
          ),
          _about(),
        ],
      );

      expect(find.text('Notre mission'), findsOneWidget);
      expect(find.text('Objet'), findsNothing);
    });

    testWidgets('aucune case à cocher, aucune mention d\'acceptation', (
      tester,
    ) async {
      // `about` n'entre jamais dans la barrière (#56) : accepter une
      // présentation n'a pas de sens.
      await pumpAbout(tester, documents: [_about()]);

      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.textContaining('accepte'), findsNothing);
    });
  });

  group('Les renvois', () {
    testWidgets('« CGU » pousse /legal/cgu', (tester) async {
      await _pumpRouted(tester);

      await tester.tap(find.byKey(AboutScreen.termsLinkKey));
      await tester.pumpAndSettle();

      expect(find.text('destination cgu'), findsOneWidget);
    });

    testWidgets('« Politique de confidentialité » pousse /legal/privacy', (
      tester,
    ) async {
      await _pumpRouted(tester);

      await tester.tap(find.byKey(AboutScreen.privacyLinkKey));
      await tester.pumpAndSettle();

      expect(find.text('destination privacy'), findsOneWidget);
    });
  });

  testWidgets('l\'écran est lisible en thème sombre', (tester) async {
    // Aucune couleur en dur : les textes suivent la palette. Un texte noir sur
    // fond sombre passerait tous les tests de contenu ci-dessus.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalRepositoryProvider.overrideWithValue(
            InMemoryLegalRepository(documents: [_about()]),
          ),
          appVersionReaderProvider.overrideWithValue(
            const FixedAppVersionReader(_fixedVersion),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const AboutScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final nom = tester.widget<Text>(
      find.text('Église Évangélique Nouvelle Vie'),
    );
    final version = tester.widget<Text>(find.text('Version 1.0.0 (1)'));

    // Le contraste, et non la seule luminance : la ligne de version est un
    // texte secondaire, volontairement plus discret que le nom. Ce qui doit
    // tenir est qu'elle reste lisible sur le fond sombre.
    expect(_contrast(nom.style!.color!, AppPalette.dark.background),
        greaterThan(4.5));
    expect(_contrast(version.style!.color!, AppPalette.dark.background),
        greaterThan(4.5));
  });
}

/// Rapport de contraste WCAG entre deux couleurs opaques.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (clair, sombre) = la > lb ? (la, lb) : (lb, la);
  return (clair + 0.05) / (sombre + 0.05);
}

/// Monte « À propos » dans un routeur minimal qui porte la route nommée
/// `AppRoute.legalDocument`, pour prouver que les renvois poussent bien
/// `/legal/:kind` — et avec le bon genre.
Future<void> _pumpRouted(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(
        name: AppRoute.legalDocument,
        path: '/legal/:kind',
        builder: (_, state) =>
            Scaffold(body: Text('destination ${state.pathParameters['kind']}')),
      ),
    ],
    initialLocation: '/about',
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        legalRepositoryProvider.overrideWithValue(
          InMemoryLegalRepository(documents: const []),
        ),
        appVersionReaderProvider.overrideWithValue(
          const FixedAppVersionReader(_fixedVersion),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
