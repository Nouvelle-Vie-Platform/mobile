import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/notes_repository.dart';
import 'package:maison_du_miracle/features/notes_editor/note_content.dart';
import 'package:maison_du_miracle/models/note_view.dart';

import '../helpers/fake_api.dart';

/// **Les quatre routes des notes** (#190, contrat N1), sur un double HTTP :
/// chemin, verbe, corps en `camelCase`, et le silence sur l'échec.
void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpNotesRepository repo;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    api.onUnauthorized = null;
    repo = HttpNotesRepository(client: api);
    serve((_) => jsonReply(200, {'id': 'x'}));
  });

  final note = NoteUpsert(
    id: '019f8000-0000-7000-8000-000000000001',
    title: 'Objectifs',
    content: '{"ops":[{"insert":"Envoyer la proposition\\n"}]}',
    body: 'Envoyer la proposition',
    categoryId: '019f8000-0000-7000-8000-0000000000c1',
    pinned: true,
    teachingId: null,
    clientCreatedAt: DateTime.utc(2026, 10, 11, 8),
    clientUpdatedAt: DateTime.utc(2026, 10, 11, 8, 5),
  );

  group('POST /notes', () {
    test('le corps, en camelCase, le Delta en objet', () async {
      expect(await repo.upsertNote(note), isTrue);

      final request = adapter.lastRequest;
      expect(request.method, 'POST');
      expect(request.path, '/notes');
      final body = adapter.lastBody;
      expect(body['id'], note.id);
      expect(body['title'], 'Objectifs');
      expect(body['body'], 'Envoyer la proposition');
      expect(body['categoryId'], note.categoryId);
      expect(body['pinned'], isTrue);
      expect(body['teachingId'], isNull);
      expect(body['clientCreatedAt'], '2026-10-11T08:00:00.000Z');
      expect(body['clientUpdatedAt'], '2026-10-11T08:05:00.000Z');
      // Un objet, pas une chaîne : le serveur valide `ops` par `ops`.
      expect(body['content'], {
        'ops': [
          {'insert': 'Envoyer la proposition\n'},
        ],
      });
    });

    test('une pièce jointe en montée ne part pas, une montée part nue (#192)',
        () {
      final content = jsonEncode({
        'ops': [
          {'insert': 'Avant\n'},
          {
            'insert': {
              'nvAttachment': {
                'kind': 'image',
                'name': 'a.jpg',
                'mime': 'image/jpeg',
                'size': 10,
                'localId': 'e-1',
              },
            },
          },
          {
            'insert': {
              'nvAttachment': {
                'kind': 'document',
                'key': 'note-media/o/b.pdf',
                'name': 'b.pdf',
                'mime': 'application/pdf',
                'size': 20,
              },
            },
          },
          {'insert': '\n'},
        ],
      });
      final payload = noteUpsertPayload(NoteUpsert(
        id: note.id,
        title: null,
        content: content,
        body: deltaToPlainText(content),
        categoryId: null,
        pinned: false,
        teachingId: null,
        clientCreatedAt: note.clientCreatedAt,
        clientUpdatedAt: note.clientUpdatedAt,
      ));
      final sent = jsonEncode(payload);
      expect(sent, isNot(contains('localId')));
      expect(sent, isNot(contains('e-1')));
      final ops = (payload['content']! as Map)['ops'] as List;
      final embeds = [
        for (final op in ops)
          if ((op as Map)['insert'] is Map) op['insert']['nvAttachment'],
      ];
      expect(embeds, [
        {
          'kind': 'document',
          'key': 'note-media/o/b.pdf',
          'name': 'b.pdf',
          'mime': 'application/pdf',
          'size': 20,
        },
      ]);
      expect(payload['body'], isNot(contains('localId')));
    });

    test('un contenu nul voyage nul', () {
      final payload = noteUpsertPayload(NoteUpsert(
        id: note.id,
        title: null,
        content: null,
        body: 'x',
        categoryId: null,
        pinned: false,
        teachingId: 't',
        clientCreatedAt: note.clientCreatedAt,
        clientUpdatedAt: note.clientUpdatedAt,
      ));
      expect(payload['content'], isNull);
      expect(payload['teachingId'], 't');
    });

    test('une panne est avalée, et rendue « pas parti »', () async {
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'hors ligne',
          ));
      expect(await repo.upsertNote(note), isFalse);
      expect(repo.lastFailure, isA<DioException>());
    });

    test('un 422 aussi', () async {
      serve((_) => errorReply(422, 'E_VALIDATION'));
      expect(await repo.upsertNote(note), isFalse);
    });
  });

  group('DELETE /notes/:id', () {
    test('le chemin', () async {
      expect(await repo.deleteNote(note.id), isTrue);
      expect(adapter.lastRequest.method, 'DELETE');
      expect(adapter.lastRequest.path, '/notes/${note.id}');
    });

    test('un 404 est un succès : la ligne est déjà partie', () async {
      serve((_) => errorReply(404, 'E_NOT_FOUND'));
      expect(await repo.deleteNote(note.id), isTrue);
    });
  });

  group('Les catégories', () {
    test('POST /notes/categories', () async {
      await repo.upsertCategory(
        id: 'c1',
        name: 'Important',
        color: NoteColor.pink,
        clientCreatedAt: DateTime.utc(2026, 10, 11),
      );
      expect(adapter.lastRequest.path, '/notes/categories');
      expect(adapter.lastBody, {
        'id': 'c1',
        'name': 'Important',
        'color': 'pink',
        'clientCreatedAt': '2026-10-11T00:00:00.000Z',
      });
    });

    test('DELETE /notes/categories/:id', () async {
      await repo.deleteCategory('c1');
      expect(adapter.lastRequest.method, 'DELETE');
      expect(adapter.lastRequest.path, '/notes/categories/c1');
    });
  });
}
