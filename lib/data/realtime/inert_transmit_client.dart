import 'transmit_client.dart';

/// Double **inerte** de [TransmitClient] — le défaut hors backend et en test.
///
/// Connexion no-op, (dés)abonnements no-op, flux **vide** : aucune socket ne
/// s'ouvre, aucun événement n'arrive, donc aucune sync n'est déclenchée par le
/// temps-réel. C'est le pendant, pour le SSE, d'[InertGroupMessaging] côté
/// écriture : en mode maquette il n'y a pas de serveur qui pousse, et un test
/// qui veut prouver le déclenchement d'une sync surcharge le provider par un
/// faux qui émet à la demande.
///
/// `const` pour être partagé sans allocation. `Stream.empty()` **ne peut pas**
/// être `const`, mais [events] rend une valeur constante par appel : un flux
/// vide qui se ferme aussitôt, sur lequel un `listen` ne reçoit jamais d'élément
/// et reçoit son `onDone` immédiatement.
class InertTransmitClient implements TransmitClient {
  const InertTransmitClient();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> subscribe(String channel) async {}

  @override
  Future<void> unsubscribe(String channel) async {}

  @override
  Stream<TransmitEvent> get events => const Stream<TransmitEvent>.empty();
}
