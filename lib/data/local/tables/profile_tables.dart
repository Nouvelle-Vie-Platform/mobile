/// Table de la collection répliquée **`profiles`** (PRD serveur
/// `messagerie-directe.md` D8/D9/D10) — la projection minimale de `users` qui
/// donne un **nom** (et un avatar) à chaque `userId`.
///
/// **Réversion assumée d'ADR-0029.** Le dépôt n'avait volontairement aucune
/// collection d'utilisateurs ; les DM l'ont rendue nécessaire (on ne peut pas
/// écrire à — ni titrer une conversation avec — quelqu'un qu'on ne sait pas
/// nommer). Le compromis qui la justifie est le **scope serveur** : jamais un
/// annuaire ouvert, seulement les personnes que je **côtoie** (mes groupes ∪ mes
/// DM). Le client ne recalcule aucun périmètre, il obéit à ce que le serveur
/// sert — comme partout.
///
/// Les trois règles de `mediatheque_tables.dart` valent ici **mot pour mot** :
/// aucune clé étrangère entre collections (un `profiles.id` est joint depuis
/// `group_members.userId` **tolérablement** — un membre sans profil s'affiche
/// quand même, par ses initiales), on stocke ce que le serveur envoie, chaque
/// ligne porte son jeton d'écriture.
///
/// **Deux limites connues, héritées du serveur** (documentées dans son
/// descripteur) : le nom d'un co-membre de longue date peut tarder à arriver
/// (« visibilité sans écriture » — le chemin heureux du DM en est immunisé), et
/// un profil ne se **rétracte pas** en sortie de scope (pas de tombstone) : il
/// subsiste jusqu'à un effacement. Faible nuisance — un nom périmé.
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart';

/// Collection `profiles` — nom + avatar d'un utilisateur que je côtoie
/// (partition `private`, **sans tombstone**).
@DataClassName('ProfileRow')
class Profiles extends Table with SyncedRow {
  @override
  String get tableName => 'profiles';

  /// `users.id` (UUID) servi par le serveur, **en chaîne**. C'est la cible des
  /// jointures depuis `group_members.userId` et des DM.
  TextColumn get id => text()();

  /// Nom d'affichage déjà résolu par le serveur (« Prénom Nom », à défaut le
  /// titre, à défaut `null`). **Jamais** un « Utilisateur inconnu » : `null` se
  /// replie sur les initiales de l'identifiant côté rendu (`AppAvatar`).
  TextColumn get displayName => text().nullable()();

  /// URL d'avatar, `null` aujourd'hui (le profil serveur n'en porte pas encore)
  /// → repli initiales. Réservée pour le jour où `users` portera un avatar.
  TextColumn get avatarUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
