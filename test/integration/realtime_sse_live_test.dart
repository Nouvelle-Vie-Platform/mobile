/// **Le temps-réel SSE, contre un vrai serveur** (`docs/temps-reel-sse.md`). Le
/// pendant « live » des tests unitaires du `RealtimeService` : ici rien n'est
/// simulé — un vrai flux `GET /__transmit/events`, un vrai
/// `POST /__transmit/subscribe`, et le serveur qui **diffuse réellement** sur
/// `groups/{id}` après un `sendDirect`. On exerce le [HttpTransmitClient] tel
/// quel, celui que la porte native branche en production.
///
/// Ce que le scénario prouve, de bout en bout :
/// 1. Bob s'abonne au canal `groups/{idDuDM}` et **reçoit l'événement SSE**
///    quand Alice lui écrit (D2, D6) ;
/// 2. traiter cet événement par une **sync** (D1) fait **atterrir le message
///    dans son magasin** — le SSE accélère, le flux delta ramène la donnée.
///
/// On ne pilote **pas** le `RealtimeService` complet ici : son coalescing et son
/// cycle de vie sont prouvés en temps simulé par `test/data/realtime/
/// realtime_service_test.dart`. Un test live veut du **temps réel** et du réseau,
/// or l'horloge simulée du binding de test et un `Timer` de coalescing s'y
/// marient mal. On exerce donc le **client réel** — ce que la note autorise
/// explicitement — et on rejoue nous-mêmes la sync que le service aurait
/// déclenchée, ce qui prouve la même chaîne.
///
/// Sauté par défaut (étiquette `live-server`, cf. `dart_test.yaml`). Monter le
/// serveur : `OTP_PHONE_DRIVER=log OTP_DEV_ECHO_CODE=true npm run dev`.
@Tags(['live-server'])
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/realtime/http_transmit_client.dart';
import 'package:maison_du_miracle/data/realtime/realtime_service.dart';
import 'package:maison_du_miracle/data/realtime/transmit_client.dart';
import 'package:maison_du_miracle/data/repositories/group_repository.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';
import 'package:maison_du_miracle/models/models.dart';

import '../data/local/local_database_fixtures.dart';
import 'live_server.dart';

void main() {
  late LiveServer server;

  // Identités **fraîches à chaque run** : une paire neuve, donc un DM neuf.
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final aliceEmail = 'rt-alice-$stamp@example.com';
  final bobEmail = 'rt-bob-$stamp@example.com';

  late String aliceToken, bobToken;
  late String bobId;

  setUpAll(() async {
    server = LiveServer();

    aliceToken = await server.signIn(aliceEmail);
    bobToken = await server.signIn(bobEmail);

    await server.setName(aliceToken, firstName: 'Alice', lastName: 'Koffi');
    await server.setName(bobToken, firstName: 'Bob', lastName: 'Mensah');

    bobId = await server.me(bobToken);

    // Le premier envoi crée paresseusement le fil et l'appartenance de Bob :
    // sans elle, l'abonnement à `groups/{idDuDM}` serait refusé (membres seuls).
    await server.sendDirect(aliceToken, bobId, 'Salut Bob', clientMessageId: 'rt-0');
  });

  tearDownAll(() => server.close());

  /// Un `Dio` porteur du Bearer de [token]. Avec [envelope], il déballe
  /// l'enveloppe JSON du serveur (nécessaire au moteur de sync) ; sans elle, il
  /// laisse passer le **flux SSE brut** que lit le client Transmit.
  Dio bearerDio(String token, {bool envelope = true}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: server.url,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (envelope) dio.interceptors.add(unwrapEnvelopeInterceptor);
    return dio;
  }

  /// Monte un magasin neuf pour [userId] et y **synchronise réellement** depuis
  /// le serveur. Rend la base, le moteur (réutilisable pour un second cycle) et
  /// le repository de lecture.
  Future<(AppDatabase, SyncEngine, StoreGroupRepository)> syncAs(
    String token,
    String userId,
  ) async {
    final db = openTestDatabase();
    final dio = bearerDio(token);
    final engine = SyncEngine(
      api: SyncApi(dio: dio),
      dao: db.syncDao,
      collections: syncedCollections(),
    );
    await engine.synchronize();
    return (db, engine, StoreGroupRepository(db.groupDao, currentUserId: userId));
  }

  test('Bob reçoit l\'événement SSE de son DM quand Alice lui écrit', () async {
    final (db, _, repo) = await syncAs(bobToken, bobId);
    addTearDown(db.close);

    final dm = (await repo.conversations().first)
        .singleWhere((c) => c.kind == ConversationKind.direct);
    final channel = RealtimeService.channelForGroup(dm.id);

    final transmitDio = bearerDio(bobToken, envelope: false);
    final client = HttpTransmitClient(dio: transmitDio);
    addTearDown(() async {
      await client.dispose();
      transmitDio.close(force: true);
    });

    final received = Completer<TransmitEvent>();
    final sub = client.events.listen((event) {
      if (event.channel == channel && !received.isCompleted) {
        received.complete(event);
      }
    });
    addTearDown(sub.cancel);

    await client.connect();
    await client.subscribe(channel);
    // Laisse l'abonnement s'enregistrer côté serveur avant d'émettre.
    await Future<void>.delayed(const Duration(seconds: 1));

    await server.sendDirect(
      aliceToken,
      bobId,
      'Ping temps-réel',
      clientMessageId: 'rt-1',
    );

    final event = await received.future.timeout(const Duration(seconds: 20));
    expect(event.channel, channel);
  });

  test(
      'un événement SSE, rejoué en sync, fait atterrir le message dans le '
      'magasin de Bob', () async {
    final (db, engine, repo) = await syncAs(bobToken, bobId);
    addTearDown(db.close);

    final dm = (await repo.conversations().first)
        .singleWhere((c) => c.kind == ConversationKind.direct);
    final channel = RealtimeService.channelForGroup(dm.id);

    final transmitDio = bearerDio(bobToken, envelope: false);
    final client = HttpTransmitClient(dio: transmitDio);
    addTearDown(() async {
      await client.dispose();
      transmitDio.close(force: true);
    });

    // Ce que ferait le `RealtimeService` sur événement (D1) : une sync — jamais
    // peindre la charge utile. On la déclenche à la première réception.
    final synced = Completer<void>();
    final sub = client.events.listen((event) async {
      if (event.channel == channel && !synced.isCompleted) {
        await engine.synchronize();
        if (!synced.isCompleted) synced.complete();
      }
    });
    addTearDown(sub.cancel);

    await client.connect();
    await client.subscribe(channel);
    await Future<void>.delayed(const Duration(seconds: 1));

    await server.sendDirect(
      aliceToken,
      bobId,
      'Message temps-réel',
      clientMessageId: 'rt-2',
    );

    await synced.future.timeout(const Duration(seconds: 20));

    final messages = await repo.messages(dm.id).first;
    expect(messages.map((m) => m.text), contains('Message temps-réel'));
  });
}
