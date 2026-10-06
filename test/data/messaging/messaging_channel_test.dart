/// **Le canal `users/{id}`** (#140) : ce qu'il décode, comment il s'ouvre, et ce
/// que le lien fait de ce qu'il reçoit.
///
/// Trois étages, comme la radio (`radio_live_channel_test.dart`) : le décodage
/// pur, le transport SSE sur un `Dio` doublé, et le lien — pilotable à la main —
/// qui range, rattrape et se rouvre.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/messaging_channel.dart';
import 'package:maison_du_miracle/data/messaging/messaging_link.dart';
import 'package:maison_du_miracle/data/messaging/sse_messaging_channel.dart';

const String _me = '019a1000-0000-7000-8000-00000000me01';
final String _channel = userChannelName(_me);

String _frame(String channel, Object? payload) =>
    jsonEncode({'channel': channel, 'payload': payload});

const Map<String, Object?> _message = {
  'id': '019a3000-0000-7000-8000-00000000msg1',
  'groupId': '019a2000-0000-7000-8000-000000grp001',
  'authorId': '019a1000-0000-7000-8000-0000000peer1',
  'isSystem': false,
  'body': null,
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-10-05T10:00:00.412+00:00',
  'deletedAt': null,
};

/// Transmit, doublé : un flux d'événements qu'on alimente, un abonnement qu'on
/// accepte ou refuse.
class _FakeTransmit implements HttpClientAdapter {
  _FakeTransmit({this.subscribeStatus = 204});

  final int subscribeStatus;
  final List<RequestOptions> requests = [];
  final StreamController<Uint8List> body = StreamController<Uint8List>();

