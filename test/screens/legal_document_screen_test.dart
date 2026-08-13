import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/legal_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';
import 'package:maison_du_miracle/screens/legal_document_screen.dart';
import 'package:maison_du_miracle/state/legal_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/content_absence.dart';
import 'package:maison_du_miracle/widgets/legal_document_body.dart';

import '../helpers/pump_screen.dart';

/// L'écran de consultation `/legal/:kind`.
///
/// Il ne décide de rien : la langue est tranchée dans le modèle de lecture, la
/// mise en forme dans le corps partagé. Ce qu'on vérifie ici est donc le
/// **câblage** — qu'il lise le bon genre, qu'il rende un magasin vide comme une
/// absence et non comme une page blanche, et qu'une révision reçue pendant la
/// lecture remplace le texte affiché.

/// Un repository dont on peut pousser les valeurs à la main, pour imiter la
/// synchronisation qui réécrit sous les pieds de l'écran.
class _PushableLegalRepository implements LegalRepository {
  final _controller = StreamController<LegalDocumentView?>.broadcast();

  void push(LegalDocumentView? document) => _controller.add(document);

  @override
  Stream<LegalDocumentView?> documentOfKind(
    String kind, {
    required String locale,
  }) =>
      _controller.stream;
}

LegalDocument _document({
  required String kind,
  int version = 3,
  List<LegalSection>? sections,
  DateTime? updatedAt,
}) =>
    LegalDocument(
      kind: kind,
      version: version,
      updatedAt: updatedAt,
      sections: sections ??
          const [
            LegalSection(
              key: 'objet',
              heading: {'fr': 'Objet', 'ee': 'Taɖodzinu'},
              body: {'fr': 'Le **service**.', 'ee': 'Dɔwɔna.'},
            ),
          ],
    );

