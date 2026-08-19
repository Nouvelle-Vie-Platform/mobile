/// **La porte du temps-réel** — le contrat Transmit, séparé de tout le reste.
///
/// Le serveur diffuse chaque message de `groups/{id}` par `@adonisjs/transmit`
/// (SSE) après le commit ; le mobile s'abonne pour **savoir qu'un message est
/// arrivé** et déclencher une sync (décision D1 de `docs/temps-reel-sse.md`).
/// Cette abstraction est la seule frontière que le `RealtimeService` connaît :
/// elle cache **complètement** le protocole Transmit et le transport, si bien
/// que le service ne sait pas s'il parle à un `Dio` natif, à un lecteur `fetch`
/// web, ou au double inerte des tests.
///
/// **L'interface est volontairement mince** — trois verbes et un flux — parce
/// que le consommateur n'en demande pas plus : « le réseau ne peint jamais »
/// (ADR-0026). Un événement ne sert qu'à **déclencher un cycle de sync** ; le
/// message lui-même revient par le flux delta de `/sync`. C'est pourquoi
/// [TransmitEvent] peut se réduire à « quelque chose est arrivé sur tel
/// canal » : la charge utile décodée est **portée mais jamais lue** pour peindre
/// (on ne dépend donc pas de sa forme, que le contrat serveur n'a pas figée —
/// même bénéfice que `GroupMessaging`, qui ne lit pas le corps d'une écriture).
///
/// **Le protocole Transmit**, pour la personne qui écrira une implémentation
/// réelle derrière cette porte :
/// - une connexion : un flux SSE `GET /__transmit/events?uid={uid}` ;
/// - s'abonner : `POST /__transmit/subscribe` `{ uid, channel }` ;
/// - se désabonner : `POST /__transmit/unsubscribe` `{ uid, channel }` ;
/// - le `uid` identifie **la connexion** et est **généré par le client** (paquet
///   `uuid`, déjà présent) : le même `uid` relie le flux d'événements et les
///   abonnements. Il appartient donc à l'implémentation, pas à cette interface.
///
/// Deux implémentations réelles viendront derrière la même porte (D6, D8) —
/// `HttpTransmitClient` (natif, flux Dio) et `WebTransmitClient` (lecteur
/// `fetch`, l'`EventSource` du navigateur ne portant pas d'en-tête
/// `Authorization`) — plus [InertTransmitClient], le défaut hors backend et en
/// test.
library;

import 'package:flutter/foundation.dart';

/// Un événement reçu du serveur : **le seul fait** que quelque chose est arrivé
/// sur un [channel].
///
/// [payload] porte la charge utile décodée du message SSE si elle est présente,
/// mais **le consommateur ne la peint pas** (D1) : il déclenche une sync et
/// laisse le flux delta ramener la donnée. Le champ existe pour le diagnostic et
/// pour ne pas fermer la porte à un usage futur ; s'en servir pour afficher un
/// message trahirait « le réseau ne peint jamais » (ADR-0026).
@immutable
class TransmitEvent {
  const TransmitEvent(this.channel, {this.payload});

  /// Le canal d'où vient l'événement — `groups/{id}` (groupes **et** DM
  /// partagent ce canal, D2).
  final String channel;

  /// La charge utile décodée, si le message SSE en portait une. **Portée, jamais
  /// lue pour peindre.**
  final Object? payload;

  @override
  String toString() => 'TransmitEvent($channel, $payload)';
}

/// **Le client Transmit**, derrière lequel se cachent le protocole et le
/// transport (natif Dio, web `fetch`, ou inerte).
///
/// Cycle de vie attendu par le `RealtimeService` : [connect] à
/// `AppLifecycleState.resumed` (D3), [subscribe] / [unsubscribe] au fil des
/// changements de `group_members` (D7), [events] écouté pour déclencher les
/// syncs, [disconnect] au passage en arrière-plan.
abstract interface class TransmitClient {
  /// **Ouvre la connexion** SSE (`GET /__transmit/events?uid={uid}`) et commence
  /// à alimenter [events]. Idempotent : appeler [connect] sur une connexion déjà
  /// ouverte ne la rouvre pas.
  ///
  /// Ne **lève pas** sur une panne réseau : le temps-réel est un accélérateur,
  /// pas une source de vérité (une coupure est rattrapée par le curseur `?since`
  /// à la reconnexion, D4). Une implémentation réelle gère seule son backoff de
  /// reconnexion (§3).
  Future<void> connect();

  /// **Ferme la connexion** et cesse d'alimenter [events]. Les abonnements en
  /// mémoire côté implémentation peuvent être conservés pour un futur [connect] ;
  /// c'est un détail d'implémentation, pas un contrat.
  Future<void> disconnect();

  /// **S'abonne** au canal [channel] (`POST /__transmit/subscribe`
  /// `{ uid, channel }`). Sans effet si déjà abonné. À connexion fermée,
  /// l'implémentation retient l'intention et l'applique à la prochaine [connect].
  Future<void> subscribe(String channel);

  /// **Se désabonne** du canal [channel] (`POST /__transmit/unsubscribe`
  /// `{ uid, channel }`). Sans effet si pas abonné.
  Future<void> unsubscribe(String channel);

  /// **Le flux des événements reçus**, tous canaux confondus (Transmit multiplexe
  /// sur une seule connexion, D2). Un flux **broadcast** : le service s'y abonne
  /// pour coalescer et déclencher des syncs. Ne se termine pas de lui-même à un
  /// [disconnect] — il se tait, puis reprend au [connect] suivant.
  Stream<TransmitEvent> get events;
}
