/// Les **deux** tables de la reprise de lecture (issue #43) — et le fait
/// qu'elles soient deux est la seule décision de ce fichier.
///
/// Une position de lecture bouge toutes les dix secondes et doit être là au
/// premier frame, y compris hors ligne, y compris sur un second appareil. Ces
/// trois exigences ne tiennent pas dans une seule table :
///
/// - **[PlaybackProgress]** est une **collection répliquée** (`private`), donc
///   remplie *uniquement* par la synchronisation. C'est elle qui donne la
///   reprise **multi-appareils** — le fidèle écoute dans le taxi, reprend chez
///   lui — et la reprise **après réinstallation**. Le réseau ne peint jamais,
///   et l'application n'écrit **jamais** dedans : écrire dans une collection
///   répliquée est la règle à ne pas tordre (ADR-0026), la synchronisation
///   écraserait, et le bug serait irreproductible.
/// - **[LocalPlaybackPositions]** est **locale seule**, jamais synchronisée,
///   écrite en continu par le lecteur. C'est elle qui permet de rouvrir
///   l'application après un plantage ou un redémarrage et de retomber sur sa
///   place, sans attendre un cycle de synchronisation — et c'est la seule qui
///   marche en avion.
///
/// Suivre à la lettre le précédent du composeur d'annonces (« le réseau ne
/// peint jamais, l'écriture ne touche pas au magasin, le flux delta ramène la
/// ligne ») aurait donné une position qui revient avec plusieurs secondes de
/// retard sur une donnée qui bouge toutes les dix secondes, et **rien du tout
/// hors ligne**. Fondre les deux tables en une aurait fait écrire
/// l'application dans une collection répliquée. Deux tables gardent les deux
/// règles intactes, au prix d'une résolution triviale à la lecture
/// (`PlaybackDao.resumeFor`).
///
/// **Aucune clé étrangère** vers `teachings` / `gatherings`, comme partout
/// ailleurs : la progression survit à la rétractation de son enseignement, et
/// c'est voulu. Une rétractation se défait — republier est courant —, alors
/// qu'une progression effacée est perdue sans recours : le curseur est déjà
/// passé devant elle, elle ne serait plus jamais livrée. La ligne « reprendre
/// la lecture » disparaît d'elle-même faute d'enseignement à joindre (règle 6
/// du magasin).
library;

import 'package:drift/drift.dart';

import 'mediatheque_tables.dart';

/// Collection `playback_progress` — la reprise de lecture, **répliquée** et
/// **privée** (partition `private`, tombstones par `deletedAt`).
///
/// Les colonnes sont celles du transformer serveur
/// (`app/mediatheque/transformers/playback_progress_transformer.ts`), en
/// `camelCase` sur le fil : `id`, `userId`, `teachingId`, `positionSeconds`,
/// `completed`, `clientCreatedAt`, `createdAt`, `updatedAt`.
///
/// **`teachingId` désigne un enseignement *ou* un rassemblement.** Les deux
/// familles partagent une table côté serveur, discriminée par `family` : le nom
/// de la colonne est celui de la table partagée, comme la verrue déjà connue de
/// `gatherings.teachingTypeId`. Ne pas le « corriger » — et ne pas en déduire
/// qu'une seule famille est concernée.
///
/// **Aucune durée nulle part.** Ni ici, ni sur `teachings` : le serveur n'a pas
/// de dénominateur et ne peut donc pas décider qu'un contenu est terminé. Il
/// stocke le booléen que le client lui envoie, et le seuil est une décision
/// application (`playback_progress_recorder.dart`).
@DataClassName('PlaybackProgressRow')
class PlaybackProgress extends Table with SyncedRow {
  @override
  String get tableName => 'playback_progress';

  /// UUIDv7 **fabriqué par le client** et conservé par le serveur à l'insert
  /// (ADR-0001/0018). C'est ce qui rend le rapport rejouable : un rejeu retombe
  /// sur la même ligne au lieu d'en créer une seconde.
  TextColumn get id => text()();

  /// Porteur de la progression — moi, par construction : la collection est
  /// `private` et son `scopeFilter` est `user_id = soi`. Stocké pour le
  /// diagnostic, jamais pour filtrer.
  TextColumn get userId => text().nullable()();

  /// **Entier… non : chaîne nue, et sans clé étrangère.** Le contenu écouté,
  /// enseignement ou rassemblement. La jointure est tolérante et se fait à la
  /// lecture ; la cible n'a pas à exister.
  TextColumn get teachingId => text()();

  /// Position de reprise, **en secondes**. C'est la seule unité du contrat
  /// serveur (`vine.number().min(0)`), et la convertir en `Duration` appartient
  /// à la lecture.
  IntColumn get positionSeconds => integer()();

  /// Décidé par le **client** et stocké tel quel par le serveur. Voir l'en-tête
  /// de cette classe : sans durée, le serveur ne peut rien en dire.
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// Instant de création **côté client**, quand le client en fournit un.
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Table **locale seule** : la position à chaud, écrite par le lecteur.
///
/// Elle ne porte **pas** [SyncedRow], et c'est structurel plutôt que
/// documentaire : sans colonne `sync_stamp`, elle ne peut pas devenir une
/// `LocalCollection` — le balayage de fin de resync et le tampon d'écriture y
/// échoueraient à la première ligne. Il n'y a donc pas de chemin par lequel
/// elle entrerait au registre de `syncedCollections()` par distraction.
///
/// Une ligne par contenu, remplacée en place : on ne garde pas d'historique de
/// positions, seulement la dernière connue.
@DataClassName('LocalPlaybackPositionRow')
class LocalPlaybackPositions extends Table {
  @override
  String get tableName => 'local_playback_positions';

  /// Le contenu écouté — enseignement ou rassemblement, la table ne les
  /// distingue pas : l'identifiant est un UUID et les deux familles partagent
  /// la même route de rapport.
  TextColumn get contentId => text()();

  /// **L'UUIDv7 sous lequel ce contenu est rapporté.**
  ///
  /// Frappé par ce client la première fois qu'il rapporte ce contenu, puis
  /// réutilisé — c'est ce qui fait de chaque rapport suivant un rejeu, donc un
  /// `UPDATE` sans doublon. Quand la synchronisation ramène la ligne serveur,
  /// c'est **son** `id` qui fait autorité (voir `PlaybackDao.resumeFor`) : une
  /// progression née sur un autre appareil a déjà son identité.
  TextColumn get progressId => text()();

  /// Même unité que la collection répliquée, pour que la résolution des deux
  /// sources n'ait aucune conversion à faire.
  IntColumn get positionSeconds => integer()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  /// Horloge **de l'appareil**, et c'est ce qui la départage de la ligne
  /// répliquée, dont l'`updatedAt` vient du serveur. Deux horloges comparées :
  /// voir la réserve écrite dans `PlaybackDao.resumeFor`.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {contentId};
}