/// Laisse le flux livrer son événement, puis l'arbre se reconstruire : deux
/// tours, parce que la valeur traverse d'abord le `StreamProvider`.
Future<void> pushed(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  Future<void> pumpLegal(
    WidgetTester tester, {
    required String kind,
    List<LegalDocument> documents = const [],
    LegalRepository? repository,
  }) =>
      pumpScreen(
        tester,
        LegalDocumentScreen(kind: kind),
        overrides: [
          legalRepositoryProvider.overrideWithValue(
            repository ?? InMemoryLegalRepository(documents: documents),
          ),
        ],
      );

  testWidgets('un magasin vide rend l\'absence « pas encore synchronisé »',
      (tester) async {
    // **Pas un écran blanc, pas une erreur.** Et pas un écran d'absence de
    // plus : c'est `ContentAbsenceView`, la même que les trois autres.
    await pumpLegal(tester, kind: 'cgu');

    expect(find.byType(ContentAbsenceView), findsOneWidget);
    expect(find.byType(LegalDocumentBody), findsNothing);
    expect(find.text('Pas encore synchronisé'), findsOneWidget);
  });

  testWidgets('les CGU se rendent, titre de section et corps compris',
      (tester) async {
    await pumpLegal(
      tester,
      kind: 'cgu',
      documents: [_document(kind: 'cgu')],
    );

    expect(find.byType(LegalDocumentBody), findsOneWidget);
    expect(find.text('Objet'), findsOneWidget);
    expect(find.text('CGU'), findsOneWidget); // la barre de marque
  });

  testWidgets('chaque genre lit le sien', (tester) async {
    await pumpLegal(
      tester,
      kind: 'privacy',
      documents: [
        _document(kind: 'cgu'),
        _document(
          kind: 'privacy',
          sections: const [
            LegalSection(
              key: 'donnees',
              heading: {'fr': 'Vos données'},
              body: {'fr': 'Nous collectons peu.'},
            ),
          ],
        ),
      ],
    );

    expect(find.text('Vos données'), findsOneWidget);
    expect(find.text('Objet'), findsNothing);
    expect(find.text('Politique de confidentialité'), findsOneWidget);
  });

  testWidgets('un genre inconnu retombe sur les CGU sans lever',
      (tester) async {
    // La route est publique : un lien mal formé ne doit pas casser
    // l'application.
    await pumpLegal(
      tester,
      kind: 'contrat-de-mariage',
      documents: [_document(kind: 'cgu')],
    );

    expect(find.text('Objet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le pied porte la version et la date de mise à jour',
      (tester) async {
    await pumpLegal(
      tester,
      kind: 'cgu',
      documents: [
        _document(kind: 'cgu', version: 4, updatedAt: DateTime.utc(2026, 3, 9)),
      ],
    );

    expect(find.text('Version 4 — mise à jour le 9 mars 2026'), findsOneWidget);
  });

  testWidgets('sans date connue, la version seule — jamais une date inventée',
      (tester) async {
    await pumpLegal(
      tester,
      kind: 'cgu',
      documents: [_document(kind: 'cgu', version: 4)],
    );

    expect(find.text('Version 4'), findsOneWidget);
  });

  testWidgets('une révision reçue pendant la lecture remplace le texte',
      (tester) async {
    // C'est le motif du `Stream`. Un `Future` aurait livré une photographie
    // prise au moment du clic.
    final repository = _PushableLegalRepository();
    await pumpLegal(tester, kind: 'cgu', repository: repository);

    repository.push(
      LegalDocumentView.resolve(
        kind: 'cgu',
        version: 1,
        locale: 'fr',
        sections: const [
          LegalSection(
            key: 'objet',
            heading: {'fr': 'Objet'},
            body: {'fr': 'Première édition.'},
          ),
        ],
      ),
    );
    await pushed(tester);
    expect(find.text('Première édition.'), findsOneWidget);

    repository.push(
      LegalDocumentView.resolve(
        kind: 'cgu',
        version: 2,
        locale: 'fr',
        sections: const [
          LegalSection(
            key: 'objet',
            heading: {'fr': 'Objet'},
            body: {'fr': 'Seconde édition.'},
          ),
        ],
      ),
    );
    await pushed(tester);

    expect(find.text('Première édition.'), findsNothing);
    expect(find.text('Seconde édition.'), findsOneWidget);
  });

  testWidgets('une rétractation retire le contenu de l\'écran ouvert',
      (tester) async {
    // Un document légal ne se rétracte pas côté serveur (pas de tombstone),
    // mais un resync peut vider la table : l'écran doit alors dire l'absence,
    // et surtout pas figer la dernière copie connue.
    final repository = _PushableLegalRepository();
    await pumpLegal(tester, kind: 'cgu', repository: repository);

    repository.push(
      LegalDocumentView.resolve(
        kind: 'cgu',
        version: 1,
        locale: 'fr',
        sections: const [
          LegalSection(
            key: 'objet',
            heading: {'fr': 'Objet'},
            body: {'fr': 'Le service.'},
          ),
        ],
      ),
    );
    await pushed(tester);
    expect(find.byType(LegalDocumentBody), findsOneWidget);

    repository.push(null);
    await pushed(tester);

    expect(find.byType(LegalDocumentBody), findsNothing);
    expect(find.byType(ContentAbsenceView), findsOneWidget);
  });

  testWidgets('le document est lisible en thème sombre', (tester) async {
    // Aucune couleur en dur dans le corps : les textes suivent la palette. Un
    // texte noir sur fond sombre passerait tous les tests de contenu.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalRepositoryProvider.overrideWithValue(
            InMemoryLegalRepository(documents: [_document(kind: 'cgu')]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: const LegalDocumentScreen(kind: 'cgu'),
        ),
      ),
    );
    await tester.pump();

    final titre = tester.widget<Text>(find.text('Objet'));
    final couleur = titre.style!.color!;
    // Clair sur sombre : la luminance du texte doit être haute.
    expect(couleur.computeLuminance(), greaterThan(0.5));
  });
}
