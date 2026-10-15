/// **L'outbox des pièces jointes** (N4, mobile#192) : `pending_note_media`,
/// et les deux lectures de contenu du composeur.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_dao.dart';

import '../../../data/local/local_database_fixtures.dart';

void main() {
  late AppDatabase db;
  late NoteMediaDao dao;

  setUp(() {
    db = openTestDatabase();
    dao = NoteMediaDao(db);
  });

  tearDown(() => db.close());

  PendingNoteMediaCompanion row(String embedId, {String? key}) =>
      PendingNoteMediaCompanion.insert(
        noteId: 'n-1',
        embedId: embedId,
        kind: 'image',
        localPath: '/tmp/$embedId.jpg',
        key: Value(key),
      );

  test('une ligne se lit par embed et, une fois montée, par clé', () async {
    await dao.insert(row('e-1'));
    expect((await dao.byEmbedId('e-1'))!.localPath, '/tmp/e-1.jpg');
    expect(await dao.byKey('note-media/o/a.jpg'), isNull);

    await dao.patch(
      'e-1',
      const PendingNoteMediaCompanion(
        mime: Value('image/jpeg'),
        key: Value('note-media/o/a.jpg'),
      ),
    );
    final byKey = (await dao.byKey('note-media/o/a.jpg'))!;
    expect(byKey.embedId, 'e-1');
    expect(byKey.mime, 'image/jpeg');
  });

  test('la cause s’écrit et s’efface', () async {
    await dao.insert(row('e-1'));
    await dao.markError('e-1', 'tooLarge');
    expect((await dao.byEmbedId('e-1'))!.error, 'tooLarge');
    await dao.markError('e-1', null);
    expect((await dao.byEmbedId('e-1'))!.error, isNull);
  });

  test('`watch` suit la ligne, `remove` la retire', () async {
    await dao.insert(row('e-1'));
    final seen = <String?>[];
    final sub = dao.watch(embedId: 'e-1').listen((r) => seen.add(r?.error));
    await pumpEventQueue();
    await dao.markError('e-1', 'network');
    await pumpEventQueue();
    await dao.remove('e-1');
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [null, 'network', null]);
    expect(await dao.all(), isEmpty);
  });

  test('`watch` sans identifiant rend nul', () async {
    expect(await dao.watch().first, isNull);
  });

  test('le brouillon se lit et se patche ; la ligne synchronisée se lit',
      () async {
    expect(await dao.localContent('n-1'), isNull);
    expect(
        await dao.patchLocalContent('n-1', '{}', DateTime.utc(2026)), isFalse);

    await db.into(db.localNotes).insert(LocalNotesCompanion.insert(
          id: 'n-1',
          content: const Value('{"ops":[]}'),
          clientCreatedAt: DateTime.utc(2026, 10, 1),
          clientUpdatedAt: DateTime.utc(2026, 10, 1),
          dirty: const Value(false),
        ));
    expect((await dao.localContent('n-1'))!.content, '{"ops":[]}');

    final patched = jsonEncode({
      'ops': [
        {'insert': 'x\n'},
      ],
    });
    final at = DateTime.utc(2026, 10, 11, 9);
    expect(await dao.patchLocalContent('n-1', patched, at), isTrue);
    final local = await (db.select(db.localNotes)
          ..where((n) => n.id.equals('n-1')))
        .getSingle();
    expect(local.content, patched);
    expect(local.dirty, isTrue);
    expect(local.clientUpdatedAt.toUtc(), at);

    await db.syncDao.applyPage(
      db.syncDao.spiritualNotesCollection,
      upserts: [
        SpiritualNotesCompanion.insert(
          id: 'n-1',
          content: const Value('{"ops":[{"insert":"s\\n"}]}'),
          updatedAt: Value(DateTime.utc(2026, 10, 2)),
        ),
      ],
      cursor: 'c-notes',
    );
    expect(await dao.syncedContent('n-1'), '{"ops":[{"insert":"s\\n"}]}');
  });
}
