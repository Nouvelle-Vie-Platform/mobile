import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/legal_acceptance_recorder.dart';
import 'package:maison_du_miracle/data/repositories/legal_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';
import 'package:maison_du_miracle/screens/legal_acceptance_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/legal_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/app_button.dart';
import 'package:maison_du_miracle/widgets/legal_document_body.dart';

import '../helpers/signed_in_auth.dart';

/// **La barrière de consentement** — l'écran dont on ne sort pas.
///
/// Ce qui s'y vérifie n'est pas de l'habillage : une case précochée n'est pas
/// un consentement, un refus affiché en brut sur un écran sans issue est une
/// impasse, et une saisie perdue à chaque échec rendrait la barrière
/// infranchissable pour qui a du réseau une seconde sur deux.
///
/// Le texte, lui, est déjà testé ailleurs (`legal_document_body`,
/// `resolveLegalLocale`) : ici on regarde la **mécanique du consentement**.

/// Un enregistreur pilotable : le test décide ce que le serveur répond.
class _ScriptedRecorder implements LegalAcceptanceRecorder {
  _ScriptedRecorder({this.summary = const {}});

  /// Le refus à lever, `null` pour réussir. Posé **après** le montage : c'est
  /// aussi ce que fait le réseau, qui ne tombe pas avant qu'on lui parle.
  LegalAcceptanceErrorCode? failure;

  /// Le résumé rendu au succès.
  Map<String, int> summary;

  /// Ce qui est effectivement parti — un seul appel, quel qu'en soit le nombre
  /// de documents.
  final List<List<LegalAcceptance>> calls = [];

  @override
  Future<Map<String, int>> accept(List<LegalAcceptance> accepts) async {
    calls.add(accepts);
    final code = failure;
    if (code != null) throw LegalAcceptanceException(code);
    return summary;
  }
}

LegalDocument _document({
  required String kind,
  required int version,
  int? lastMandatoryVersion,
}) =>
    LegalDocument(
      kind: kind,
      version: version,
      lastMandatoryVersion: lastMandatoryVersion ?? version,
      sections: [
        LegalSection(
          key: 'objet',
          heading: {'fr': 'Objet ($kind)'},
          body: const {'fr': 'Le **service**.'},
        ),
      ],
    );

final _terms = _document(kind: LegalDocumentKind.terms, version: 3);
final _privacy = _document(kind: LegalDocumentKind.privacy, version: 2);

