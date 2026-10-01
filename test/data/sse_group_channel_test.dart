/// **Le protocole SSE, relevé sur `@adonisjs/transmit` et vérifié ici** (#101).
///
/// Deux choses s'y ratent en silence, et aucune ne se verrait à l'exécution — la
/// conversation marcherait simplement « parfois » :
///
/// 1. **l'ordre** : `POST /__transmit/subscribe` cherche le flux par son `uid`, il
///    doit donc partir **après** que le `GET` a rendu ses en-têtes. L'inverse
///    donne un abonnement refusé pour un membre légitime ;
/// 2. **le même `uid` des deux côtés** : un abonnement frappé sur un identifiant
///    que le flux ne porte pas réussit côté serveur et ne délivre jamais rien.
///
/// Et la discipline de la tranche : **aucune charge utile n'est lue**. Le serveur
/// diffuse l'intégralité du message (`TransmitGroupBroadcaster`) ; on ne compte
/// que des frontières d'événements.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/realtime/group_channel.dart';
import 'package:maison_du_miracle/data/realtime/sse_frames.dart';
import 'package:maison_du_miracle/data/realtime/sse_group_channel.dart';

/// Un serveur Transmit réduit à ses deux routes : le flux, et l'abonnement.
class _FakeTransmit implements HttpClientAdapter {
  _FakeTransmit({this.subscribeStatus = 204});

  /// Le code que rend `POST /__transmit/subscribe`. `400` est ce que Transmit
  /// rend quand l'autorisation refuse (`SubscribeController`).
  final int subscribeStatus;

  final List<RequestOptions> requests = [];
  final StreamController<Uint8List> body = StreamController<Uint8List>();

