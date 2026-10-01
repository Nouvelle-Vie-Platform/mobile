/// **Le canal temps réel d'un groupe — et il ne transporte qu'un signal** (#101).
///
/// Ce que cette couche achète, exactement : avec une conversation **ouverte à
/// l'écran**, un message arrive sans attendre le prochain cycle. Hors de cet
/// écran, elle n'achète **rien** — pas de notification, pas de réveil, pas de
/// badge. iOS suspend le réseau dès qu'on passe à autre chose, et Android le
/// fait aussi sous contrainte de batterie. Elle existe parce qu'il n'y a pas de
/// compte Apple Developer Program, donc pas de clé APNs, donc **aucun** push sur
/// iPhone (FCM y passe par APNs) ; elle ne remplace pas le push, elle le
/// complète.
///
/// ## ⚠️ Le signal ne porte **rien**, et c'est la contrainte de la tranche
///
/// [GroupChannelSignal] est une valeur **vide**. Pas de corps de message, pas
/// d'identifiant, rien à désérialiser — donc rien à écrire dans le magasin.
///
/// Ce n'est pas une économie de code, c'est ADR-0006 rendu structurel : la base
/// est la seule source de vérité, le temps réel n'est qu'un **accélérateur de
/// notification**. Un signal déclenche un cycle de synchronisation, et c'est le
/// **moteur** qui écrit — exactement comme le fera le réveil push. Écrire depuis
/// l'événement donnerait deux écritures concurrentes dans la même table Drift,
/// deux curseurs qui se croisent, et un message qui arrive par les deux chemins :
/// le chemin mixte que la décision 1 du cadrage d'Échanges a refusé
/// (`server-portal/docs/echanges-branchement-plan.md`), et la classe de bogue la
/// plus coûteuse à diagnostiquer.
///
/// Un type vide ferme la porte : il n'y a rien à lire dedans. Et un garde-fou de
/// **source** (`test/data/open_thread_channel_test.dart`) interdit à tout fichier
/// de `lib/data/realtime/` d'importer Drift ou un DAO.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// **Le nom du canal d'un groupe**, et la seule copie de ce motif côté client.
///
/// Le serveur le construit à l'identique (`groupChannel` dans
/// `app/groups/contracts/group_broadcaster.ts`) et n'autorise l'abonnement qu'aux
/// **membres** (`CheckGroupMembership`). Un non-membre est refusé, et c'est très
/// bien : le refus n'a aucune conséquence visible (voir [GroupChannelRefused]).
String groupChannelName(String groupId) => 'groups/$groupId';

/// **Un signal, et rien de plus** : « va voir le serveur ».
///
/// Il est émis dans **deux** cas, qui disent la même chose :
///
/// - quelque chose vient d'être diffusé sur le canal ;
/// - le canal vient de s'**ouvrir** — première fois ou réouverture après une
///   coupure. Un canal neuf n'a aucune mémoire de ce qui s'est diffusé avant lui,
///   donc il a le même trou à faire combler.
///
/// La classe est **vide**, et doit le rester. Voir l'en-tête du fichier : tout
/// champ qu'on lui ajouterait serait une donnée venue du réseau, donc une seconde
/// source de vérité à côté du magasin. Et c'est pour cela que les deux cas n'ont
/// pas à être distingués : il n'y a qu'une seule chose à en faire.
@immutable
final class GroupChannelSignal {
  const GroupChannelSignal();

  @override
  String toString() => 'GroupChannelSignal()';
}

/// **L'abonnement a été refusé** — et ce n'est pas une panne.
///
/// Le serveur réserve le canal aux membres du groupe. Un refus veut donc dire
/// « ce fil n'est pas le mien », ou « le magasin était en avance sur mon retrait
/// du groupe ». Il ne se réessaie pas : insister ne changerait pas la réponse, et
/// une boucle d'abonnements refusés coûterait du forfait pour rien.
///
/// Distinct d'une panne de transport, qui elle se rattrape : voir
/// `OpenThreadChannel`.
class GroupChannelRefused implements Exception {
  const GroupChannelRefused(this.channel, this.statusCode);

  final String channel;

  /// Le code du refus, `null` si le serveur n'en a pas donné.
  final int? statusCode;

  @override
  String toString() =>
      'GroupChannelRefused: « $channel » (${statusCode ?? 'sans code'})';
}

/// Contrat d'écoute du canal d'un groupe.
abstract interface class GroupChannel {
  /// Ouvre le canal de [groupId] et rend ses signaux.
  ///
  /// Le flux **ne se termine pas de lui-même** tant que la connexion tient ;
  /// annuler l'abonnement ferme la connexion, et c'est le seul moyen de la
  /// fermer. Une fin de flux (serveur redéployé, réseau coupé) ou une erreur
  /// disent « le canal est tombé » ; c'est à l'appelant de décider s'il rouvre.
  Stream<GroupChannelSignal> watch(String groupId);
}

/// Double **muet** : aucun canal, aucun signal, aucune socket.
///
/// Le défaut sans backend, et celui de tous les tests d'écran : l'implémentation
/// réelle ouvrirait une socket que `flutter test` refuse (400 sur tout accès
/// réseau) et laisserait derrière elle la minuterie de réouverture.
///
/// Un flux **vide et jamais clos** plutôt que `Stream.empty()` : un flux qui se
/// termine tout de suite serait lu comme un canal tombé, et ferait tourner la
/// réouverture dans le vide. Ici, rien ne se passe — exactement ce que doit voir
/// une application dont le temps réel n'existe pas.
class SilentGroupChannel implements GroupChannel {
  const SilentGroupChannel();

  @override
  Stream<GroupChannelSignal> watch(String groupId) =>
      // ignore: close_sinks — le contrôleur est fermé par l'annulation de
      // l'abonnement, qui est le seul moyen de fermer un canal (voir [watch]).
      StreamController<GroupChannelSignal>().stream;
}
