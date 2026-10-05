/// **Le canal temps réel de la messagerie, `users/{monId}`** (#140, tranche M1b
/// du plan `server-portal/docs/messagerie-whatsapp-plan.md`, contrat serveur
/// `docs/messagerie-temps-reel-contrat.md` de M1a) — et sa charge **est** la
/// donnée.
///
/// ## Pourquoi ce fichier n'est pas dans `lib/data/realtime/`
///
/// `realtime/` portait le canal **par groupe** de #101 (`groups/{id}`), qui ne
/// transportait qu'un **signal** vide : un événement déclenchait un cycle, et le
/// moteur de synchronisation écrivait. Un garde-fou de source y interdisait tout
/// `jsonDecode`. Ce canal-là est **retiré** côté client : ouvert seulement dans
/// le fil affiché, il ne pouvait rien pour la liste, et son signal coûtait deux
/// allers-retours de plus par message.
///
/// Le canal `users/{id}` porte **la ligne elle-même**. Le serveur la produit par
/// la même fonction que le tirage delta (`group_sync_rows.ts`) : le client la
/// range **exactement comme il rangerait la même ligne tirée**, par le même
/// descripteur du registre (`SyncedCollection.applyLive`), sans traduction. Il
/// n'y a donc pas de « chemin mixte » au sens de la décision 1 d'Échanges — deux
/// chemins, une seule fonction d'écriture, et la synchronisation reste la vérité
/// de rattrapage (ADR-0006, piège 4 du plan) : à chaque (re)connexion, un cycle.
///
/// Même découpage que la radio (`lib/data/radio/`), qui a ouvert la voie d'un
/// canal dont la charge est la donnée : ce fichier **décode** (le contrat), le
/// transport vit dans `sse_messaging_channel.dart`, et l'écriture dans le
/// magasin dans `messaging_store_writer.dart`.
///
/// ## La forme d'une trame Transmit
///
/// ```
/// data: {"channel":"users/<id>","payload":{"type":"message.created","message":{…}}}
/// data: {"channel":"$$transmit/ping","payload":…}
/// ```
///
/// Le battement (toutes les 25 s) arrive **sur la même connexion** : il faut lire
/// `channel` et ignorer ce qui n'est pas `users/<mon id>` — sauf pour se savoir
/// vivant.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../local/sync_dao.dart' show SyncCollectionKey;

/// **Le nom du canal d'une personne**, et la seule copie de ce motif côté
/// client. Le serveur n'y admet que le porteur **qui est** cette personne
/// (`start/transmit.ts`), jamais un jeton d'appareil.
String userChannelName(String userId) => 'users/$userId';

/// Le canal du battement de Transmit (`config/transmit.ts`, toutes les 25 s).
const String kTransmitPingChannel = r'$$transmit/ping';

/// Un événement du canal, déjà décodé.
sealed class MessagingEvent {
  const MessagingEvent();
}

/// **La connexion vient de s'ouvrir** — première fois ou après une coupure.
///
/// Émis par le **client**, après l'abonnement réussi. Un canal neuf n'a aucune
/// mémoire de ce qui s'est diffusé avant lui (une bascule bleu/vert coupe tous
/// les flux ~120 s, piège 4) : c'est le moment d'un cycle de synchronisation.
final class MessagingChannelOpened extends MessagingEvent {
  const MessagingChannelOpened();
}

/// **La connexion est vivante** : un battement, ou une trame qu'on ne sait pas
/// lire. Ne porte rien — il remet seulement à zéro le délai de silence.
final class MessagingHeartbeat extends MessagingEvent {
  const MessagingHeartbeat();
}

/// **Une ligne d'une collection répliquée**, telle que le tirage la servirait.
@immutable
final class MessagingRowEvent extends MessagingEvent {
  const MessagingRowEvent({
    required this.type,
    required this.collection,
    required this.row,
  });

  /// `message.created`, `message.updated`, `message.deleted`,
  /// `membership.changed`, `group.updated`, `read.advanced`.
  final String type;

