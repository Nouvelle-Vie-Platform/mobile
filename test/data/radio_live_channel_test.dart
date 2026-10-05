/// **Le canal radio et ses événements** (#135) — le décodage, la lecture des
/// trames, et le protocole Transmit repris des groupes.
///
/// Ici, contrairement au canal d'un groupe, **la charge est lue** : ces tests
/// éprouvent donc ce que le décodeur accepte et, surtout, ce qu'il refuse
/// d'inventer.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/radio/radio_channel.dart';
import 'package:maison_du_miracle/data/radio/radio_live.dart';
import 'package:maison_du_miracle/data/radio/sse_radio_channel.dart';

String _frame(String channel, Map<String, Object?> payload) =>
    jsonEncode({'channel': channel, 'payload': payload});

/// Un serveur Transmit réduit à ses routes : le flux, et l'abonnement — dont
/// la réponse se règle **par canal**.
class _FakeTransmit implements HttpClientAdapter {
  _FakeTransmit({this.statusFor = const {}});

  final Map<String, int> statusFor;
  final List<RequestOptions> requests = [];
  final StreamController<Uint8List> body = StreamController<Uint8List>();

  void emitBytes(List<int> bytes) => body.add(Uint8List.fromList(bytes));
  void emit(String raw) => emitBytes(utf8.encode(raw));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    if (path == '/__transmit/events') {
      return ResponseBody(
        body.stream,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    }
    if (path == '/__transmit/subscribe') {
      final channel = (options.data as Map)['channel'] as String;
      return ResponseBody.fromString('', statusFor[channel] ?? 204);
    }
    throw StateError('route non doublée : $path');
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeTransmit server) =>
    Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..httpClientAdapter = server;

void main() {
  group('Le décodage d\'une trame', () {
    test('live.started porte le direct et le compteur, en entier', () {
      final event = decodeRadioChannelData(_frame('radio', {
        'type': 'live.started',
        'live': {'startedAt': '2026-10-05T18:00:00.000Z'},
        'listeners': 42,
      }));
      expect(event, isA<RadioLiveChanged>());
      final changed = event! as RadioLiveChanged;
      expect(changed.live?.startedAt, DateTime.utc(2026, 10, 5, 18));
      expect(changed.listeners, 42);
    });

    test('live.ended ferme le direct, même si la charge porte autre chose', () {
      final event = decodeRadioChannelData(_frame('radio', {
        'type': 'live.ended',
        'live': null,
        'listeners': null,
      })) as RadioLiveChanged;
      expect(event.live, isNull);
      expect(event.listeners, isNull);
    });

    test('listeners : un nombre, ou null pour cacher le compteur', () {
      expect(
        (decodeRadioChannelData(_frame('radio', {
          'type': 'listeners',
          'listeners': 17,
        })) as RadioListenersChanged)
            .listeners,
        17,
      );
      expect(
        (decodeRadioChannelData(_frame('radio', {
          'type': 'listeners',
          'listeners': null,
        })) as RadioListenersChanged)
            .listeners,
        isNull,
      );
    });

    test('reactions : les cinq clés, un compte illisible vaut zéro', () {
      final event = decodeRadioChannelData(_frame('radio', {
        'type': 'reactions',
        'counts': {
          'heart': 12,
          'pray': 3,
          'praise': 0,
          'fire': 'beaucoup',
          'amen': 1,
        },
        'since': '2026-10-05T18:01:00.000Z',
        'windowMs': 1000,
      })) as RadioReactionsAggregated;
      expect(event.counts, {
        RadioReaction.heart: 12,
        RadioReaction.pray: 3,
        RadioReaction.praise: 0,
        RadioReaction.fire: 0,
        RadioReaction.amen: 1,
      });
    });

    test('comment.posted : la forme exacte de GET /radio/comments', () {
      final event = decodeRadioChannelData(_frame('radio', {
        'type': 'comment.posted',
        'comment': {
          'id': 'c-1',
          'body': 'Amen !',
          'createdAt': '2026-10-05T18:02:11.000Z',
          'author': {'kind': 'guest', 'name': 'Kossi', 'avatarUrl': null},
        },
      })) as RadioCommentPosted;
      expect(event.comment.id, 'c-1');
      expect(event.comment.body, 'Amen !');
      expect(event.comment.authorName, 'Kossi');
      expect(event.comment.byGuest, isTrue);
      expect(event.comment.avatarUrl, isNull);
    });

    test('comment.hidden : l\'identifiant seul', () {
      final event = decodeRadioChannelData(_frame('radio', {
        'type': 'comment.hidden',
        'commentId': 'c-1',
      })) as RadioCommentHidden;
      expect(event.commentId, 'c-1');
    });

    test('le canal privé : un signalement, une décision', () {
      final reported = decodeRadioChannelData(_frame('radio/moderation', {
        'type': 'comment.reported',
        'commentId': 'c-9',
      })) as RadioModerationChanged;
      expect(reported.commentId, 'c-9');
      expect(reported.isReview, isFalse);

      final reviewed = decodeRadioChannelData(_frame('radio/moderation', {
        'type': 'comment.reviewed',
        'commentId': 'c-9',
        'outcome': 'hidden',
      })) as RadioModerationChanged;
      expect(reviewed.isReview, isTrue);
      expect(reviewed.outcome, 'hidden');
    });

    test('rien n\'est inventé : autre canal, type inconnu, charge illisible',
        () {
      for (final data in [
        _frame('groups/42', {'type': 'comment.posted'}),
        _frame('radio', {'type': 'quelque.chose'}),
        _frame('radio', {
          'type': 'comment.posted',
          'comment': {'id': 'x'}
        }),
        _frame('radio', {'type': 'comment.hidden'}),
        _frame('radio/moderation', {'type': 'comment.reported'}),
        _frame(r'$$transmit/ping', {}),
        'pas du JSON',
        '[]',
      ]) {
        expect(decodeRadioChannelData(data), isNull, reason: data);
      }
    });
  });

  group('La lecture des trames', () {
    test(
        'une ligne vide termine un événement, les commentaires ne comptent pas',
        () {
      final reader = SseEventReader();
      expect(reader.consume(':ok\n\n'), isEmpty);
      expect(reader.consume('data: {"a":1}\n'), isEmpty);
      expect(reader.consume('\n'), ['{"a":1}']);
    });

    test('un fragment coupe une ligne ; deux événements dans un fragment', () {
      final reader = SseEventReader();
      expect(reader.consume('data: {"a"'), isEmpty);
      expect(
          reader.consume(':1}\n\ndata: {"b":2}\n\n'), ['{"a":1}', '{"b":2}']);
    });

    test('plusieurs lignes data se joignent, \\r\\n vaut \\n', () {
      final reader = SseEventReader();
      expect(reader.consume('id: 3\r\ndata: un\r\ndata: deux\r\n\r\n'),
          ['un\ndeux']);
    });
  });

  group('Le protocole, celui des groupes', () {
    test('le flux d\'abord, puis l\'abonnement à « radio », sous le même uid',
        () async {
      final server = _FakeTransmit();
      final channel =
          SseRadioChannel(client: _dio(server), mintUid: () => 'u1');
      final events = <RadioChannelEvent>[];
      final sub = channel.watch(moderation: false).listen(events.add);
      await pumpEventQueue();

      expect(server.requests.map((r) => r.uri.path), [
        '/__transmit/events',
        '/__transmit/subscribe',
      ]);
      expect(server.requests.first.uri.queryParameters['uid'], 'u1');
      expect(server.requests.first.receiveTimeout, Duration.zero);
      expect(server.requests.last.data, {'uid': 'u1', 'channel': 'radio'});
      expect(events.single, isA<RadioChannelOpened>());
      expect((events.single as RadioChannelOpened).moderation, isFalse);
      await sub.cancel();
    });

    test('un modérateur s\'abonne aussi au canal privé, sur la même connexion',
        () async {
      final server = _FakeTransmit();
      final channel =
          SseRadioChannel(client: _dio(server), mintUid: () => 'u2');
      final events = <RadioChannelEvent>[];
      final sub = channel.watch(moderation: true).listen(events.add);
      await pumpEventQueue();

      expect(
        server.requests
            .where((r) => r.uri.path == '/__transmit/subscribe')
            .map((r) => (r.data as Map)['channel']),
        ['radio', 'radio/moderation'],
      );
      expect((events.single as RadioChannelOpened).moderation, isTrue);
      await sub.cancel();
    });

    test('un refus du canal privé ne coupe pas le canal public', () async {
      final server = _FakeTransmit(statusFor: {'radio/moderation': 403});
      final channel =
          SseRadioChannel(client: _dio(server), mintUid: () => 'u3');
      final events = <RadioChannelEvent>[];
      Object? error;
      final sub = channel
          .watch(moderation: true)
          .listen(events.add, onError: (Object e) => error = e);
      await pumpEventQueue();

      expect(error, isNull);
      expect((events.single as RadioChannelOpened).moderation, isFalse);

      server.emit('data: ${_frame('radio', {
            'type': 'listeners',
            'listeners': 12,
          })}\n\n');
      await pumpEventQueue();
      expect(events.last, isA<RadioListenersChanged>());
      await sub.cancel();
    });

    test('un refus du canal public est un refus, pas une panne', () async {
      final server = _FakeTransmit(statusFor: {'radio': 403});
      final channel =
          SseRadioChannel(client: _dio(server), mintUid: () => 'u4');
      Object? error;
      var done = false;
      channel.watch(moderation: false).listen(
            (_) {},
            onError: (Object e) => error = e,
            onDone: () => done = true,
          );
      await pumpEventQueue();
      expect(error, isA<RadioChannelRefused>());
      expect(done, isTrue);
    });

    test(
        'la charge est décodée en UTF-8, même coupée au milieu d\'un caractère',
        () async {
      final server = _FakeTransmit();
      final channel =
          SseRadioChannel(client: _dio(server), mintUid: () => 'u5');
      final events = <RadioChannelEvent>[];
      final sub = channel.watch(moderation: false).listen(events.add);
      await pumpEventQueue();

      final bytes = utf8.encode('data: ${_frame('radio', {
            'type': 'comment.posted',
            'comment': {
              'id': 'c-é',
              'body': 'Gloire à Dieu 🙏',
              'createdAt': '2026-10-05T18:02:11.000Z',
              'author': {'kind': 'member', 'name': 'Élodie M.'},
            },
          })}\n\n');
      // Coupé au milieu de l'emoji (4 octets) : un décodage par fragment
      // rendrait du charabia.
      final cut = bytes.indexOf(0xF0) + 2;
      server.emitBytes(bytes.sublist(0, cut));
      await pumpEventQueue();
      server.emitBytes(bytes.sublist(cut));
      await pumpEventQueue();

      final posted = events.whereType<RadioCommentPosted>().single;
      expect(posted.comment.body, 'Gloire à Dieu 🙏');
      expect(posted.comment.authorName, 'Élodie M.');
      await sub.cancel();
    });

    test('le serveur rend la main : le flux se ferme, l\'appelant rouvrira',
        () async {
      final server = _FakeTransmit();
      final channel =
          SseRadioChannel(client: _dio(server), mintUid: () => 'u6');
      var done = false;
      channel
          .watch(moderation: false)
          .listen((_) {}, onDone: () => done = true);
      await pumpEventQueue();
      await server.body.close();
      await pumpEventQueue();
      expect(done, isTrue);
    });
  });

  test('le canal muet ne s\'ouvre ni ne se ferme', () async {
    var events = 0;
    var done = false;
    final sub = const SilentRadioChannel()
        .watch(moderation: false)
        .listen((_) => events++, onDone: () => done = true);
    await pumpEventQueue();
    expect(events, 0);
    expect(done, isFalse);
    await sub.cancel();
  });
}