  /// Les octets du flux, tels qu'une socket les livrerait.
  void emit(String raw) => body.add(Uint8List.fromList(raw.codeUnits));

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

Dio _dio(_FakeTransmit server) => Dio(
      BaseOptions(baseUrl: 'https://eenv.brainsial.com'),
    )..httpClientAdapter = server;

void main() {
  group('Les trames, sans rien décoder', () {
    test('une ligne vide termine un événement', () {
      final reader = SseFrameReader();
      expect(reader.consume('data: {"id":"m-1"}\n'), 0);
      expect(reader.consume('\n'), 1);
    });

    test('un fragment peut couper une ligne en deux', () {
      // Le régime normal d'une connexion mobile : la socket rend des octets, pas
      // des lignes. Un lecteur sans mémoire perdrait un événement sur deux.
      final reader = SseFrameReader();
      expect(reader.consume('data: {"id":"m'), 0);
      expect(reader.consume('-1"}'), 0);
      expect(reader.consume('\n\ndata: x\n\n'), 2);
    });

    test('le `:ok` d\'ouverture n\'est pas un événement', () {
      // Transmit l'envoie dès l'ouverture, parce que Safari ne déclenche `onopen`
      // qu'à la première trame. Le compter déclencherait un cycle de plus par
      // connexion — pas faux, mais c'est le signal d'abonnement qui porte ça.
      final reader = SseFrameReader();
      expect(reader.consume(':ok\n\n'), 0);
    });

    test('les fins de ligne `\\r\\n` comptent comme `\\n`', () {
      final reader = SseFrameReader();
      expect(reader.consume('data: x\r\n\r\n'), 1);
    });

    test('deux lignes vides de suite ne font pas deux événements', () {
      final reader = SseFrameReader();
      expect(reader.consume('data: x\n\n\n\n'), 1);
    });

    test('un corps multiligne reste un seul événement', () {
      final reader = SseFrameReader();
      expect(reader.consume('data: {\ndata: "a":1\ndata: }\n\n'), 1);
    });
  });

  group('L\'ouverture du canal', () {
    test('le flux part d\'abord, l\'abonnement ensuite, sur le même uid',
        () async {
      final server = _FakeTransmit();
      final channel = SseGroupChannel(
        client: _dio(server),
        mintUid: () => 'uid-fixe',
      );

      final signals = <GroupChannelSignal>[];
      final subscription = channel.watch('g-1').listen(signals.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      expect(
        server.requests.map((r) => r.uri.path).toList(),
        ['/__transmit/events', '/__transmit/subscribe'],
        reason: 'le serveur cherche le flux par son uid : l\'abonnement arrive '
            'après',
      );
      expect(server.requests.first.uri.queryParameters['uid'], 'uid-fixe');
      expect(
        server.requests.last.data,
        {'uid': 'uid-fixe', 'channel': 'groups/g-1'},
      );
      expect(
        server.requests.first.receiveTimeout,
        Duration.zero,
        reason: 'un canal silencieux quinze secondes est le cas normal d\'une '
            'conversation ; le défaut du client tuerait la connexion en boucle',
      );
    });

    test('un abonnement réussi EST un signal', () async {
      // Un canal neuf n'a aucune mémoire de ce qui s'est diffusé avant lui : il a
      // le même trou à faire combler qu'un message reçu. C'est ce qui fait qu'une
      // reconnexion rattrape sa coupure, et que le fil qu'on vient d'ouvrir se
      // rafraîchit.
      final server = _FakeTransmit();
      final channel = SseGroupChannel(client: _dio(server));

      final signals = <GroupChannelSignal>[];
      final subscription = channel.watch('g-1').listen(signals.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      expect(signals, hasLength(1));
    });

    test('rien ne part tant que personne n\'écoute', () async {
      // Un canal ouvert que personne ne lit serait du forfait dépensé pour rien.
      final server = _FakeTransmit();
      SseGroupChannel(client: _dio(server)).watch('g-1');
      await pumpEventQueue();

      expect(server.requests, isEmpty);
    });

    test('un refus d\'abonnement remonte en GroupChannelRefused, et clôt',
        () async {
      // Le canal est réservé aux membres (`CheckGroupMembership`). Un refus n'est
      // pas une panne : `OpenThreadChannel` ne le réessaie pas.
      final server = _FakeTransmit(subscribeStatus: 400);
      final channel = SseGroupChannel(client: _dio(server));

      Object? failure;
      var closed = false;
      final subscription = channel.watch('g-1').listen(
            (_) {},
            onError: (Object error) => failure = error,
            onDone: () => closed = true,
          );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      expect(failure, isA<GroupChannelRefused>());
      expect((failure! as GroupChannelRefused).statusCode, 400);
      expect(closed, isTrue);
    });
  });

  group('Les messages diffusés', () {
    test('une trame diffusée donne un signal, et son corps est ignoré',
        () async {
      final server = _FakeTransmit();
      final channel = SseGroupChannel(client: _dio(server));

      final signals = <GroupChannelSignal>[];
      final subscription = channel.watch('g-1').listen(signals.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(signals, hasLength(1), reason: 'le signal d\'abonnement');

      // La forme réelle de `TransmitGroupBroadcaster` : le message entier. Rien
      // n'en est lu — le moteur ira le chercher.
      server.emit(':ok\n\n');
      server.emit(
        'data: {"channel":"groups/g-1","payload":{"id":"m-1","groupId":"g-1",'
        '"authorId":"u-1","isSystem":false,"body":"Amen","clientMessageId":null,'
        '"clientCreatedAt":null,"createdAt":"2026-10-01T10:00:00.000Z"}}\n\n',
      );
      await pumpEventQueue();

      expect(signals, hasLength(2));
    });

    test('la fin du flux clôt le canal : il est tombé', () async {
      final server = _FakeTransmit();
      final channel = SseGroupChannel(client: _dio(server));

      var closed = false;
      final subscription =
          channel.watch('g-1').listen((_) {}, onDone: () => closed = true);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await server.body.close();
      await pumpEventQueue();

      expect(closed, isTrue);
    });
  });
}
