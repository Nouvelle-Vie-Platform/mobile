/// **L'écriture de la messagerie de groupe** — le contrat, séparé de la lecture.
///
/// Comme le composeur d'annonces l'est d'`AnnouncementRepository`, cette
/// abstraction est **séparée** de la lecture des groupes (`GroupRepository`,
/// adossé au magasin) : les deux n'ont ni la même source (serveur / magasin), ni
/// la même forme (`Future` / `Stream`), ni le même régime hors-ligne (impossible
/// / normal). Les fondre donnerait un objet dont la moitié des méthodes marchent
/// en avion.
///
/// **La réception passe par la synchronisation** : après une écriture réussie,
/// l'appelant déclenche un cycle (`SyncScheduler.refresh`) et le flux delta
/// ramène le message / l'appartenance / la demande. Le réseau ne peint jamais
/// (ADR-0026). Effet heureux : la **forme exacte de la réponse** d'écriture, que
/// le contrat serveur n'a pas encore figée, ne peut pas nous casser — on ne la
/// lit pas.
library;

import 'package:flutter/foundation.dart';

/// Nature d'un refus d'écriture, pour que l'écran choisisse la phrase.
///
/// Le partage se fait d'abord sur **l'existence d'une réponse** : « le serveur
/// n'a rien dit » (réseau) et « le serveur a dit non » sont deux choses
/// différentes pour l'utilisateur.
enum GroupWriteErrorCode {
  /// Pas de réponse (timeout, DNS, coupure, TLS).
  network,

  /// **401** — la session n'est plus valide.
  unauthorized,

  /// **403** — pas le droit : non-membre, diffusion réservée aux admins, verrou
  /// d'écriture, rôle insuffisant.
  forbidden,

  /// **404 / 410** — le groupe, le message ou la demande a disparu.
  gone,

  /// **409** — conflit : déjà membre, demande déjà en attente.
  conflict,

  /// **422** — corps refusé par le validateur.
  rejected,

  /// Autre réponse HTTP (5xx…).
  server,

  /// Requête annulée, ou cas non couvert.
  unknown,
}

/// Un refus d'écriture, porteur de son [code] et, si le serveur l'a dit, d'un
/// [message].
@immutable
class GroupWriteException implements Exception {
  const GroupWriteException(this.code, [this.message]);

  final GroupWriteErrorCode code;
  final String? message;

  @override
  String toString() => 'GroupWriteException($code, $message)';
}

/// **L'écriture de la messagerie de groupe**, sur le `Dio` d'`ApiClient`.
///
/// Aucune méthode ne rend le corps du serveur : toutes rendent `void` (ou lèvent
/// [GroupWriteException]). Ce que l'écriture a produit revient par la
/// **synchronisation**, jamais par la réponse.
abstract interface class GroupMessaging {
  /// `POST /groups/:id/messages` — envoyer un message.
  ///
  /// [clientMessageId] est la **clé d'idempotence offline** (ADR-0018) : un
  /// renvoi après reconnexion portant la même clé ne crée pas de doublon.
  /// [clientCreatedAt] est l'horodatage d'affichage (ordre de rédaction réel).
  Future<void> sendMessage(
    String groupId, {
    required String body,
    String? clientMessageId,
    DateTime? clientCreatedAt,
  });

  /// `POST /groups/:id/join` — rejoindre librement un groupe `open`.
  Future<void> join(String groupId);

  /// `POST /groups/:id/join-requests` — **demander** à rejoindre un groupe
  /// `request`. L'état « En attente » revient par la synchronisation
  /// (`group_join_requests`).
  Future<void> requestToJoin(String groupId);

  /// `POST /groups/:id/leave` — quitter un groupe.
  Future<void> leave(String groupId);

  /// `POST /groups/:id/join-requests/:requestId/approve` — valider une demande
  /// (leader/modérateur).
  Future<void> approveJoinRequest(String groupId, int requestId);

  /// `POST /groups/:id/join-requests/:requestId/reject` — refuser une demande
  /// (leader/modérateur).
  Future<void> rejectJoinRequest(String groupId, int requestId);
}
