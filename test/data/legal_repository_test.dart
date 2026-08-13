import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/repositories/legal_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_legal_repository.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';

import 'local/local_database_fixtures.dart';

/// Le repository des documents légaux, **sur le vrai magasin** (base en
/// mémoire) et sur son double.
///
/// Le test de parité compte ici plus qu'ailleurs. La règle de repli d'un
/// document légal est la **seule dérogation du dépôt** à `pick` (ADR-0035) : si
/// le double ne l'appliquait pas, elle ne serait exercée nulle part en mode
/// maquette, c'est-à-dire pendant tout le développement — et un document
/// mélangé s'y afficherait parfaitement, sans faire rougir un seul test.

/// Deux sections, dont **une seule** est traduite en éwé.
const _partiellementTraduit = [
  LegalSection(
    key: 'objet',
    heading: {'fr': 'Objet', 'ee': 'Taɖodzinu'},
    body: {'fr': 'Le service.', 'ee': 'Dɔwɔna.'},
  ),
  LegalSection(
    key: 'conservation',
    heading: {'fr': 'Conservation'},
    body: {'fr': 'Trois ans.'},
  ),
];

/// Les mêmes deux sections, complètes dans les deux langues.
const _entierementTraduit = [
  LegalSection(
    key: 'objet',
    heading: {'fr': 'Objet', 'ee': 'Taɖodzinu'},
    body: {'fr': 'Le service.', 'ee': 'Dɔwɔna.'},
  ),
  LegalSection(
    key: 'conservation',
    heading: {'fr': 'Conservation', 'ee': 'Dzadzraɖo'},
    body: {'fr': 'Trois ans.', 'ee': 'Ƒe etɔ̃.'},
  ),
];

void main() {
  late AppDatabase db;
  late SyncDao sync;
  late StoreLegalRepository store;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
    store = StoreLegalRepository(db.legalDao);
  });

  tearDown(() => db.close());

  Future<void> seed(List<LegalDocumentsCompanion> rows) => sync
      .applyPage(sync.legalDocumentsCollection, upserts: rows, cursor: 'c1');

  group('Le magasin, traduit en modèle de lecture', () {
    test('un magasin vide rend `null` — une attente, pas une erreur', () async {
      expect(await store.documentOfKind('cgu', locale: 'fr').first, isNull);
    });

    test('les sections sortent repliées, dans l\'ordre, avec le pied',
        () async {
      await seed([
        legalDocumentRow(
          1,
          version: 4,
          lastMandatoryVersion: 3,
          sections: _entierementTraduit,
          publishedAt: DateTime.utc(2026, 1, 4),
          updatedAt: DateTime.utc(2026, 3, 9),
        ),
      ]);

      final document = (await store.documentOfKind('cgu', locale: 'fr').first)!;

      expect(document.kind, 'cgu');
      expect(document.version, 4);
      expect(document.lastMandatoryVersion, 3);
      expect(document.sections.map((s) => s.key), ['objet', 'conservation']);
      expect(document.sections.first.heading, 'Objet');
      // Le magasin range les instants en secondes d'époque et les rend dans le
      // fuseau de l'appareil : on compare des **instants**, jamais des chaînes
      // ni des `DateTime` de fuseaux différents.
      expect(
        document.footerDate!.isAtSameMomentAs(DateTime.utc(2026, 3, 9)),
        isTrue,
      );
    });

    test('une révision reçue pendant la lecture remplace le texte à l\'écran',
        () async {
      // Le motif du `Stream`. Un `Future` livrerait une photographie prise au
      // moment du clic — et sur l'écran qu'on demandera d'accepter (#56), cette
      // photographie serait la preuve horodatée d'un accord donné sur un texte
      // périmé.
      await seed([
        legalDocumentRow(
          1,
          version: 1,
          sections: const [
            LegalSection(
              key: 'objet',
              heading: {'fr': 'Objet'},
              body: {'fr': 'Première édition.'},
            ),
          ],
        ),
      ]);

      final vus = <String?>[];
      final abonnement = store
          .documentOfKind('cgu', locale: 'fr')
          .listen((d) => vus.add(d?.sections.single.body));
      await pumpEventQueue();

      await seed([
        legalDocumentRow(
          1,
          version: 2,
          sections: const [
            LegalSection(
              key: 'objet',
              heading: {'fr': 'Objet'},
              body: {'fr': 'Seconde édition.'},
            ),
          ],
        ),
      ]);
      await pumpEventQueue();
      await abonnement.cancel();

      expect(vus, ['Première édition.', 'Seconde édition.']);
    });
  });

  group('Parité — le double applique les MÊMES règles', () {
    /// Les deux implémentations, alimentées par la même donnée brute.
    Future<(LegalDocumentView, LegalDocumentView)> deux(
      List<LegalSection> sections, {
      required String locale,
    }) async {
      await seed([legalDocumentRow(1, version: 2, sections: sections)]);
      final double = InMemoryLegalRepository(
        documents: [
          LegalDocument(kind: 'cgu', version: 2, sections: sections),
        ],
      );

      return (
        (await store.documentOfKind('cgu', locale: locale).first)!,
        (await double.documentOfKind('cgu', locale: locale).first)!,
      );
    }

    test('un document complet en éwé sort en éwé des deux côtés', () async {
      final (magasin, double) = await deux(_entierementTraduit, locale: 'ee');

      expect(magasin.locale, 'ee');
      expect(double.locale, magasin.locale);
      expect(
        double.sections.map((s) => (s.key, s.heading, s.body)),
        magasin.sections.map((s) => (s.key, s.heading, s.body)),
      );
    });

    test('une SEULE section manquante bascule les deux, entièrement', () async {
      final (magasin, double) = await deux(_partiellementTraduit, locale: 'ee');

      expect(magasin.locale, 'fr');
      expect(double.locale, 'fr');
      // Y compris la section qui *était* traduite : le résultat est binaire.
      expect(magasin.sections.first.heading, 'Objet');
      expect(double.sections.first.heading, 'Objet');
    });

    test('un genre absent rend `null` des deux côtés', () async {
      final double = InMemoryLegalRepository(documents: const []);

      expect(await store.documentOfKind('privacy', locale: 'fr').first, isNull);
      expect(
          await double.documentOfKind('privacy', locale: 'fr').first, isNull);
    });
  });

  group('Le double du mode maquette exerce la règle pour de vrai', () {
    test('la politique de confidentialité fictive sort en français en éwé',
        () async {
      // `SampleData` laisse une section sans traduction éwé **à dessein** :
      // sans elle, la dérogation d'ADR-0035 ne serait exercée nulle part
      // pendant tout le développement en mode maquette.
      final double = InMemoryLegalRepository();

      final privacy =
          (await double.documentOfKind('privacy', locale: 'ee').first)!;
      expect(privacy.locale, 'fr');

      // Les CGU, elles, sont complètes : elles sortent bien en éwé.
      final cgu = (await double.documentOfKind('cgu', locale: 'ee').first)!;
      expect(cgu.locale, 'ee');
    });

    test('« à propos » n\'exige aucune acceptation', () async {
      final about = (await InMemoryLegalRepository()
          .documentOfKind('about', locale: 'fr')
          .first)!;

      expect(about.lastMandatoryVersion, isNull);
    });
  });
}