  /// La clé de collection (`SyncCollectionKey`) où la ligne se range.
  final String collection;

  /// La ligne, en `camelCase`, mot pour mot celle du flux delta.
  final Map<String, Object?> row;

  /// Le groupe que la ligne concerne — son `id` pour un groupe, son `groupId`
  /// pour le reste. `null` sur une ligne mal formée.
  String? get groupId {
    final raw =
        collection == SyncCollectionKey.groups ? row['id'] : row['groupId'];
    return raw is String ? raw : null;
  }
}

/// La table du contrat : quel type d'événement porte quelle collection, sous
/// quelle clé. Écrite **une fois**.
const Map<String, ({String collection, String key})> _kEventRows = {
  'message.created': (
    collection: SyncCollectionKey.groupMessages,
    key: 'message'
  ),
  'message.updated': (
    collection: SyncCollectionKey.groupMessages,
    key: 'message'
  ),
  'message.deleted': (
    collection: SyncCollectionKey.groupMessages,
    key: 'message'
  ),
  'membership.changed': (
    collection: SyncCollectionKey.groupMembers,
    key: 'membership'
  ),
  'group.updated': (collection: SyncCollectionKey.groups, key: 'group'),
  'read.advanced': (collection: SyncCollectionKey.groupReads, key: 'read'),
};

/// **Décode une trame** `data:` de Transmit.
///
/// - le battement (`$$transmit/ping`) → [MessagingHeartbeat] ;
/// - un événement de [channel] dont le type est au contrat → [MessagingRowEvent] ;
/// - tout le reste (autre canal, type inconnu d'un serveur plus récent, charge
///   mal formée) → `null`. Un événement ignoré ne coûte rien : le cycle suivant
///   ramène la ligne. Un événement inventé rangerait un faux.
MessagingEvent? decodeMessagingData(String data, {required String channel}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(data);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;

  final from = decoded['channel'];
  if (from == kTransmitPingChannel) return const MessagingHeartbeat();
  if (from != channel) return null;

  final payload = decoded['payload'];
  if (payload is! Map) return null;
  final type = payload['type'];
  if (type is! String) return null;
  final shape = _kEventRows[type];
  if (shape == null) return null;

  final row = payload[shape.key];
  if (row is! Map) return null;
  return MessagingRowEvent(
    type: type,
    collection: shape.collection,
    row: {for (final e in row.entries) e.key.toString(): e.value},
  );
}

/// **L'abonnement a été refusé** — porteur sans compte (invité), ou jeton qui
/// n'est pas celui de cette personne. Ce n'est pas une panne, et ça ne se
/// réessaie pas : insister ne changerait pas la réponse.
class MessagingChannelRefused implements Exception {
  const MessagingChannelRefused(this.statusCode);

  final int? statusCode;

  @override
  String toString() => 'MessagingChannelRefused(${statusCode ?? 'sans code'})';
}

/// Contrat d'écoute du canal d'une personne.
abstract interface class MessagingChannel {
  /// Ouvre **une** connexion abonnée à `users/[userId]`.
  ///
  /// Le premier événement d'une connexion réussie est [MessagingChannelOpened].
  /// Le flux ne se termine pas de lui-même tant que la connexion tient ;
  /// annuler l'abonnement la ferme. Une fin de flux ou une erreur disent « le
  /// canal est tombé ».
  Stream<MessagingEvent> watch(String userId);
}

/// **Double muet** : aucune socket, aucun événement, et un flux **jamais clos**
/// — un flux clos tout de suite se lirait comme un canal tombé et ferait tourner
/// la réouverture dans le vide. Le défaut sans backend et dans les tests.
class SilentMessagingChannel implements MessagingChannel {
  const SilentMessagingChannel();

  @override
  Stream<MessagingEvent> watch(String userId) =>
      // ignore: close_sinks — fermé par l'annulation de l'abonnement.
      StreamController<MessagingEvent>().stream;
}
