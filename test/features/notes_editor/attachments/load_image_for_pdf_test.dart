/// **Les photos du PDF** (N4, mobile#192) : le fichier local d'abord, l'URL
/// signée ensuite, rien sinon.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/notes_media/load_image_for_pdf.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_dao.dart';

import '../../../data/local/local_database_fixtures.dart';
import 'note_media_doubles.dart';

void main() {
  late AppDatabase db;
  late NoteMediaDao dao;
  late FakeNoteMediaUrls urls;
  late Directory dir;

  const key = 'note-media/owner/p.jpg';

  setUp(() {
    db = openTestDatabase();
    dao = NoteMediaDao(db);
    urls = FakeNoteMediaUrls();
    dir = Directory.systemTemp.createTempSync('n4_pdf');
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> pending(String path) => dao.insert(
        PendingNoteMediaCompanion.insert(
          noteId: 'n-1',
          embedId: 'e-1',
          kind: 'image',
          localPath: path,
          key: const Value(key),
        ),
      );

  test('le fichier local tant qu’il existe, sans réseau', () async {
    final file = File('${dir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
    await pending(file.path);
    urls.stored[key] = Uint8List.fromList([9]);

    expect(await loadImageForPdf(key, dao: dao, urls: urls), [1, 2, 3]);
    expect(urls.resolved, isEmpty);
  });

  test('sinon l’URL signée', () async {
    await pending('${dir.path}/parti.jpg');
    urls.stored[key] = Uint8List.fromList([9, 8]);
    expect(await loadImageForPdf(key, dao: dao, urls: urls), [9, 8]);
  });

  test('ni l’un ni l’autre : nul (la photo sort en ligne de texte)', () async {
    expect(await loadImageForPdf(key, dao: dao, urls: urls), isNull);
  });
}
