// Palier du **surlignage de quelques mots** (mobile#252) :
// `AppDatabase.kWordMarkSchemaVersion` = v32, après la versification (v31).
// Il exige `test/data/local/schema/schema_v32.dart`, produit par
// `make gen && make migrations`.
//
// Le dernier test est celui qui porte la décision du contrat : **nulles
// partout veut dire « ce qu'on faisait avant »**. Une marque posée avant ce
// palier n'a pas de traduction, donc elle paraît dans toutes ; et `char_from`
// vaut **0** pour le premier caractère — une valeur légitime, jamais un
// « pas de valeur ».

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/marks/bible_marks_store.dart';

import 'schema/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  const v = AppDatabase.kWordMarkSchemaVersion;

  test('v32 suit la versification', () {
    expect(v, 32);
    expect(GeneratedHelper.versions, contains(v));
    expect(AppDatabase.kWordMarkSchemaVersion,
        AppDatabase.kVersificationSchemaVersion + 1);
  });

  test('v31 → v32 : les trois champs du mot, sur les deux tables', () async {
    final connection = await verifier.startAt(v - 1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test('v1 → v32 : un appareil resté en v1 rejoue tous les paliers', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, v);
  });

  test(
      'v31 → v32 : les marques déjà posées survivent sans traduction — donc '
      'dans toutes', () async {
    final schema = await verifier.schemaAt(v - 1);
    // Un surlignage de membre (le miroir) et un geste d'invité (la table
    // locale), tels qu'ils existaient avant le palier.
    schema.rawDatabase.execute(
      "INSERT INTO bible_marks (sync_stamp, id, kind, book, chapter, "
      "verse_from, verse_to, color) "
      "VALUES (1, 'm-1', 'highlight', 'John', 3, 16, 18, 'yellow')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO local_bible_marks (id, kind, book, chapter, verse_from, "
      "color, client_created_at, client_updated_at, dirty) "
      "VALUES ('l-1', 'favorite', 'Ps', 23, 1, NULL, 0, 0, 1)",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, v);

    final mirror = (await db.select(db.bibleMarks).get()).single;
    expect((mirror.id, mirror.verseFrom, mirror.color), ('m-1', 16, 'yellow'));
    expect(mirror.versionCode, isNull);
    expect(mirror.charFrom, isNull);
    expect(mirror.charTo, isNull);
    final local = (await db.select(db.localBibleMarks).get()).single;
    expect((local.id, local.dirty), ('l-1', true));
    expect(local.versionCode, isNull);

    // La lecture fusionnée s'en accommode, et la marque paraît dans n'importe
    // quelle traduction : c'est la promesse « rien ne change pour les marques
    // déjà posées ».
    final marks = await BibleMarksStore(db).watch(member: true).first;
    expect(marks, hasLength(2));
    for (final m in marks) {
      expect(m.versionCode, isNull, reason: m.id);
      expect(m.isWordMark, isFalse, reason: m.id);
      expect(m.showsIn('LSG'), isTrue, reason: m.id);
      expect(m.showsIn('EWE'), isTrue, reason: m.id);
    }
  });

  test('`char_from = 0` se range et se relit comme un zéro, pas comme nul',
      () async {
    final db = AppDatabase(await verifier.startAt(v));
    addTearDown(db.close);

    // Le premier caractère du verset : la valeur qui a mordu deux fois cette
    // semaine, dont une fois côté serveur sur ce même chantier.
    await db.into(db.localBibleMarks).insert(
          LocalBibleMarksCompanion.insert(
            id: 'w-1',
            kind: 'highlight',
            book: 'John',
            chapter: 3,
            verseFrom: const Value(16),
            verseTo: const Value(16),
            color: const Value('green'),
            versionCode: const Value('LSG'),
            charFrom: const Value(0),
            charTo: const Value(3),
            clientCreatedAt: DateTime.utc(2026, 10, 27),
            clientUpdatedAt: DateTime.utc(2026, 10, 27),
          ),
        );

    final row = (await db.select(db.localBibleMarks).get()).single;
    expect(row.charFrom, 0);
    expect(row.charFrom, isNotNull);
    final mark = (await BibleMarksStore(db).watch(member: false).first).single;
    expect((mark.charFrom, mark.charTo, mark.versionCode), (0, 3, 'LSG'));
    expect(mark.isWordMark, isTrue);
    expect(mark.showsIn('LSG'), isTrue);
    expect(mark.showsIn('EWE'), isFalse,
        reason: 'un surlignage au mot ne suit pas les autres traductions');
  });
}