void main() {
  late _ScriptedRecorder recorder;
  late SignedInAuthRepository auth;
  late ProviderContainer container;

  /// Le rechargement demandé par le refus 422 : compté, jamais réellement
  /// synchronisé (aucun test ne parle au réseau).
  var refreshes = 0;

  /// Un montage = un arbre neuf. Sans cette clé, deux `pumpWidget` successifs
  /// **réutilisent le `State`** de l'écran (même type, même position) : les
  /// cases resteraient cochées et le refus précédent affiché, et un test qui
  /// remonte la barrière relirait l'écran d'avant.
  var mount = 0;

  Future<void> pumpGate(
    WidgetTester tester, {
    Map<String, int> accepted = const {},
    List<LegalDocument>? documents,
  }) async {
    // Écran haut : deux documents entiers, deux cases et un bouton.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    recorder = _ScriptedRecorder(summary: const {'cgu': 3, 'privacy': 2});
    auth = SignedInAuthRepository(accepted: accepted);
    refreshes = 0;

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authRepositoryProvider.overrideWithValue(auth),
        legalRepositoryProvider.overrideWithValue(
          InMemoryLegalRepository(documents: documents ?? [_terms, _privacy]),
        ),
        legalAcceptanceRecorderProvider.overrideWithValue(recorder),
        pullToRefreshProvider.overrideWithValue(() async => refreshes++),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: ValueKey(mount++),
          theme: AppTheme.light,
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const LegalAcceptanceScreen(),
        ),
      ),
    );
    // Session résolue, puis flux du magasin livré.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  AppButton continueButton(WidgetTester tester) => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Continuer'),
      );

  Finder box(String kind) => find.byKey(Key('legal_accept_$kind'));

  Future<void> check(WidgetTester tester, String kind) async {
    await tester.tap(box(kind));
    await tester.pump();
  }

  testWidgets('deux documents exigés : deux cases, aucune précochée',
      (tester) async {
    await pumpGate(tester);

    expect(find.byType(LegalDocumentBody), findsNWidgets(2));
    expect(box('cgu'), findsOneWidget);
    expect(box('privacy'), findsOneWidget);
    for (final tile in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(tile.value, isFalse,
          reason: 'une case précochée n\'est pas un '
              'consentement');
    }

    // Bouton inactif tant que tout n'est pas coché — pas « tant qu'une case
    // n'est pas cochée ».
    expect(continueButton(tester).onPressed, isNull);
    await check(tester, 'cgu');
    expect(continueButton(tester).onPressed, isNull);
    await check(tester, 'privacy');
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('un seul document en retard : une seule case, un seul document',
      (tester) async {
    // Les CGU sont à jour, la politique est passée de 1 à 2.
    await pumpGate(tester, accepted: {'cgu': 3, 'privacy': 1});

    expect(find.byType(LegalDocumentBody), findsOneWidget);
    expect(box('cgu'), findsNothing);
    expect(box('privacy'), findsOneWidget);

    await check(tester, 'privacy');
    expect(continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('le titre distingue la première acceptation de la reprise',
      (tester) async {
    await pumpGate(tester);
    expect(find.text('Avant de commencer'), findsOneWidget);
    expect(find.text('Nos conditions ont changé'), findsNothing);

    // Un fidèle qui a déjà accepté quelque chose relit une révision.
    await pumpGate(tester, accepted: {'cgu': 3, 'privacy': 1});
    expect(find.text('Nos conditions ont changé'), findsOneWidget);
    expect(find.text('Avant de commencer'), findsNothing);
  });

  testWidgets('un seul envoi, aux versions affichées', (tester) async {
    await pumpGate(tester);
    await check(tester, 'cgu');
    await check(tester, 'privacy');
    await tester.tap(find.widgetWithText(AppButton, 'Continuer'));
    await tester.pump();
    await tester.pump();

    expect(recorder.calls, hasLength(1),
        reason: 'le serveur écrit en transaction : un corps, ou rien');
    expect(
      recorder.calls.single,
      const [
        LegalAcceptance(kind: 'cgu', version: 3),
        LegalAcceptance(kind: 'privacy', version: 2),
      ],
      reason: 'la version envoyée est celle du texte lu, pas son plancher',
    );
  });

  testWidgets('au succès, la session porte le résumé — et le cache aussi',
      (tester) async {
    await pumpGate(tester);
    await check(tester, 'cgu');
    await check(tester, 'privacy');
    await tester.tap(find.widgetWithText(AppButton, 'Continuer'));
    await tester.pump();
    await tester.pump();

    // C'est l'état qui change ; l'écran ne navigue pas (ici il n'y a même pas
    // de routeur pour l'entendre). La garde fait le reste.
    expect(
      container.read(authProvider).user!.acceptedLegal,
      {'cgu': 3, 'privacy': 2},
    );
    expect(container.read(pendingLegalAcceptancesProvider), isEmpty);
    // Le cache local suit : sans lui, le prochain démarrage hors ligne
    // rouvrirait une barrière que seul le réseau peut refermer.
    expect(auth.user.acceptedLegal, {'cgu': 3, 'privacy': 2});
  });

  testWidgets(
      'hors ligne : le texte se lit, l\'accord est refusé, les cases '
      'restent cochées', (tester) async {
    await pumpGate(tester);
    recorder.failure = LegalAcceptanceErrorCode.network;

    // Le document est là : il vient du magasin, pas du réseau.
    expect(find.byType(LegalDocumentBody), findsNWidgets(2));

    await check(tester, 'cgu');
    await check(tester, 'privacy');
    await tester.tap(find.widgetWithText(AppButton, 'Continuer'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Connexion requise pour enregistrer votre accord.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Réessayer'), findsOneWidget);
    // **La saisie reste à l'écran**, comme au composeur d'annonces.
    for (final tile in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(tile.value, isTrue);
    }

    // Le réseau revient : le même bouton repart, sans rien recocher.
    recorder.failure = null;
    await tester.tap(find.widgetWithText(AppButton, 'Réessayer'));
    await tester.pump();
    await tester.pump();
    expect(container.read(authProvider).user!.acceptedLegal,
        {'cgu': 3, 'privacy': 2});
  });

  testWidgets('les quatre refus ont chacun leur phrase, aucune brute',
      (tester) async {
    const phrases = {
      LegalAcceptanceErrorCode.network:
          'Connexion requise pour enregistrer votre accord.',
      LegalAcceptanceErrorCode.unauthorized:
          'Votre session a expiré. Reconnectez-vous pour enregistrer votre accord.',
      LegalAcceptanceErrorCode.outdated: 'Ces conditions ont été mises à jour.',
      LegalAcceptanceErrorCode.server:
          'Le serveur n\'a pas pu enregistrer votre accord.',
    };

    for (final entry in phrases.entries) {
      await pumpGate(tester);
      recorder.failure = entry.key;
      await check(tester, 'cgu');
      await check(tester, 'privacy');
      await tester.tap(find.widgetWithText(AppButton, 'Continuer'));
      await tester.pump();
      await tester.pump();

      expect(find.text(entry.value), findsOneWidget,
          reason: 'refus ${entry.key.name}');
    }
  });

  testWidgets('le 401 ne propose rien : c\'est la garde qui ramène à /auth',
      (tester) async {
    await pumpGate(tester);
    recorder.failure = LegalAcceptanceErrorCode.unauthorized;
    await check(tester, 'cgu');
    await check(tester, 'privacy');
    await tester.tap(find.widgetWithText(AppButton, 'Continuer'));
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(AppButton, 'Réessayer'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Recharger'), findsNothing);
  });

  testWidgets('le 422 recharge le document, il ne rejoue pas l\'envoi',
      (tester) async {
    await pumpGate(tester);
    recorder.failure = LegalAcceptanceErrorCode.outdated;
    await check(tester, 'cgu');
    await check(tester, 'privacy');
    await tester.tap(find.widgetWithText(AppButton, 'Continuer'));
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(AppButton, 'Recharger'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Réessayer'), findsNothing);

    await tester.tap(find.widgetWithText(AppButton, 'Recharger'));
    await tester.pump();

    // Un cycle de synchronisation, et **un seul envoi** : réessayer à
    // l'identique échouerait toujours.
    expect(refreshes, 1);
    expect(recorder.calls, hasLength(1));
    // Les cases n'ont pas bougé — et la barrière est toujours là.
    for (final tile in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(tile.value, isTrue);
    }
    expect(container.read(pendingLegalAcceptancesProvider), isNotEmpty);
  });
}
