/// **Les routes de la page live** (#135) : chemins, corps, lectures, et le
/// rangement des refus — par leur `code`, jamais par le statut seul.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/radio/http_radio_live_repository.dart';
import 'package:maison_du_miracle/data/radio/radio_live.dart';
import 'package:maison_du_miracle/data/radio/radio_live_repository.dart';

/// Un serveur qui répond ce qu'on lui dit, **enveloppe `data` comprise** —
/// l'intercepteur de l'application la déballe, comme en production.
class _FakeServer implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int status = 200;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({HttpRadioLiveRepository repo, _FakeServer server}) _setUp() {
  final server = _FakeServer();
  final dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
    ..httpClientAdapter = server
    ..interceptors.add(unwrapEnvelopeInterceptor);
  return (repo: HttpRadioLiveRepository(client: dio), server: server);
}

const _comment = {
  'id': '0199b1c2-0000-7000-8000-000000000001',
  'body': 'Amen !',
  'createdAt': '2026-10-05T18:02:11.000Z',
  'author': {'kind': 'member', 'name': 'Ama K.', 'avatarUrl': null},
};

void main() {
  group('Les lectures', () {
    test('le fil : direct, commentaires du plus ancien au plus récent, viewer',
        () async {
      final (:repo, :server) = _setUp();
      server.body = {
        'data': {
          'live': {'startedAt': '2026-10-05T18:00:00.000Z'},
          'comments': [
            _comment,
            {..._comment, 'id': 'c-2', 'body': 'Gloire'},
          ],
          'viewer': {
            'kind': 'guest',
            'pseudonym': 'Kossi',
            'silenced': false,
            'canComment': true,
            'moderator': false,
          },
        },
      };
      final thread = await repo.thread();
      expect(server.requests.single.uri.path, '/radio/comments');
      expect(thread.live, isNotNull);
      expect(thread.comments.map((c) => c.body), ['Amen !', 'Gloire']);
      expect(thread.viewer.isGuest, isTrue);
      expect(thread.viewer.pseudonym, 'Kossi');
      expect(thread.viewer.moderator, isFalse);
    });

    test('hors direct : fil fermé, et un commentaire sans identifiant écarté',
        () async {
      final (:repo, :server) = _setUp();
      server.body = {
        'data': {
          'live': null,
          'comments': [
            {..._comment, 'id': null},
          ],
          'viewer': {'kind': 'member', 'pseudonym': null, 'moderator': true},
        },
      };
      final thread = await repo.thread();
      expect(thread.live, isNull);
      expect(thread.comments, isEmpty);
      expect(thread.viewer.moderator, isTrue);
    });

    test('le fil ne garde que les cinquante derniers', () {
      final thread = RadioThread.fromJson({
        'live': {'startedAt': '2026-10-05T18:00:00.000Z'},
        'comments': [
          for (var i = 0; i < 60; i++) {..._comment, 'id': 'c-$i'},
        ],
      });
      expect(thread.comments, hasLength(kRadioCommentWindow));
      expect(thread.comments.last.id, 'c-59');
    });

    test('la file des signalements', () async {
      final (:repo, :server) = _setUp();
      server.body = {
        'data': {
          'live': {'startedAt': '2026-10-05T18:00:00.000Z'},
          'items': [
            {
              'comment': _comment,
              'pendingReports': 2,
              'firstReportedAt': '2026-10-05T18:03:00.000Z',
            },
          ],
        },
      };
      final queue = await repo.moderationQueue();
      expect(server.requests.single.uri.path, '/radio/moderation/comments');
      expect(queue.items.single.pendingReports, 2);
      expect(queue.items.single.comment.authorName, 'Ama K.');
    });
  });

  group('Les écritures', () {
    test('une réaction part sous son identifiant, jamais son emoji', () async {
      final (:repo, :server) = _setUp();
      server.status = 202;
      server.body = {
        'data': {'reaction': 'pray'},
      };
      await repo.react(RadioReaction.pray);
      expect(server.requests.single.method, 'POST');
      expect(server.requests.single.uri.path, '/radio/reactions');
      expect(server.requests.single.data, {'reaction': 'pray'});
    });

    test('un commentaire rend la forme du canal', () async {
      final (:repo, :server) = _setUp();
      server.status = 201;
      server.body = {'data': _comment};
      final comment = await repo.postComment('Amen !');
      expect(server.requests.single.data, {'body': 'Amen !'});
      expect(comment.id, _comment['id']);
    });

    test('l\'heure entendue part avec le commentaire et la réaction (#187)',
        () async {
      final (:repo, :server) = _setUp();
      final heard = DateTime.utc(2026, 10, 5, 18, 2, 3, 250);
      server.status = 201;
      server.body = {'data': _comment};
      await repo.postComment('Amen !', heardAt: heard);
      server.status = 202;
      server.body = {
        'data': {'reaction': 'fire'},
      };
      await repo.react(RadioReaction.fire, heardAt: heard);
      expect(server.requests.map((r) => r.data), [
        {'body': 'Amen !', 'heardAt': '2026-10-05T18:02:03.250Z'},
        {'reaction': 'fire', 'heardAt': '2026-10-05T18:02:03.250Z'},
      ]);
    });

    test('le pseudo', () async {
      final (:repo, :server) = _setUp();
      server.body = {
        'data': {'pseudonym': 'Kossi'},
      };
      expect(await repo.savePseudonym('Kossi'), 'Kossi');
      expect(server.requests.single.method, 'PUT');
      expect(server.requests.single.uri.path, '/radio/pseudonym');
      expect(server.requests.single.data, {'pseudonym': 'Kossi'});
    });

    test('signaler et modérer visent un message', () async {
      final (:repo, :server) = _setUp();
      server.status = 201;
      await repo.report('c-1');
      server.status = 200;
      await repo.hide('c-1');
      await repo.keep('c-1');
      await repo.silence('c-1');
      await repo.resetPseudonym('c-1');
      expect(server.requests.map((r) => '${r.method} ${r.uri.path}'), [
        'POST /radio/comments/c-1/reports',
        'POST /radio/moderation/comments/c-1/hide',
        'POST /radio/moderation/comments/c-1/keep',
        'POST /radio/moderation/comments/c-1/silence',
        'POST /radio/moderation/comments/c-1/reset-pseudonym',
      ]);
    });
  });

  group('Les refus, rangés par leur code', () {
    Future<RadioLiveRefusal> refusalOf(int status, String code) async {
      final (:repo, :server) = _setUp();
      server.status = status;
      server.body = {'code': code};
      try {
        await repo.postComment('x');
      } on RadioLiveException catch (error) {
        expect(error.status, status);
        return error.refusal;
      }
      fail('aucun refus levé');
    }

    test('chaque code a sa place', () async {
      expect(await refusalOf(403, 'E_RADIO_PSEUDONYM_REQUIRED'),
          RadioLiveRefusal.pseudonymRequired);
      expect(await refusalOf(403, 'E_RADIO_AUTHOR_SILENCED'),
          RadioLiveRefusal.silenced);
      expect(await refusalOf(409, 'E_RADIO_COMMENTS_CLOSED'),
          RadioLiveRefusal.closed);
      expect(await refusalOf(429, 'E_RADIO_COMMENT_THROTTLED'),
          RadioLiveRefusal.throttled);
      expect(await refusalOf(429, 'E_RADIO_REACTION_THROTTLED'),
          RadioLiveRefusal.throttled);
      expect(await refusalOf(422, 'E_RADIO_COMMENT_INVALID'),
          RadioLiveRefusal.invalid);
      expect(await refusalOf(422, 'E_RADIO_PSEUDONYM_INVALID'),
          RadioLiveRefusal.pseudonymInvalid);
      expect(await refusalOf(409, 'E_RADIO_COMMENT_ALREADY_REPORTED'),
          RadioLiveRefusal.alreadyReported);
      expect(await refusalOf(404, 'E_RADIO_COMMENT_NOT_FOUND'),
          RadioLiveRefusal.notFound);
      expect(await refusalOf(409, 'E_RADIO_COMMENT_AUTHOR_NOT_GUEST'),
          RadioLiveRefusal.notGuest);
      expect(
          await refusalOf(403, 'E_OUTSIDE_SCOPE'), RadioLiveRefusal.forbidden);
    });

    test('deux 403 ne se confondent pas : le code départage', () async {
      expect(await refusalOf(403, 'E_RADIO_PSEUDONYM_REQUIRED'),
          isNot(await refusalOf(403, 'E_RADIO_AUTHOR_SILENCED')));
    });

    test('sans réponse : une panne de transport', () {
      final error = classifyRadioLiveError(DioException(
        requestOptions: RequestOptions(path: '/radio/comments'),
        type: DioExceptionType.connectionError,
      ));
      expect(error.refusal, RadioLiveRefusal.transport);
    });
  });
}
