// Lectures du magasin, côté documents légaux.
//
// Deux choses s'y vérifient et rien d'autre : que la ligne se retrouve par son
// genre, et que les sections ressortent **brutes** — cartes de traduction
// entières, dans l'ordre servi. Le jour où le magasin replierait une langue à
// l'écriture, `resolveLegalLocale` deviendrait inapplicable (ADR-0035) et rien
// d'autre ne le dirait.

import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';

import 'local_database_fixtures.dart';

const _sections = [
  LegalSection(
    key: 'objet',
    heading: {'fr': 'Objet', 'ee': 'Taɖodzinu'},
    body: {'fr': 'Le service.', 'ee': 'Dɔwɔna.'},
  ),
  LegalSection(
    key: 'contact',
    heading: {'fr': 'Contact'},
    body: {'fr': 'Écrivez-nous.'},
  ),
];

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<void> seed(List<LegalDocumentsCompanion> rows) =>
      db.batch((batch) => batch.insertAll(db.legalDocuments, rows));

  test('un magasin vide ne rend rien — une attente, pas une erreur', () async {
    expect(
      await db.legalDao
          .documentOfKind(LegalDocumentKind.terms)
          .getSingleOrNull(),
      isNull,
    );
  });

  test('le document se retrouve par son genre', () async {
    await seed([
      legalDocumentRow(1, kind: 'cgu', version: 4),
      legalDocumentRow(2, kind: 'privacy', version: 2),
      legalDocumentRow(3, kind: 'about', version: 1),
    ]);

    final privacy = await db.legalDao
        .documentOfKind(LegalDocumentKind.privacy)
        .getSingleOrNull();

    expect(privacy!.kind, 'privacy');
    expect(privacy.version, 2);
  });

  test('les sections ressortent brutes, dans l\'ordre, cartes entières',
      () async {
    await seed([legalDocumentRow(1, sections: _sections)]);

    final row = await db.legalDao.documentOfKind('cgu').getSingleOrNull();

    expect(row!.sections.map((s) => s.key), ['objet', 'contact']);
    // La carte entière : le magasin n'a choisi aucune langue.
    expect(row.sections.first.heading, {'fr': 'Objet', 'ee': 'Taɖodzinu'});
    expect(row.sections.last.body, {'fr': 'Écrivez-nous.'});
  });

  test('le flux ré-émet quand la synchronisation réécrit sous les pieds',
      () async {
    await seed([legalDocumentRow(1, version: 1)]);
    final stream = db.legalDao.documentOfKind('cgu').watchSingleOrNull();

    final seen = <int?>[];
    final subscription = stream.listen((row) => seen.add(row?.version));
    await pumpEventQueue();

    await db.into(db.legalDocuments).insert(
          legalDocumentRow(1, version: 2),
          mode: InsertMode.insertOrReplace,
        );
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, [1, 2]);
  });

  test('deux éditions croisées : la plus haute version gagne', () async {
    // Le serveur ne tient qu'une ligne courante par genre ; ce tri ne sert qu'à
    // rendre la lecture déterministe si deux éditions se croisaient dans un
    // même cycle.
    await seed([
      legalDocumentRow(1, kind: 'cgu', version: 2),
      legalDocumentRow(2, kind: 'cgu', version: 5),
    ]);

    final row = await db.legalDao.documentOfKind('cgu').getSingleOrNull();
    expect(row!.version, 5);
  });
}