  void emit(String raw) => body.add(Uint8List.fromList(utf8.encode(raw)));

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
      return ResponseBody.fromString('', subscribeStatus);
    }
    throw StateError('route non doublée : $path');
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(HttpClientAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..httpClientAdapter = adapter;

/// Un canal piloté à la main.
class _ScriptedChannel implements MessagingChannel {
  final List<String> watched = [];
  int cancelled = 0;
  StreamController<MessagingEvent>? _current;

  @override
  Stream<MessagingEvent> watch(String userId) {
    watched.add(userId);
    final controller = StreamController<MessagingEvent>();
    controller.onCancel = () {
      cancelled++;
      if (_current == controller) _current = null;
    };
    _current = controller;
    return controller.stream;
  }

  void emit(MessagingEvent event) => _current!.add(event);
  void opened() => emit(const MessagingChannelOpened());
  void drop() => _current!.close();
  void breakDown() => _current!.addError(const SocketException('coupé'));
  void refuse() => _current!.addError(const MessagingChannelRefused(403));
}

MessagingRowEvent _row(Map<String, Object?> row) => MessagingRowEvent(
      type: 'message.created',
      collection: SyncCollectionKey.groupMessages,
      row: row,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Le décodage', () {
    test('chaque type du contrat range sa ligne dans SA collection', () {
      const cases = {
        'message.created': ('message', SyncCollectionKey.groupMessages),
        'message.updated': ('message', SyncCollectionKey.groupMessages),
        'message.deleted': ('message', SyncCollectionKey.groupMessages),
        'membership.changed': ('membership', SyncCollectionKey.groupMembers),
        'group.updated': ('group', SyncCollectionKey.groups),
        'read.advanced': ('read', SyncCollectionKey.groupReads),
        // M8 (#146).
        'arrangement.changed': (
          'arrangement',
          SyncCollectionKey.groupArrangements
        ),
      };
      for (final MapEntry(key: type, value: (key, collection))
          in cases.entries) {
        final event = decodeMessagingData(
          _frame(_channel, {
            'type': type,
            key: {'id': 'x', 'groupId': 'g'},
          }),
          channel: _channel,
        );
        expect(event, isA<MessagingRowEvent>(), reason: type);
        final row = event! as MessagingRowEvent;
        expect(row.collection, collection, reason: type);
        expect(row.row['id'], 'x');
      }
    });

    test('la ligne arrive telle quelle — corps nul compris', () {
      final event = decodeMessagingData(
        _frame(_channel, {'type': 'message.created', 'message': _message}),
        channel: _channel,
      )! as MessagingRowEvent;
      expect(event.row, _message);
      expect(event.groupId, _message['groupId']);
    });

    test('le battement est un signe de vie, pas une ligne', () {
      expect(
        decodeMessagingData(
          _frame(kTransmitPingChannel, {}),
          channel: _channel,
        ),
        isA<MessagingHeartbeat>(),
      );
    });

    test(
        'un autre canal, un type inconnu, une trame illisible : rien — on '
        'n\'invente pas une ligne', () {
      expect(
        decodeMessagingData(
          _frame('users/quelqu-un-d-autre', {
            'type': 'message.created',
            'message': _message,
          }),
          channel: _channel,
        ),
        isNull,
      );
      expect(
        decodeMessagingData(
          _frame(_channel, {'type': 'reaction.added', 'reaction': {}}),
          channel: _channel,
        ),
        isNull,
      );
      expect(decodeMessagingData('pas du json', channel: _channel), isNull);
    });

    test('le groupe d\'une ligne `groups` est son `id`', () {
      const event = MessagingRowEvent(
        type: 'group.updated',
        collection: SyncCollectionKey.groups,
        row: {'id': 'g-9'},
      );
      expect(event.groupId, 'g-9');
    });
  });

  group('Le transport', () {
    test(
        'le flux part d\'abord, l\'abonnement à users/<moi> ensuite, puis '
        'l\'ouverture est annoncée', () async {
      final server = _FakeTransmit();
      final events = <MessagingEvent>[];
      final sub = SseMessagingChannel(client: _dio(server), mintUid: () => 'u1')
          .watch(_me)
          .listen(events.add);
      await pumpEventQueue();

      expect(server.requests.map((r) => r.uri.path), [
        '/__transmit/events',
        '/__transmit/subscribe',
      ]);
      expect(server.requests.first.queryParameters['uid'], 'u1');
      expect(server.requests.first.receiveTimeout, Duration.zero);
      expect(server.requests.last.data, {'uid': 'u1', 'channel': _channel});
      expect(events.single, isA<MessagingChannelOpened>());
      await sub.cancel();
    });

    test('une trame devient une ligne, un battement un signe de vie', () async {
      final server = _FakeTransmit();
      final events = <MessagingEvent>[];
      final sub = SseMessagingChannel(client: _dio(server), mintUid: () => 'u2')
          .watch(_me)
          .listen(events.add);
      await pumpEventQueue();

      final frame =
          _frame(_channel, {'type': 'message.created', 'message': _message});
      // Coupée en deux au milieu : une socket rend des morceaux, pas des lignes.
      server.emit('data: ${frame.substring(0, 20)}');
      server.emit('${frame.substring(20)}\n\n');
      server.emit('data: ${_frame(kTransmitPingChannel, {})}\n\n');
      await pumpEventQueue();

      expect(events[1], isA<MessagingRowEvent>());
      expect(events[2], isA<MessagingHeartbeat>());
      await sub.cancel();
    });

    test('un refus d\'abonnement est un refus, pas une panne', () async {
      final server = _FakeTransmit(subscribeStatus: 403);
      Object? error;
      SseMessagingChannel(client: _dio(server), mintUid: () => 'u3')
          .watch(_me)
          .listen((_) {}, onError: (Object e) => error = e);
      await pumpEventQueue();

      expect(error, isA<MessagingChannelRefused>());
    });
  });

  group('Le lien', () {
    late _ScriptedChannel channel;
    late List<String> log;
    late List<MessagingRowEvent> applied;
    late bool groupKnown;
    late MessagingLink link;

    setUp(() {
      channel = _ScriptedChannel();
      log = [];
      applied = [];
      groupKnown = true;
      link = MessagingLink(
        userId: _me,
        channel: channel,
        apply: (event) async {
          applied.add(event);
          log.add('apply');
          return groupKnown;
        },
        resynchronize: () async => log.add('cycle'),
        retryDelay: const Duration(milliseconds: 10),
        silenceLimit: const Duration(milliseconds: 200),
      );
    });

    tearDown(() => link.close());

    test('il s\'ouvre sur MON canal', () async {
      link.open();
      expect(channel.watched, [_me]);
    });

    test('chaque (re)connexion lance un cycle de rattrapage', () async {
      link.open();
      channel.opened();
      await pumpEventQueue();
      expect(log, ['cycle']);
    });

    test(
        'une ligne est RANGÉE, et ne déclenche pas de cycle quand son groupe '
        'est connu', () async {
      link.open();
      channel.emit(_row(_message));
      await pumpEventQueue();

      expect(applied.single.row, _message);
      expect(log, ['apply']);
    });

    test('un groupe inconnu : la ligne est rangée, PUIS un cycle', () async {
      groupKnown = false;
      link.open();
      channel.emit(_row(_message));
      await pumpEventQueue();

      expect(log, ['apply', 'cycle']);
    });

    test('les lignes se rangent dans l\'ordre d\'arrivée', () async {
      link.open();
      channel
        ..emit(_row({..._message, 'id': 'a'}))
        ..emit(_row({..._message, 'id': 'b'}))
        ..emit(_row({..._message, 'id': 'c'}));
      await pumpEventQueue();

      expect(applied.map((e) => e.row['id']), ['a', 'b', 'c']);
    });

    test('une ligne qu\'on ne sait pas ranger appelle un cycle, sans lever',
        () async {
      final failing = MessagingLink(
        userId: _me,
        channel: channel,
        apply: (_) async => throw StateError('base occupée'),
        resynchronize: () async => log.add('cycle'),
      );
      addTearDown(failing.close);
      failing.open();
      channel.emit(_row(_message));
      await pumpEventQueue();

      expect(log, ['cycle']);
      expect(failing.lastFailure, isA<StateError>());
    });

    test('le battement ne range rien et ne lance rien', () async {
      link.open();
      channel.emit(const MessagingHeartbeat());
      await pumpEventQueue();
      expect(log, isEmpty);
    });

    test('un canal tombé se rouvre, et sa réouverture rattrape', () async {
      link.open();
      channel.drop();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(channel.watched, hasLength(2));
      channel.opened();
      await pumpEventQueue();
      expect(log, ['cycle']);
    });

    test('une panne de transport se rouvre aussi', () async {
      link.open();
      channel.breakDown();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(channel.watched, hasLength(2));
    });

    test('un refus ne se réessaie JAMAIS', () async {
      link.open();
      channel.refuse();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(channel.watched, hasLength(1));
      expect(link.lastFailure, isA<MessagingChannelRefused>());
    });

    test(
        'un silence trop long APRÈS un battement est une mort : la connexion '
        'est rouverte', () async {
      link.open();
      channel.emit(const MessagingHeartbeat());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(channel.watched.length, greaterThanOrEqualTo(2));
    });

    test('sans battement vu, le silence ne rouvre rien', () async {
      link.open();
      channel.opened();
      channel.emit(_row(_message));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(channel.watched, hasLength(1));
    });

    test('un battement tient la connexion en vie', () async {
      link.open();
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        channel.emit(const MessagingHeartbeat());
      }
      expect(channel.watched, hasLength(1));
    });

    test('l\'arrière-plan ferme, le retour rouvre — et l\'ouverture rattrape',
        () async {
      link.open();
      link.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(channel.cancelled, 1);
      expect(link.isConnected, isFalse);

      link.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(channel.watched, hasLength(2));
      channel.opened();
      await pumpEventQueue();
      expect(log, ['cycle']);
    });

    test('`inactive` ne ferme rien', () async {
      link.open();
      link.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(link.isConnected, isTrue);
      expect(channel.cancelled, 0);
    });

    test('fermer rend la connexion, et un retour ne rouvre plus rien',
        () async {
      link.open();
      await link.close();
      expect(channel.cancelled, 1);
      link.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(channel.watched, hasLength(1));
    });
  });

  group('Le chien de garde adaptatif (minuterie simulée, 60 s réelles)', () {
    // Le serveur ne bat pas pour l'instant (`pingInterval` retiré) : le
    // constat de silence ne s'arme qu'au premier `$$transmit/ping` reçu sur la
    // connexion courante. `testWidgets` simule l'horloge des minuteries.
    MessagingLink linkOn(_ScriptedChannel channel, List<String> log) =>
        MessagingLink(
          userId: _me,
          channel: channel,
          apply: (_) async => true,
          resynchronize: () async => log.add('cycle'),
        );

    // `close` rend ses minuteries **avant** son premier `await` ; l'attendre
    // sous l'horloge simulée bloquerait le harnais (l'annulation d'abonnement
    // se termine dans la zone racine, que `testWidgets` ne fait pas tourner).
    Future<void> closeUnderFakeClock(WidgetTester tester, MessagingLink link) {
      unawaited(link.close());
      return tester.pump();
    }

    testWidgets('sans battement : aucune reconnexion après 5 min de silence',
        (tester) async {
      final channel = _ScriptedChannel();
      final log = <String>[];
      final link = linkOn(channel, log);
      link.open();
      channel.opened();
      await tester.pump();
      expect(log, ['cycle']);

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(minutes: 1));
      }

      expect(channel.watched, hasLength(1));
      expect(channel.cancelled, 0);
      expect(log, ['cycle'], reason: 'aucun cycle de plus sur un canal calme');
      await closeUnderFakeClock(tester, link);
    });

    testWidgets('un battement, puis plus de 60 s de silence : UNE reconnexion',
        (tester) async {
      final channel = _ScriptedChannel();
      final link = linkOn(channel, <String>[]);
      link.open();
      channel.opened();
      channel.emit(const MessagingHeartbeat());
      await tester.pump();

      await tester.pump(const Duration(seconds: 59));
      expect(channel.watched, hasLength(1), reason: 'pas avant la limite');
      await tester.pump(const Duration(seconds: 2));
      expect(channel.watched, hasLength(2));

      // La connexion neuve repart désarmée : sans nouveau battement, son
      // silence ne la rouvre pas.
      await tester.pump(const Duration(minutes: 5));
      expect(channel.watched, hasLength(2));
      await closeUnderFakeClock(tester, link);
    });

    testWidgets('un battement régulier tient la connexion en vie',
        (tester) async {
      final channel = _ScriptedChannel();
      final link = linkOn(channel, <String>[]);
      link.open();
      for (var i = 0; i < 10; i++) {
        channel.emit(const MessagingHeartbeat());
        await tester.pump(const Duration(seconds: 25));
      }
      expect(channel.watched, hasLength(1));
      await closeUnderFakeClock(tester, link);
    });
  });

  test(
      'le canal par groupe n\'est plus ouvert : aucun fichier de lib/ ne '
      'construit `groups/{id}`', () {
    // Le contrat M1a : « M1b ne doit plus s'y abonner ». Le canal reste servi
    // pour le parc installé ; un client qui s'y réabonnerait doublerait le
    // trafic pour rien.
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final source in sources) {
      final code = source
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code,
        isNot(contains("'groups/\$")),
        reason: '${source.path} construit un nom de canal par groupe',
      );
    }
  });
}
