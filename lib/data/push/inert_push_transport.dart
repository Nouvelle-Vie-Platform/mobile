import 'push_transport.dart';

/// Double **inerte** de [PushTransport] — le défaut hors backend et en test.
///
/// C'est le pendant, pour le réveil push, d'[InertContentPlayer] côté lecture et
/// d'[InertGroupMessaging] côté écriture : aucun canal de plugin, aucun
/// abonnement natif, aucune minuterie. Il ne peut donc **jamais** lever de
/// `MissingPluginException`, ce qui en fait le seul transport qu'on puisse
/// construire sous `flutter test` et en mode maquette.
///
/// Son comportement est celui d'un appareil **sans push** :
/// [obtainRegistration] rend `null` (décision **D4** — dégradé propre, l'app
/// marche, SSE + sync au premier plan), et [onRefresh] est un flux **vide** qui
/// ne se ferme pas de lui-même mais n'émet rien. Un test qui veut observer une
/// inscription ou une rotation surcharge le provider par un faux — il ne compte
/// pas sur celui-ci pour produire quoi que ce soit.
///
/// Le **vrai** transport (FCM, puis UnifiedPush) est injecté par le démarrage de
/// l'application, une fois Firebase debout — chemin que les tests ne prennent
/// jamais.
class InertPushTransport implements PushTransport {
  const InertPushTransport();

  @override
  Future<PushRegistration?> obtainRegistration() async => null;

  @override
  Stream<PushRegistration> get onRefresh => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
