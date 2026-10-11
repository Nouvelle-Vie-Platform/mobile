/// **Joindre un média à une note** (N4, mobile#192) : embed tout de suite,
/// bornes vérifiées **avant** le `PUT`, reprise à l'étape atteinte, cause
/// définitive non rejouée.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/messaging/media/media_outbox.dart';
import 'package:maison_du_miracle/data/notes_media/note_attachment_content.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_composer.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_dao.dart';

import '../../../data/local/local_database_fixtures.dart';
import 'note_media_doubles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NoteMediaDao dao;
  late ScriptedNoteTransport transport;
  late CopyPreparer preparer;
  late Directory outboxRoot;
  late Directory sources;
  late NoteMediaComposer composer;
  late QuillController controller;
  late int resends;
  var minted = 0;

  const noteId = 'n-1';
  final now = DateTime.utc(2026, 10, 11, 10);

  setUp(() {
    db = openTestDatabase();
    dao = NoteMediaDao(db);
    transport = ScriptedNoteTransport();
    preparer = CopyPreparer();
    outboxRoot = Directory.systemTemp.createTempSync('n4_outbox');
    sources = Directory.systemTemp.createTempSync('n4_src');
    resends = 0;
    minted = 0;
    controller = QuillController.basic();
    composer = NoteMediaComposer(
      dao: dao,
      transport: transport,
      preparer: preparer,
      outbox: MediaOutbox(root: () async => outboxRoot),
      resendNotes: () async => resends++,
      now: () => now,
      mintId: () => 'e-${minted++}',
    );
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
    for (final dir in [outboxRoot, sources]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  String source(String name, int bytes) {
    final file = File('${sources.path}/$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 7));
    return file.path;
  }

  List<Map<String, dynamic>> embeds() => [
        for (final op in controller.document.toDelta().toList())
          if (attachmentOf({'insert': op.data}) case final data?) data,
      ];

  Future<void> seedLocal(String content) =>
      db.into(db.localNotes).insert(LocalNotesCompanion.insert(
            id: noteId,
            content: Value(content),
            body: const Value('x'),
            clientCreatedAt: DateTime.utc(2026, 10, 1),
            clientUpdatedAt: DateTime.utc(2026, 10, 1),
            dirty: const Value(false),
          ));

  String deltaWith(Map<String, Object?> attachment) => jsonEncode({
        'ops': [
          {'insert': 'avant\n'},
          {
            'insert': {'nvAttachment': attachment},
          },
          {'insert': '\n'},
        ],
      });

  group('l’embed paraît tout de suite', () {
    test('avant le premier await, avec localId et sans clé', () async {
      final sent = composer.attach(
        noteId: noteId,
        controller: controller,
        source: NoteMediaSource(
          kind: 'image',
          path: source('IMG_1.jpg', 500),
          name: 'IMG_1.jpg',
        ),
      );
      final pending = embeds().single;
      expect(pending[kNoteAttachmentLocalId], 'e-0');
      expect(pending.containsKey('key'), isFalse);
      expect(pending['name'], 'IMG_1.jpg');
      await sent;
    });

    test('une photo : préparée, montée, la clé posée, le brouillon relancé',
        () async {
      await composer.attach(
        noteId: noteId,
        controller: controller,
        source: NoteMediaSource(
          kind: 'image',
          path: source('IMG_2.jpg', 500),
          name: 'IMG_2.jpg',
        ),
      );
      final data = embeds().single;
      expect(data['key'], startsWith('note-media/owner/'));
      expect(data.containsKey(kNoteAttachmentLocalId), isFalse);
      expect(data['width'], 1600);
      expect(data['height'], 1200);
      expect(data['mime'], 'image/jpeg');
      expect(transport.uploads, hasLength(1));
      expect(resends, 1);
      final row = (await dao.byEmbedId('e-0'))!;
      expect(row.key, data['key']);
      expect(row.error, isNull);
    });

    test('un audio enregistré part tel quel, en `audio/mp4` déclaré', () async {
      await composer.attach(
        noteId: noteId,
        controller: controller,
        source: NoteMediaSource(
          kind: 'audio',
          path: source('rec.m4a', 300),
          name: 'Enregistrement audio',
          mime: 'audio/mp4',
          durationSeconds: 12,
        ),
      );
      expect(preparer.images + preparer.videos, 0);
      expect(transport.tickets.single,
          {'kind': 'audio', 'contentType': 'audio/mp4'});
      expect(embeds().single['duration'], 12);
    });

    test('une vidéo : sondée, compressée, vignette montée à part', () async {
      await composer.attach(
        noteId: noteId,
        controller: controller,
        source: NoteMediaSource(
          kind: 'video',
          path: source('clip.mov', 800),
          name: 'clip.mov',
        ),
      );
      final data = embeds().single;
      expect(preparer.videos, 1);
      expect(transport.uploads, hasLength(2));
      expect(data['thumbKey'], startsWith('note-media/owner/'));
      expect(data['duration'], 42);
      expect(data['mime'], 'video/mp4');
    });
  });

  group('les bornes, avant le PUT', () {
    test('trop lourd : refusé sans montée, et pas rejoué après synchro',
        () async {
      transport.maxBytes = 10;
      await composer.attach(
        noteId: noteId,
        controller: controller,
        source: NoteMediaSource(
          kind: 'image',
          path: source('big.jpg', 500),
          name: 'big.jpg',
        ),
      );
      expect(transport.uploads, isEmpty);
      expect((await dao.byEmbedId('e-0'))!.error, 'tooLarge');
      expect(embeds().single[kNoteAttachmentLocalId], 'e-0');

      final tickets = transport.tickets.length;
      await composer.resendPending();
      expect(transport.tickets.length, tickets, reason: 'définitif');

      // « Réessayer » essaie quand même.
      await composer.retry('e-0');
      expect(transport.tickets.length, tickets + 1);
    });

    test('vidéo trop longue : refusée avant la compression', () async {
      preparer.videoSeconds = 200;
      await composer.attach(
        noteId: noteId,
        controller: controller,
        source: NoteMediaSource(
          kind: 'video',
          path: source('long.mp4', 800),
          name: 'long.mp4',
        ),
      );
      expect(preparer.probes, 1);
      expect(preparer.videos, 0);
      expect(transport.uploads, isEmpty);
      expect((await dao.byEmbedId('e-0'))!.error, 'tooLong');
    });

    test('type refusé par le serveur : définitif, pas rejoué', () async {
      transport.rejectTicketWith = 'E_NOTE_MEDIA_TYPE_NOT_ALLOWED';
      await composer.attach(
        noteId: noteId,
        controller: controller,
        source: NoteMediaSource(
          kind: 'document',
          path: source('a.pdf', 100),
          name: 'a.pdf',
          mime: 'application/pdf',
        ),
      );
      expect((await dao.byEmbedId('e-0'))!.error, 'typeNotAllowed');
      await composer.resendPending();
      expect(transport.tickets, isEmpty);
    });
  });

  group('la reprise, à l’étape atteinte', () {
    test('panne réseau au PUT : ni re-préparation ni double montée', () async {
      transport.failUpload = true;
      await composer.attach(
        noteId: noteId,
        controller: controller,
        source: NoteMediaSource(
          kind: 'image',
          path: source('IMG_3.jpg', 500),
          name: 'IMG_3.jpg',
        ),
      );
      var row = (await dao.byEmbedId('e-0'))!;
      expect(row.error, kNoteMediaNetworkError);
      expect(row.mime, 'image/jpeg', reason: 'préparée');
      expect(row.key, isNull);
      expect(embeds().single['width'], 1600, reason: 'dimensions posées');

      await composer.resendPending();
      row = (await dao.byEmbedId('e-0'))!;
      expect(preparer.images, 1);
      expect(transport.uploads, hasLength(1));
      expect(row.key, isNotNull);
      expect(embeds().single['key'], row.key);
    });

    test('clé posée mais embed pas patché : patché dans le brouillon',
        () async {
      // L'application est morte entre la montée et le patch ; l'écran est
      // fermé.
      await seedLocal(deltaWith({
        'kind': 'document',
        'name': 'a.pdf',
        'mime': 'application/pdf',
        'size': 100,
        kNoteAttachmentLocalId: 'e-9',
      }));
      await dao.insert(PendingNoteMediaCompanion.insert(
        noteId: noteId,
        embedId: 'e-9',
        kind: 'document',
        localPath: source('a.pdf', 100),
        mime: const Value('application/pdf'),
        size: const Value(100),
        key: const Value('note-media/owner/a.pdf'),
      ));

      await composer.resendPending();

      expect(transport.tickets, isEmpty);
      final local = await (db.select(db.localNotes)
            ..where((n) => n.id.equals(noteId)))
          .getSingle();
      expect(local.dirty, isTrue);
      expect(local.clientUpdatedAt.toUtc(), now);
      expect(hasPendingAttachment(local.content), isFalse);
      expect(
          contentCites(local.content, key: 'note-media/owner/a.pdf'), isTrue);
      expect(resends, 1);
    });

    test('livrée : la ligne s’oublie et l’outbox se vide', () async {
      const key = 'note-media/owner/done.jpg';
      final file = File(
          await MediaOutbox(root: () async => outboxRoot).pathFor('e-7.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      await db.syncDao.applyPage(
        db.syncDao.spiritualNotesCollection,
        upserts: [
          SpiritualNotesCompanion.insert(
            id: noteId,
            content: Value(deltaWith({
              'kind': 'image',
              'key': key,
              'name': 'done.jpg',
              'mime': 'image/jpeg',
              'size': 3,
            })),
            updatedAt: Value(DateTime.utc(2026, 10, 2)),
          ),
        ],
        cursor: 'c-notes',
      );
      await dao.insert(PendingNoteMediaCompanion.insert(
        noteId: noteId,
        embedId: 'e-7',
        kind: 'image',
        localPath: file.path,
        mime: const Value('image/jpeg'),
        key: const Value(key),
      ));

      await composer.resendPending();

      expect(await dao.all(), isEmpty);
      expect(file.existsSync(), isFalse);
    });

    test('effacée par l’utilisateur : oubliée, sans ticket', () async {
      await seedLocal(jsonEncode({
        'ops': [
          {'insert': 'plus rien\n'},
        ],
      }));
      await dao.insert(PendingNoteMediaCompanion.insert(
        noteId: noteId,
        embedId: 'e-8',
        kind: 'image',
        localPath: source('gone.jpg', 10),
      ));

      await composer.resendPending();

      expect(await dao.all(), isEmpty);
      expect(transport.tickets, isEmpty);
    });
  });

  group('le contenu envoyé au serveur', () {
    test('sans embed en attente ni champ local', () {
      final json = jsonEncode({
        'ops': [
          {'insert': 'a\n'},
          {
            'insert': {
              'nvAttachment': {
                'kind': 'image',
                'name': 'x.jpg',
                kNoteAttachmentLocalId: 'e-1',
              },
            },
          },
          {'insert': '\n'},
          {
            'insert': {
              'nvAttachment': {
                'kind': 'document',
                'key': 'note-media/o/y.pdf',
                'name': 'y.pdf',
                'mime': 'application/pdf',
                'size': 4,
                'stray': true,
              },
            },
          },
          {'insert': '\n'},
        ],
      });
      expect(hasPendingAttachment(json), isTrue);
      final sent = serverNoteContent(json)!;
      expect(hasPendingAttachment(sent), isFalse);
      final ops = (jsonDecode(sent) as Map)['ops'] as List;
      expect(ops, hasLength(4));
      expect(attachmentOf(ops[2]), {
        'kind': 'document',
        'key': 'note-media/o/y.pdf',
        'name': 'y.pdf',
        'mime': 'application/pdf',
        'size': 4,
      });
      expect(serverNoteContent(null), isNull);
    });

    test('insertion au milieu d’une ligne : l’embed seul sur la sienne', () {
      controller.replaceText(
          0, 0, 'abcd', const TextSelection.collapsed(offset: 2));
      insertAttachmentEmbed(controller, {'kind': 'image', 'name': 'p.jpg'});
      final ops = controller.document.toDelta().toList();
      expect(ops.first.data, 'ab\n');
      expect(attachmentOf({'insert': ops[1].data})?['name'], 'p.jpg');
      expect(ops[2].data, startsWith('\ncd'));
      expect(controller.selection.baseOffset, 5);
    });
  });
}
