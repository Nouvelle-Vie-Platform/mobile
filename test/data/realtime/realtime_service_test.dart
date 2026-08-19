/// **Le `RealtimeService`, prouvé contre un client factice.**
///
/// On exerce les quatre décisions de `docs/temps-reel-sse.md` que le service
/// possède en propre, sans jamais ouvrir de socket : un [FakeTransmitClient] émet
/// à la demande, un compteur tient lieu de socle de sync, et l'horloge simulée de
/// `testWidgets` (`tester.pump(duration)`) fait avancer le `Timer` de coalescing
/// sans attente réelle — même patron que `test/data/status_player_test.dart`.
///
/// - **D1/D5 — coalescing** : un événement déclenche **une** sync après la
///   fenêtre ; une rafale rapprochée n'en déclenche **qu'une**.
/// - **D7 — réabonnement réactif** : un changement de mes appartenances
///   (dés)abonne exactement les bons canaux.
/// - **D3/D4 — cycle de vie + rattrapage** : le retour au premier plan rouvre la
///   connexion et déclenche une sync de rattrapage.
///
/// L'horloge est celle du binding de test : on injecte `tester.binding` pour que
/// l'observateur du cycle de vie et le `Timer` vivent dans le temps simulé.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/realtime/realtime_service.dart';
import 'package:maison_du_miracle/data/realtime/transmit_client.dart';

/// Double **pilotable** de [TransmitClient] : il n'ouvre rien, mais compte les
/// (dé)connexions, retient les (dés)abonnements, et **émet à la demande** sur un
/// flux broadcast — de quoi jouer un événement serveur ou une reconnexion.
class FakeTransmitClient implements TransmitClient {
  final StreamController<TransmitEvent> _controller =
      StreamController<TransmitEvent>.broadcast();

  final List<String> subscribed = <String>[];
  final List<String> unsubscribed = <String>[];
  int connectCount = 0;
  int disconnectCount = 0;

  @override
  Stream<TransmitEvent> get events => _controller.stream;

  @override
  Future<void> connect() async => connectCount++;

  @override
  Future<void> disconnect() async => disconnectCount++;

  @override
  Future<void> subscribe(String channel) async => subscribed.add(channel);

  @override
  Future<void> unsubscribe(String channel) async => unsubscribed.add(channel);

  /// Joue un événement serveur (broadcast → livré au prochain `pump`).
  void emit(TransmitEvent event) => _controller.add(event);

  Future<void> close() => _controller.close();
}

void main() {
  const window = Duration(milliseconds: 300);

  /// Monte un service démarré, prêt à recevoir. Rend le service, le client, le
  /// contrôleur d'appartenances et un accès **vivant** au nombre de syncs
  /// déclenchées. Le premier `connect()` a déjà émis sa sync de rattrapage (D4),
  /// donc `signals()` vaut **1** au retour.
  Future<
      ({
        RealtimeService service,
        FakeTransmitClient client,
        StreamController<List<String>> memberships,
        int Function() signals,
      })> boot(WidgetTester tester) async {
    final client = FakeTransmitClient();
    final memberships = StreamController<List<String>>();
    var signals = 0;

    final service = RealtimeService(
      client: client,
      myGroupIds: memberships.stream,
      onRealtimeSignal: () async => signals++,
      binding: tester.binding,
      coalesceWindow: window,
    );

    addTearDown(() async {
      service.dispose();
      await client.close();
      await memberships.close();
    });

    service.start();
    // Livre le `connect()` asynchrone (micro-tâche) et sa sync de rattrapage.
    await tester.pump();

    return (
      service: service,
      client: client,
      memberships: memberships,
      signals: () => signals,
    );
  }

  testWidgets('un événement déclenche une sync realtime après coalescing',
      (tester) async {
    final h = await boot(tester);
    expect(h.signals(), 1, reason: 'la connexion a déjà rattrapé (D4)');

    h.client.emit(const TransmitEvent('groups/g1'));
    await tester.pump(); // livre l'événement, arme la fenêtre de coalescing
    expect(h.signals(), 1, reason: 'rien tant que la fenêtre court');

    await tester.pump(window);
    expect(h.signals(), 2, reason: 'une sync realtime après la fenêtre');
  });

  testWidgets('plusieurs événements rapprochés ⇒ UNE seule sync',
      (tester) async {
    final h = await boot(tester);
    expect(h.signals(), 1);

    // Rafale d'un fil actif, toute entière dans la fenêtre de 300 ms.
    h.client.emit(const TransmitEvent('groups/g1'));
    await tester.pump(); // arme à t=0
    h.client.emit(const TransmitEvent('groups/g1'));
    await tester.pump(const Duration(milliseconds: 100)); // t=100, absorbé
    h.client.emit(const TransmitEvent('groups/g2'));
    await tester.pump(const Duration(milliseconds: 100)); // t=200, absorbé
    expect(h.signals(), 1, reason: 'encore dans la fenêtre : rien parti');

    await tester.pump(const Duration(milliseconds: 100)); // t=300 : échéance
    expect(h.signals(), 2, reason: 'la rafale se regroupe en une sync');

    // Aucun réarmement fantôme : la fenêtre ne se rallume pas toute seule.
    await tester.pump(window);
    expect(h.signals(), 2);
  });

  testWidgets('un changement d\'appartenances (dés)abonne les bons canaux',
      (tester) async {
    final h = await boot(tester);

    h.memberships.add(<String>['g1', 'g2']);
    await tester.pump();
    expect(h.client.subscribed, containsAll(<String>['groups/g1', 'groups/g2']));
    expect(h.client.unsubscribed, isEmpty);

    // g1 part, g3 arrive ; g2 reste et **ne doit pas** bouger.
    h.memberships.add(<String>['g2', 'g3']);
    await tester.pump();
    expect(h.client.subscribed, contains('groups/g3'));
    expect(h.client.unsubscribed, <String>['groups/g1']);
    expect(h.client.unsubscribed, isNot(contains('groups/g2')));
  });

  testWidgets('reconnexion (retour au premier plan) ⇒ sync de rattrapage',
      (tester) async {
    final h = await boot(tester);
    expect(h.client.connectCount, 1);
    expect(h.signals(), 1);

    // Arrière-plan (D3) : la connexion se ferme, pas de sync.
    h.service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(h.client.disconnectCount, 1);
    expect(h.signals(), 1);

    // Retour au premier plan : reconnexion + rattrapage (D4).
    h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(h.client.connectCount, 2);
    expect(h.signals(), 2, reason: 'chaque (ré)ouverture déclenche une sync');
  });

  testWidgets('un signal de reconnexion émis par le client déclenche une sync',
      (tester) async {
    // Le client réel émet une sentinelle à chaque reconnexion (D4) ; le service
    // ne lit pas le canal (D1) et la traite comme n'importe quel événement.
    final h = await boot(tester);
    expect(h.signals(), 1);

    h.client.emit(const TransmitEvent('__transmit_reconnect__'));
    await tester.pump();
    await tester.pump(window);
    expect(h.signals(), 2);
  });

  testWidgets('les transitions inactive/hidden ne touchent pas la connexion',
      (tester) async {
    final h = await boot(tester);
    expect(h.client.connectCount, 1);

    h.service.didChangeAppLifecycleState(AppLifecycleState.inactive);
    h.service.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await tester.pump();
    // Ni fermeture ni réouverture : seul `paused`/`resumed` agit (D3).
    expect(h.client.disconnectCount, 0);
    expect(h.client.connectCount, 1);
  });
}
