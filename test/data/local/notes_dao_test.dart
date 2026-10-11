import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/notes_dao.dart';
import 'package:maison_du_miracle/models/note_view.dart';

import 'local_database_fixtures.dart';

/// **Les deux tables des notes, et la résolution entre elles** (#190).
///
/// L'invariant : *la synchronisation remplit `spiritual_notes`, l'éditeur
/// remplit `local_notes`, et la lecture préfère le brouillon tant qu'il
/// existe*. Il disparaît quand la ligne synchronisée revient au moins aussi
/// récente que lui.
void main() {
  late AppDatabase db;
  late NotesDao dao;

  const a = '019f8000-0000-7000-8000-00000000000a';
  const b = '019f8000-0000-7000-8000-00000000000b';
  const c = '019f8000-0000-7000-8000-00000000000c';
  const catBlue = '019f8000-0000-7000-8000-0000000000c1';
  const catPink = '019f8000-0000-7000-8000-0000000000c2';

  setUp(() {
    db = openTestDatabase();
    dao = db.notesDao;
  });

  tearDown(() => db.close());

  /// Une ligne **répliquée**, posée comme la synchronisation le ferait.
  Future<void> synced({
    required String id,
    String? title,
    String body = '',
    String? categoryId,
    bool pinned = false,
    String? teachingId,
    required DateTime updatedAt,
  }) {
    return db.syncDao.applyPage(
      db.syncDao.spiritualNotesCollection,
      upserts: [
        SpiritualNotesCompanion.insert(
          id: id,
          title: Value(title),
          body: Value(body),
          categoryId: Value(categoryId),
          pinned: Value(pinned),
          teachingId: Value(teachingId),
          updatedAt: Value(updatedAt),
        ),
      ],
      cursor: 'c-notes',
    );
  }

  Future<void> local({
    required String id,
    String? title,
    String body = '',
    String? categoryId,
    bool pinned = false,
    String? teachingId,
    required DateTime clientUpdatedAt,
    bool dirty = true,
  }) {
    return dao.saveDraft(LocalNotesCompanion.insert(
      id: id,
      title: Value(title),
      body: Value(body),
      categoryId: Value(categoryId),
      pinned: Value(pinned),
      teachingId: Value(teachingId),
      clientCreatedAt: clientUpdatedAt,
      clientUpdatedAt: clientUpdatedAt,
      dirty: Value(dirty),
    ));
  }

  Future<List<NoteView>> list({String? categoryId, String query = ''}) =>
      dao.watchNotes(categoryId: categoryId, query: query).first;

  group('La fusion', () {
    test('le brouillon l\'emporte sur la ligne synchronisée', () async {
      await synced(
        id: a,
        title: 'Serveur',
        body: 'ancien',
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      await local(
        id: a,
        title: 'Téléphone',
        body: 'nouveau',
        clientUpdatedAt: DateTime.utc(2026, 10, 2),
      );

      final notes = await list();
      expect(notes, hasLength(1));
      expect(notes.single.title, 'Téléphone');
      expect(notes.single.body, 'nouveau');
      expect(notes.single.isLocal, isTrue);
    });

    test('le brouillon reste la vérité même une fois envoyé (`dirty` faux)',
        () async {
      // Entre le `2xx` et le retour du delta, la carte ne doit pas reculer
      // d'une version.
      await synced(id: a, body: 'ancien', updatedAt: DateTime.utc(2026, 10, 1));
      await local(
        id: a,
        body: 'nouveau',
        clientUpdatedAt: DateTime.utc(2026, 10, 2),
        dirty: false,
      );

      expect((await list()).single.body, 'nouveau');
    });

    test('une note synchronisée seule se lit telle quelle', () async {
      await synced(
        id: a,
        title: 'Serveur',
        body: 'corps',
        updatedAt: DateTime.utc(2026, 10, 1),
      );

      final note = (await dao.watchNote(a).first)!;
      expect(note.title, 'Serveur');
      expect(note.isLocal, isFalse);
      expect(note.updatedAt, DateTime.utc(2026, 10, 1));
    });

    test('une note inconnue rend nul', () async {
      expect(await dao.watchNote(a).first, isNull);
    });
  });

  group('La purge', () {
    test('la ligne locale part quand le serveur revient au moins aussi récent',
        () async {
      await local(
        id: a,
        body: 'brouillon',
        clientUpdatedAt: DateTime.utc(2026, 10, 2, 10),
      );
      await synced(
        id: a,
        body: 'brouillon',
        updatedAt: DateTime.utc(2026, 10, 2, 10),
      );

      expect(await dao.purgeReconciled(), 1);
      expect(await dao.localNote(a), isNull);
      expect((await list()).single.isLocal, isFalse);
    });

    test('elle reste quand le serveur est en retard sur la frappe', () async {
      await local(
        id: a,
        body: 'frappe récente',
        clientUpdatedAt: DateTime.utc(2026, 10, 2, 10),
      );
      await synced(
        id: a,
        body: 'version d\'avant',
        updatedAt: DateTime.utc(2026, 10, 2, 9),
      );

      expect(await dao.purgeReconciled(), 0);
      expect((await list()).single.body, 'frappe récente');
    });

    test('elle reste tant que le serveur ne connaît pas la note', () async {
      await local(id: a, body: 'x', clientUpdatedAt: DateTime.utc(2026, 10, 2));
      expect(await dao.purgeReconciled(), 0);
      expect(await dao.localNote(a), isNotNull);
    });
  });

  group('Le tri et les filtres', () {
    setUp(() async {
      await synced(
        id: a,
        title: 'Objectifs',
        body: 'Envoyer la proposition',
        categoryId: catBlue,
        updatedAt: DateTime.utc(2026, 10, 3),
      );
      await synced(
        id: b,
        title: 'Sociologie',
        body: 'Lire les pages 102-120',
        categoryId: catPink,
        pinned: true,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      await synced(
        id: c,
        title: 'Courses',
        body: 'Lait d\'avoine, BANANES',
        updatedAt: DateTime.utc(2026, 10, 2),
      );
    });

    test('épinglées en tête, puis les plus récentes', () async {
      expect((await list()).map((n) => n.id), [b, a, c]);
    });

    test('le filtre de catégorie', () async {
      expect((await list(categoryId: catBlue)).map((n) => n.id), [a]);
      expect((await list(categoryId: 'inconnue')), isEmpty);
    });

    test(
        'la recherche, sur le titre et le corps, sans tenir compte de la '
        'casse', () async {
      expect((await list(query: 'socio')).map((n) => n.id), [b]);
      expect((await list(query: 'bananes')).map((n) => n.id), [c]);
      expect((await list(query: 'PAGES')).map((n) => n.id), [b]);
      expect(await list(query: 'rien'), isEmpty);
    });

    test('recherche et catégorie se cumulent', () async {
      expect(await list(query: 'proposition', categoryId: catPink), isEmpty);
      expect((await list(query: 'proposition', categoryId: catBlue)).length, 1);
    });

    test('la recherche voit aussi les brouillons', () async {
      await local(
        id: a,
        title: 'Objectifs',
        body: 'Appeler le plombier',
        clientUpdatedAt: DateTime.utc(2026, 10, 4),
      );
      expect((await list(query: 'plombier')).map((n) => n.id), [a]);
      expect(await list(query: 'proposition'), isEmpty);
    });
  });

  group('Les catégories', () {
    test('se lisent par nom, couleur analysée', () async {
      await db.syncDao.applyPage(
        db.syncDao.noteCategoriesCollection,
        upserts: [
          NoteCategoriesCompanion.insert(
              id: catPink, name: 'Zèle', color: 'pink'),
          NoteCategoriesCompanion.insert(
              id: catBlue, name: 'Amour', color: 'fuchsia'),
        ],
        cursor: 'c-cat',
      );

      final categories = await dao.watchCategories().first;
      expect(categories.map((c) => c.name), ['Amour', 'Zèle']);
      expect(categories.first.color, isNull, reason: 'couleur inconnue');
      expect(categories.last.color, NoteColor.pink);
    });
  });

  group('La note d\'un enseignement', () {
    const teaching = '019f7000-0000-7000-8000-000000000001';

    test('absente : nul', () async {
      expect(await dao.noteIdForTeaching(teaching), isNull);
    });

    test('trouvée, dans le brouillon comme dans le synchronisé', () async {
      await synced(
        id: a,
        teachingId: teaching,
        updatedAt: DateTime.utc(2026, 10, 1),
      );
      expect(await dao.noteIdForTeaching(teaching), a);

      await local(
        id: b,
        teachingId: teaching,
        clientUpdatedAt: DateTime.utc(2026, 10, 5),
      );
      expect(await dao.noteIdForTeaching(teaching), b,
          reason: 'la plus récente');
    });
  });

  group('L\'écriture', () {
    test('un brouillon se remplace en place', () async {
      await local(
          id: a, body: 'un', clientUpdatedAt: DateTime.utc(2026, 10, 1));
      await local(
          id: a, body: 'deux', clientUpdatedAt: DateTime.utc(2026, 10, 2));

      final rows = await db.select(db.localNotes).get();
      expect(rows, hasLength(1));
      expect(rows.single.body, 'deux');
    });

    test('`markSent` ne blanchit que la version envoyée', () async {
      final t1 = DateTime.utc(2026, 10, 1);
      await local(id: a, body: 'un', clientUpdatedAt: t1);
      await local(
          id: a, body: 'deux', clientUpdatedAt: DateTime.utc(2026, 10, 2));

      await dao.markSent(a, t1);
      expect((await dao.localNote(a))!.dirty, isTrue, reason: 'frappe depuis');

      await dao.markSent(a, DateTime.utc(2026, 10, 2));
      expect((await dao.localNote(a))!.dirty, isFalse);
      expect(await dao.dirtyNotes(), isEmpty);
    });

    test('`markFailed` garde le brouillon à envoyer, avec sa cause', () async {
      await local(
          id: a, body: 'un', clientUpdatedAt: DateTime.utc(2026, 10, 1));
      await dao.markFailed(a, 'réseau');
      final row = (await dao.localNote(a))!;
      expect(row.dirty, isTrue);
      expect(row.lastError, 'réseau');
    });

    test('`deleteLocal` retire le brouillon, et lui seul', () async {
      await synced(id: a, updatedAt: DateTime.utc(2026, 10, 1));
      await local(id: a, body: 'x', clientUpdatedAt: DateTime.utc(2026, 10, 2));
      await dao.deleteLocal(a);
      expect(await dao.localNote(a), isNull);
      // La ligne répliquée ne bouge pas : seule une tombstone du delta la
      // retire.
      expect(await db.select(db.spiritualNotes).get(), hasLength(1));
    });
  });

  test(
      'garde-fou de source : l\'application n\'écrit jamais dans '
      '`spiritual_notes` ni `note_categories`', () {
    // Même règle que `playback_progress` (ADR-0026) : le moteur passe par
    // `LocalCollection.table`, donc nommer l'une des deux tables dans un
    // `delete`, un `into` ou un `update` est, par construction, le fait de
    // quelqu'un d'autre que la synchronisation.
    const forbidden = [
      'delete(spiritualNotes)',
      'into(spiritualNotes)',
      'update(spiritualNotes)',
      'delete(noteCategories)',
      'into(noteCategories)',
      'update(noteCategories)',
      'DELETE FROM spiritual_notes',
      'INSERT INTO spiritual_notes',
      'UPDATE spiritual_notes',
    ];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    expect(sources, isNotEmpty);
    for (final source in sources) {
      final code = source
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final fragment in forbidden) {
        expect(code, isNot(contains(fragment)), reason: source.path);
      }
    }
  });
}
