/// **Les collections `spiritual_notes` et `note_categories`, de bout en
/// bout** (#190) : que les lignes servies traversent `sync_rows.dart`, qu'une
/// rétractation voyage, qu'un serveur en retard ne coûte rien.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/branch_filter.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';
import 'package:maison_du_miracle/models/note_view.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

const _noteId = '019f8000-0000-7000-8000-000000000001';
const _categoryId = '019f8000-0000-7000-8000-0000000000c1';

/// Une note telle que la sert `GET /sync/spiritual_notes` (contrat N1).
const Map<String, Object?> _notePayload = {
  'id': _noteId,
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'teachingId': '019f7000-0000-7000-8000-000000000001',
  'title': 'Objectifs du mardi',
  'content': {
    'ops': [
      {'insert': 'Envoyer la proposition\n'},
    ],
  },
  'body': 'Envoyer la proposition',
  'categoryId': _categoryId,
  'pinned': true,
  'clientCreatedAt': '2026-10-10T08:00:00.000Z',
  'createdAt': '2026-10-10T08:00:02.000Z',
  'updatedAt': '2026-10-11T10:00:00.000Z',
  'deletedAt': null,
};

const Map<String, Object?> _categoryPayload = {
  'id': _categoryId,
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'name': 'Important',
  'color': 'blue',
  'clientCreatedAt': '2026-10-10T07:00:00.000Z',
  'createdAt': '2026-10-10T07:00:01.000Z',
  'updatedAt': '2026-10-10T07:00:01.000Z',
  'deletedAt': null,
};

void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;

  final cursor = serverCursor(
    updatedAtIso: '2026-10-11T10:00:00.000Z',
    id: _noteId,
  );

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
    dao = db.syncDao;
  });

  tearDown(() => db.close());

  Map<String, Object?> manifest({String? c}) => {
        'scope_version': 1,
        'collections': [
          for (final key in [
            SyncCollectionKey.noteCategories,
            SyncCollectionKey.spiritualNotes,
          ])
            manifestEntry(
              key,
              partition: 'private',
              currentCursor: c ?? cursor,
              hasChanges: true,
              fromZero: c == null,
            ),
        ],
      };

  SyncEngine engine() => SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) =>
                c.key == SyncCollectionKey.spiritualNotes ||
                c.key == SyncCollectionKey.noteCategories)
            .toList(growable: false),
      );

  group('Le registre', () {
    test('les deux collections sont là, privées, hors filtre de branche', () {
      final keys = syncedCollections().map((c) => c.key).toList();
      expect(keys, contains(SyncCollectionKey.spiritualNotes));
      expect(keys, contains(SyncCollectionKey.noteCategories));
      // Les catégories avant les notes qu'elles colorent.
      expect(
        keys.indexOf(SyncCollectionKey.noteCategories),
        lessThan(keys.indexOf(SyncCollectionKey.spiritualNotes)),
      );
      expect(isBranchScoped(SyncCollectionKey.spiritualNotes), isFalse);
      expect(isBranchScoped(SyncCollectionKey.noteCategories), isFalse);
      expect(kSyncCollections[SyncCollectionKey.spiritualNotes], 'private');
      expect(kSyncCollections[SyncCollectionKey.noteCategories], 'private');
    });
  });

  group('Le tirage', () {
    test('une note et sa catégorie entrent au magasin', () async {
      server
        ..serveManifest(manifest())
        ..serveCollection(
          'note_categories',
          deltaPage(items: const [_categoryPayload], nextCursor: cursor),
        )
        ..serveCollection(
          'spiritual_notes',
          deltaPage(items: const [_notePayload], nextCursor: cursor),
        );

      final report = await engine().synchronize();
      expect(report.pulled, [
        SyncCollectionKey.noteCategories,
        SyncCollectionKey.spiritualNotes,
      ]);

      final note = (await db.notesDao.watchNotes().first).single;
      expect(note.id, _noteId);
      expect(note.title, 'Objectifs du mardi');
      expect(note.body, 'Envoyer la proposition');
      expect(note.pinned, isTrue);
      expect(note.categoryId, _categoryId);
      expect(note.teachingId, '019f7000-0000-7000-8000-000000000001');
      expect(note.updatedAt, DateTime.utc(2026, 10, 11, 10));
      // Le Delta est rangé brut, ré-encodé : l'éditeur riche le relit.
      expect(note.content, '{"ops":[{"insert":"Envoyer la proposition\\n"}]}');

      final category = (await db.notesDao.watchCategories().first).single;
      expect(category.name, 'Important');
      expect(category.color, NoteColor.blue);
    });

    test('une note sans titre ni corps ni contenu se range quand même',
        () async {
      server
        ..serveManifest(manifest())
        ..serveCollection(
          'spiritual_notes',
          deltaPage(items: const [
            {
              'id': _noteId,
              'updatedAt': '2026-10-11T10:00:00.000Z',
            },
          ], nextCursor: cursor),
        );

      await engine().synchronize();

      final note = (await db.notesDao.watchNotes().first).single;
      expect(note.title, isNull);
      expect(note.body, '');
      expect(note.content, isNull);
      expect(note.pinned, isFalse);
    });

    test('une rétractation retire la note, et la catégorie', () async {
      server
        ..serveManifests([manifest(), manifest(c: 'c2')])
        ..servePages('note_categories', [
          deltaPage(items: const [_categoryPayload], nextCursor: cursor),
          deltaPage(items: const [
            {'id': _categoryId, 'deletedAt': '2026-10-12T00:00:00.000Z'},
          ], nextCursor: 'c2'),
        ])
        ..servePages('spiritual_notes', [
          deltaPage(items: const [_notePayload], nextCursor: cursor),
          deltaPage(items: const [
            {'id': _noteId, 'deletedAt': '2026-10-12T00:00:00.000Z'},
          ], nextCursor: 'c2'),
        ]);

      await engine().synchronize();
      expect(await db.notesDao.watchNotes().first, hasLength(1));

      await engine().synchronize();
      expect(await db.notesDao.watchNotes().first, isEmpty);
      expect(await db.notesDao.watchCategories().first, isEmpty);
    });

    test('le 404 d\'un serveur en retard saute les collections', () async {
      server.serveManifest(manifest());

      final report = await engine().synchronize();

      expect(report.pulled, isEmpty);
      expect(await db.notesDao.watchNotes().first, isEmpty);
    });
  });
}
