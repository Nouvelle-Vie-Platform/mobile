/// La table **locale seule** du téléchargement hors ligne (#190).
///
/// Elle suit **le même patron que `local_playback_positions`** : jamais
/// synchronisée, jamais dans le registre `syncedCollections()`, écrite par un
/// moteur de l'appareil (ici `DownloadManager`) et non par la synchronisation.
/// Un téléchargement est **physique à un appareil** — un fichier `.aac` sur ce
/// téléphone-ci — et n'a rien à faire dans une collection répliquée (PRD §5,
/// « liste de téléchargements synchronisée » explicitement hors périmètre).
///
/// **C'est ce magasin qui peint l'écran** (ADR-0026, décision 2) : le moteur y
/// écrit la progression et l'état, les écrans (bouton 5 états #192, page
/// Téléchargements #193) les liront. Le réseau — ici les rappels de
/// `background_downloader` — ne peint jamais : il traverse le `DownloadManager`,
/// qui écrit ici, et l'écran observe la table.
///
/// **Aucune clé étrangère** vers `teachings`, comme partout ailleurs
/// (ADR-0026, règle 4) : un enseignement rétracté puis republié est courant, et
/// un téléchargement doit survivre au trou. La purge d'un fichier au retrait de
/// son enseignement est un **geste** du cycle de vie (#194), pas une contrainte
/// d'intégrité.
library;

import 'package:drift/drift.dart';

/// Les états d'un téléchargement, tels que le PRD les nomme (§3.2, F5/F8/F9).
///
/// Stockés **en texte** (`textEnum`) et non en index : l'ordre de cet enum ne
/// doit pas être un contrat de stockage. Ajouter un état plus tard ne doit pas
/// décaler les valeurs déjà écrites sur les téléphones.
enum DownloadState {
  /// En file, pas encore démarré par le moteur natif.
  queued,

  /// Transfert en cours.
  running,

  /// Mis en pause par le fidèle (reprenable par `Range`).
  paused,

  /// **En attente de wifi** : wifi-only actif et l'appareil est sur cellulaire
  /// (F8). Le moteur natif tient la contrainte ; l'état la rend visible.
  waitingWifi,

  /// Fichier complet sur le disque, prêt à l'écoute hors ligne.
  complete,

  /// Échec — réseau, disque plein, tâche perdue. [Downloads.failureReason]
  /// porte le détail, et le partiel est **conservé** (F9).
  failed,

  /// **Mise à jour disponible** : le média a été révisé côté serveur
  /// (`download.version` a changé, ADR-0039). La copie locale reste écoutable ;
  /// le badge et la re-proposition sont le périmètre de #194.
  outdated,
}

/// Collection **locale seule** — un téléchargement par contenu.
///
/// La clé primaire est [contentId] seul : les UUID d'enseignements et de
/// rassemblements sont uniques (même table serveur, ADR discriminée par
/// `family`), donc un identifiant ne peut désigner qu'un contenu. [contentType]
/// reste une **donnée** — pour l'affichage et pour router la lecture (#191)
/// vers la bonne famille — jamais un discriminant de clé.
@DataClassName('DownloadRow')
class Downloads extends Table {
  @override
  String get tableName => 'downloads';

  /// `teaching` en v1. Gardé pour rester agnostique au type de contenu (PRD :
  /// brancher les rassemblements ensuite sans refonte).
  TextColumn get contentType => text()();

  /// L'UUID du contenu téléchargé — la même identité que dans `teachings`.
  TextColumn get contentId => text()();

  /// La qualité **concrète** téléchargée : `low` | `mid` | `high`
  /// ([MediaQuality.key]). Jamais `auto` — le moteur résout le réglage en un
  /// palier concret avant d'écrire ici (le fichier `.aac` en a un).
  TextColumn get quality => text()();

  /// L'état courant. Défaut [DownloadState.queued] : une ligne naît en file.
  TextColumn get state => textEnum<DownloadState>()
      .withDefault(Constant(DownloadState.queued.name))();

  /// Octets déjà sur le disque. Alimente le pourcentage et **valide la reprise**
  /// (`Range`) : on ne recolle jamais des octets par-dessus un total inconnu.
  IntColumn get bytesReceived => integer().withDefault(const Constant(0))();

  /// Taille totale attendue, connue **avant** le réseau (`download.bytes`,
  /// ADR-0038). Sert le pourcentage et le **pré-check d'espace disque** (F9).
  IntColumn get bytesTotal => integer().withDefault(const Constant(0))();

  /// Chemin du fichier sur l'appareil, résolu par le moteur natif. Nul tant que
  /// la tâche n'a pas commencé à écrire. La lecture offline-first (#191) le lit.
  TextColumn get localPath => text().nullable()();

  /// L'identifiant de tâche `background_downloader`. C'est le pont entre cette
  /// ligne et le moteur natif : les rappels de progression/état l'apportent, on
  /// retrouve la ligne par lui. Nul si l'enqueue n'a pas (encore) abouti.
  TextColumn get taskId => text().nullable()();

  /// `download.version` au moment du téléchargement — l'identité du transcode.
  /// C'est la comparaison avec la version courante de l'enseignement (livrée par
  /// la sync) qui détecte une **révision** (ADR-0039) et fait passer
  /// [DownloadState.outdated]. La détection elle-même est #194.
  TextColumn get versionId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Le motif d'échec, quand [state] vaut [DownloadState.failed]. Stocké en
  /// texte (clé stable), l'écran choisit la phrase — comme partout ailleurs, une
  /// erreur ne sort jamais en brut.
  TextColumn get failureReason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {contentId};
}
