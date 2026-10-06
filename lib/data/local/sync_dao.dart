import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'app_database.dart';
import 'tables/announcement_tables.dart';
import 'tables/gathering_tables.dart';
import 'tables/legal_tables.dart';
import 'tables/mediatheque_tables.dart';
import 'tables/playback_tables.dart';
import 'tables/receipt_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/decor_tables.dart';
import 'tables/group_tables.dart';
import 'tables/interaction_tables.dart';
import 'tables/season_tables.dart';
import 'tables/auth_tables.dart';
import 'tables/device_tables.dart';
import 'tables/menu_tables.dart';
import 'tables/vocabulary_tables.dart';

part 'sync_dao.g.dart';

/// Clés de collection du protocole delta. **Le seul discriminant du rangement**
/// (ADR-0026, décision 1) : une ligne se range d'après le canal par lequel elle
/// est arrivée, jamais d'après un champ qu'elle porte.
abstract final class SyncCollectionKey {
  static const String branches = 'branches';
  static const String teachingTypes = 'teaching_types';
  static const String contributors = 'contributors';
  static const String teachings = 'teachings';

  /// Le **pivot des invités** d'un contenu de médiathèque (#77) : un
  /// enseignement à plusieurs voix, **sans nouvelle famille de contenu**. Une
  /// collection neuve, `partition: 'reference'` — un crédit n'appartient à
  /// aucune branche —, servie aussi au **porteur sans compte** (ADR-0040) : lui
  /// refuser le pivot lui donnerait un épisode dont les intervenants manquent,
  /// c'est-à-dire un écran **faux** plutôt qu'un écran vide.
  ///
  /// Elle porte un **tombstone**, contrairement à
  /// [officialAccountMemberships] : une ligne périmée, ici, est **un nom
  /// affiché sur un écran**. Un intervenant décrédité resterait crédité sur les
  /// téléphones jusqu'à une resynchronisation complète — des semaines —, et
  /// rien côté serveur ne repasserait derrière : il n'y a pas d'écriture à
  /// revérifier, il n'y a qu'un nom.
  static const String teachingGuests = 'teaching_guests';

  /// Rubriques de **rassemblement** — le jumeau de [teachingTypes] pour l'autre
  /// famille. Deux référentiels distincts, jamais mélangés : le serveur ne
  /// livre à chacun que les rubriques de sa famille.
  static const String gatheringTypes = 'gathering_types';

  /// Les **rassemblements** : concert, convention, formation, forum, croisade.
  /// Une collection neuve, jamais un élargissement de [teachings] — une
  /// collection neuve est ignorée par un client qui ne la demande pas, là où une
  /// collection élargie contamine ceux qui ne savent pas la lire.
  static const String gatherings = 'gatherings';

  /// Le **référentiel des fonds de statut** : trois arrêts de dégradé et une
  /// encre, dérivés par le serveur à l'écriture (ADR-0030). Le client peint, il
  /// ne recalcule pas.
  static const String statusBackgrounds = 'status_backgrounds';

  /// Les **comptes officiels d'église** sous lesquels une annonce est publiée.
  /// C'est là que se joint l'en-tête d'un statut, jamais dans l'annonce.
  static const String officialAccounts = 'official_accounts';

  /// **Mes** appartenances aux comptes officiels — la collection est scoppée sur
  /// l'acteur, elle ne contient rien d'autre. Un confort d'affichage, jamais une
  /// autorisation : le serveur revérifie à chaque écriture.
  static const String officialAccountMemberships =
      'official_account_memberships';

  /// Les **annonces** de l'onglet Annonces (les « statuts »).
  static const String announcements = 'announcements';

  /// Les **documents légaux** — CGU, politique de confidentialité, « à
  /// propos » (issue #55). Un **référentiel** sans aucun filtre de périmètre :
  /// un document légal n'appartient à aucune branche, ne s'adresse à aucune
  /// audience, et les trois genres partent aux trois lecteurs de la même
  /// façon. Elle passe par le flux delta et non par un `GET /legal/:kind`
  /// parce que la barrière de consentement doit afficher **hors ligne** ce
  /// qu'elle demande d'accepter.
  static const String legalDocuments = 'legal_documents';

  /// **Les saisons** — la période datée dont le fond vertical habille les deux
  /// lecteurs. Un **référentiel** sans filtre de périmètre, servi **entier** :
  /// c'est le téléphone qui élit la saison du jour, parce qu'il est le seul à
  /// savoir quel jour on est hors ligne, et le seul à pouvoir basculer à minuit
  /// sans réseau.
  static const String seasons = 'seasons';

  /// **Le décor par défaut** — le fond que l'application pose quand aucune
  /// saison ne couvre le jour. Une collection d'une seule ligne (le singleton
  /// des réglages de la vitrine), et une clé à elle plutôt qu'une saison sans
  /// dates : deux notions, deux clés.
  static const String decor = 'decor';

  /// **Le vocabulaire réglé au portail** (#81) — les termes de l'église et les
  /// surcharges de libellé qui recouvrent les `.arb` de l'application.
  ///
  /// Un **référentiel** sans aucun filtre de périmètre : un mot n'appartient à
  /// aucune branche, et le porteur sans compte lit la même façade qu'un membre
  /// — lui refuser le vocabulaire lui donnerait l'**ancien** mot là où le
  /// membre voit le nouveau.
  ///
  /// **Sans tombstone, et sans en avoir besoin** : la ligne ne se supprime
  /// jamais côté serveur. Effacer une surcharge y écrit `null`, et c'est ce
  /// `null` qui apprend au téléphone de revenir à son `.arb` — une suppression
  /// de ligne, elle, ne voyagerait pas.
  ///
  /// ⚠️ Son `id` est une **chaîne** (la clé du catalogue), là où les autres
  /// référentiels portent un `SERIAL`.
  static const String presentationVocabulary = 'presentation_vocabulary';

  /// **Les entrées de menu** (#82) — ce qui porte un libellé, une visibilité et
  /// un ordre **par surface**, et une destination décrite en termes métier.
  ///
  /// La clé est `menu_entries` et elle ne se renommera plus (ADR-0017 amendé par
  /// ADR-0024) : c'est le nom de l'**objet**, pas celui de son rendu. « tabs »
  /// aurait nommé le rendu d'une entrée sur **une** surface, or une même entrée
  /// paraît dans la médiathèque et à l'accueil, sous deux gabarits.
  ///
  /// Un **référentiel** sans aucun filtre de périmètre : un menu n'appartient à
  /// aucune branche — il y a un site public et une application, et la barre
  /// réglée depuis Aného est celle de Lomé. Et elle est servie **sans compte**
  /// (`servesAnonymous`), ce qui n'est pas un confort mais la condition de
  /// l'écran : la médiathèque et l'accueil sont les deux premiers écrans qu'un
  /// porteur sans compte ouvre, et sans le drapeau il n'aurait **aucun** onglet.
  ///
  /// **Sans tombstone, et c'est un manque assumé** : `SaveMenu` écrit le menu en
  /// entier, donc une entrée que le tableau posté ne nomme plus est supprimée
  /// durement et cesse simplement de paraître au flux. La réparation appartient
  /// au client, sur le patron « pas de contenu, pas de section ».
  static const String menuEntries = 'menu_entries';

  /// **Les canaux de connexion** (#83) — par quelles portes l'application
  /// propose d'entrer, et ce qu'elle annonce.
  ///
  /// Un **référentiel** sans aucun filtre de périmètre : une porte d'entrée
  /// n'appartient à aucune branche — il n'y a pas une connexion de Lomé et une
  /// d'Aného. Et elle est servie **sans compte** (`servesAnonymous`), ce qui
  /// n'est pas un confort : l'écran de connexion est par définition regardé par
  /// quelqu'un qui n'a pas de compte, et un refus ici laisserait l'application
  /// proposer pour toujours une porte fermée.
  ///
  /// **Sans tombstone, et sans en avoir besoin** : le singleton ne se supprime
  /// pas. **Fermer** un canal met un booléen à `false`, et c'est cette ligne-là
  /// qui voyage.
  static const String authChannels = 'auth_channels';

  /// **Le réglage d'exploitation du parc** (#91) — aujourd'hui le seul seuil du
  /// bandeau de mise à jour, réglé depuis l'écran *Appareils* du portail.
  ///
  /// Un **référentiel** sans aucun filtre de périmètre : un parc d'appareils
  /// n'appartient à aucune branche — il n'y a pas une version recommandée à Lomé
  /// et une autre à Aného. Et elle est servie **sans compte**
  /// (`servesAnonymous`), ce qui n'est pas un confort : un invité utilise
  /// l'application, et son APK est exactement aussi vieux que celui du membre
  /// assis à côté de lui.
  ///
  /// **Sans tombstone, et sans en avoir besoin** : le singleton ne se supprime
  /// pas. **Retirer** le seuil met la colonne à `null`, et c'est cette ligne-là
  /// qui voyage.
  static const String deviceSettings = 'device_settings';

  /// **La reprise de lecture** — la première collection `private` que ce client
  /// réplique (issue #43). Elle est en **lecture-depuis-la-synchro seulement** :
  /// l'application écrit sa position à chaud dans `local_playback_positions`,
  /// qui n'est pas une collection, et rapporte au serveur par
  /// `POST /teachings/:teachingId/progress`. Rien de local n'entre jamais ici.
  static const String playbackProgress = 'playback_progress';

  /// **Mes requêtes** (#148) — demandes de prière, suggestions et réclamations
  /// que j'ai envoyées, et leur statut de traitement. `partition: 'private'`
  /// (`owner_id = soi` côté serveur), **avec** tombstone. Elle se remplit par le
  /// flux, jamais par l'application : un envoi (`POST /interactions`) est suivi
  /// d'un cycle, et c'est ce cycle qui ramène la ligne.
  static const String myInteractions = 'my_interactions';

  /// **Les profils de mes co-membres** (#96) — la projection `{id, displayName,
  /// avatarUrl}` de `users` qui donne un **nom** à chaque `userId`.
  ///
  /// `partition: 'private'`, et le périmètre est **relationnel** et non de
  /// branche : les personnes que je côtoie, jamais un annuaire. C'est la
  /// réversion assumée d'ADR-0029 côté serveur, et sans elle la rubrique
  /// Échanges ne pouvait pas être peinte — un fil où personne n'a de nom.
  ///
  /// **Sans tombstone** : sortir de mon périmètre ne produit aucun signal. Le
  /// coût est borné par la lecture, qui ne nomme que ce qu'elle affiche.
  static const String profiles = 'profiles';

  /// **Les groupes** (#96) : le groupe, son effectif actif, sa politique
  /// d'adhésion et son régime d'écriture.
  ///
  /// `partition: 'branch'` côté serveur, mais le périmètre réel est
  /// l'**appartenance** — national ∪ branche visible ∪ groupes rejoints. Servie
  /// au porteur **sans compte**, et **vide** : il n'appartient à rien.
  ///
  /// **Sans tombstone** : la table serveur n'a pas de `deleted_at`, retirer un
  /// groupe met `isActive` à `false`.
  static const String groups = 'groups';

  /// **Le roster de mes groupes** (#96) : ma ligne **et** celles de mes
  /// co-membres. `partition: 'private'`.
  ///
  /// **Avec tombstone**, et il porte mon propre départ autant que le retrait
  /// d'un co-membre. C'est la seule des cinq dont la rétractation retire
  /// vraiment quelque chose de l'écran, et c'est pourquoi la liste des
  /// conversations se lit sur elle plutôt que sur `groups`.
  static const String groupMembers = 'group_members';

  /// **Mes demandes d'adhésion** ∪ celles des groupes que j'administre (#96).
  /// `partition: 'private'`.
  ///
  /// **Avec tombstone**, mais il n'est pas le canal de la décision : un verdict
  /// voyage par le changement de `status` et le bump d'`updated_at`. Un client
  /// qui attendrait le `deleted_at` ne l'apprendrait jamais.
  static const String groupJoinRequests = 'group_join_requests';

  /// **Le fil** (#96). `partition: 'branch'`, périmètre réel = l'appartenance.
  ///
  /// **Avec tombstone** : la suppression de modération voyage, et la ligne quitte
  /// le magasin quelle que soit son origine.
  ///
  /// ⚠️ Rangée **après** [profiles], exprès : elle désigne ce que les profils
  /// nomment, et un référentiel sans filtre ni jointure est le moins susceptible
  /// d'échouer.
  static const String groupMessages = 'group_messages';

  /// **Ma position de lecture** dans chacun de mes groupes (#140, serveur M1a).
  /// `partition: 'private'` : seule ma lecture voyage, et seulement chez moi —
  /// la mettre dans `group_members` l'aurait envoyée à tous les co-membres.
  ///
  /// **Sans tombstone.** Rangée par `groupId`, et rangée **avant**
  /// [groupMessages] dans le registre : à la toute première synchronisation, la
  /// lecture arrivée d'abord évite que tout l'historique ne s'allume en non-lu
  /// le temps que le fil soit tiré.
  static const String groupReads = 'group_reads';

  /// **Mon rangement** de chacune de mes discussions (#146, M8) : archivée,
  /// épinglée. `partition: 'private'`, **sans tombstone**, rangée par
  /// `groupId` — désarchiver revient avec le champ nul.
  static const String groupArrangements = 'group_arrangements';

  /// **L'accusé de chacun de mes messages** (#142, serveur M3) : ✓✓ et ✓✓
  /// bleu. `partition: 'private'` (servie à l'auteur seul), **sans
  /// tombstone**, rangée par l'identifiant du message, et **après**
  /// [groupMessages] : une coche n'a de sens que sur un message déjà là.
  static const String messageReceipts = 'message_receipts';
}

/// Descripteur local d'une collection répliquée : sa clé de protocole et la
/// table où ses lignes se rangent.
///
/// Il existe pour que les primitives transactionnelles soient écrites **une
/// fois** plutôt qu'une par collection. Quatre copies de « appliquer une page »
/// seraient quatre occasions d'en oublier le curseur.
final class LocalCollection<D> {
  const LocalCollection._(this.key, this.table);

  /// Clé du protocole (`teachings`, `teaching_types`, …).
  final String key;

  /// Table locale de destination.
  final TableInfo<Table, D> table;
}

/// Nom de la colonne de jeton d'écriture, commune à toutes les tables de
/// collection (voir `SyncedRow`).
const String _kSyncStampColumn = 'sync_stamp';

/// **Les primitives transactionnelles du magasin.**
///
/// Trois opérations, et l'ordre dans lequel elles se composent est l'essentiel
/// de ce fichier :
///
/// - [applyPage] — appliquer une page du flux : ses lignes **et** son curseur,
///   ou ni l'un ni l'autre ;
/// - [beginResync] / [applyResyncPage] / [finishResync] — remplacer une
///   collection entière **sans jamais la vider d'abord** ;
/// - [readScopeVersion] / [writeScopeVersion] — l'état global, qui ne suit
///   surtout pas la règle des curseurs.
@DriftAccessor(
  tables: [
    SyncCursors,
    SyncState,
    ResyncTokens,
    Branches,
    TeachingTypes,
    Contributors,
    Teachings,
    TeachingGuests,
    GatheringTypes,
    Gatherings,
    StatusBackgrounds,
    OfficialAccounts,
    OfficialAccountMemberships,
    Announcements,
    PlaybackProgress,
    LegalDocuments,
    Seasons,
    PresentationVocabulary,
    MenuEntries,
    Decor,
    AuthChannels,
    DeviceSettings,
    Profiles,
    Groups,
    GroupMembers,
    GroupJoinRequests,
    GroupMessages,
    GroupReads,
    MyInteractions,
    GroupArrangements,
    MessageReceipts,
  ],
)
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  /// **Point d'injection de panne, réservé aux tests.**
  ///
  /// Appelé à l'intérieur de la transaction d'[applyPage], entre l'écriture des
  /// lignes et celle du curseur. Il n'existe que pour prouver l'invariant
  /// central : une coupure à cet instant précis ne doit **rien** laisser
  /// derrière elle. Nul en production.
  @visibleForTesting
  Future<void> Function()? crashBetweenRowsAndCursor;

  LocalCollection<BranchRow> get branchesCollection =>
      LocalCollection._(SyncCollectionKey.branches, branches);

  LocalCollection<TeachingTypeRow> get teachingTypesCollection =>
      LocalCollection._(SyncCollectionKey.teachingTypes, teachingTypes);

  LocalCollection<ContributorRow> get contributorsCollection =>
      LocalCollection._(SyncCollectionKey.contributors, contributors);

  LocalCollection<TeachingRow> get teachingsCollection =>
      LocalCollection._(SyncCollectionKey.teachings, teachings);

  /// **Le pivot des invités** (#77). Rien d'un contenu : deux identifiants et
  /// un rang. Son tombstone passe par le chemin commun — `readsAsRetraction`
  /// trie en amont, et la ligne quitte le magasin par son identifiant, sans
  /// qu'aucune colonne locale ne garde la trace du retrait.
  LocalCollection<TeachingGuestRow> get teachingGuestsCollection =>
      LocalCollection._(SyncCollectionKey.teachingGuests, teachingGuests);

  LocalCollection<GatheringTypeRow> get gatheringTypesCollection =>
      LocalCollection._(SyncCollectionKey.gatheringTypes, gatheringTypes);

  LocalCollection<GatheringRow> get gatheringsCollection =>
      LocalCollection._(SyncCollectionKey.gatherings, gatherings);

  LocalCollection<StatusBackgroundRow> get statusBackgroundsCollection =>
      LocalCollection._(SyncCollectionKey.statusBackgrounds, statusBackgrounds);

  LocalCollection<OfficialAccountRow> get officialAccountsCollection =>
      LocalCollection._(SyncCollectionKey.officialAccounts, officialAccounts);

  LocalCollection<OfficialAccountMembershipRow>
      get officialAccountMembershipsCollection => LocalCollection._(
            SyncCollectionKey.officialAccountMemberships,
            officialAccountMemberships,
          );

  LocalCollection<AnnouncementRow> get announcementsCollection =>
      LocalCollection._(SyncCollectionKey.announcements, announcements);

  /// **Sans tombstone** : un document légal ne se supprime pas, il s'édite. Le
  /// serveur pose `tombstoneColumn: null` sur ce descripteur, aucune
  /// rétractation ne voyage — et le jour où un genre cesserait d'être servi,
  /// ce serait une migration, pas un `deleted_at`.
  LocalCollection<LegalDocumentRow> get legalDocumentsCollection =>
      LocalCollection._(SyncCollectionKey.legalDocuments, legalDocuments);

  /// **Sans tombstone non plus** : une saison se supprime pour de bon côté
  /// serveur, et la disparition ne voyage pas. Le coût est borné par
  /// [SeasonDao], qui départage deux saisons du même jour par le plus grand
  /// `id` — la saison recréée l'emporte sur celle qu'on venait d'effacer.
  LocalCollection<SeasonRow> get seasonsCollection =>
      LocalCollection._(SyncCollectionKey.seasons, seasons);

  /// **Sans tombstone, et sans en avoir besoin** : un mot réglé ne se supprime
  /// pas, il repasse à `null` — et c'est ce `null` qui porte le retour au mot
  /// du dépôt jusqu'au téléphone. Supprimer la ligne laisserait un appareil
  /// déjà synchronisé afficher pour toujours un mot que le portail ne montre
  /// plus.
  LocalCollection<VocabularyRow> get presentationVocabularyCollection =>
      LocalCollection._(
        SyncCollectionKey.presentationVocabulary,
        presentationVocabulary,
      );

  /// **Toutes les entrées, éteintes et hors fenêtre comprises** (#82) : la
  /// visibilité par surface et la fenêtre de publication sont des **colonnes**,
  /// pas un périmètre de livraison. C'est le décochage lui-même qui voyage, et
  /// c'est la seule forme sous laquelle il puisse voyager — la collection n'a
  /// pas de tombstone, une ligne écartée par un filtre serveur resterait pour
  /// toujours sur l'appareil qui l'avait reçue.
  LocalCollection<MenuEntryRow> get menuEntriesCollection =>
      LocalCollection._(SyncCollectionKey.menuEntries, menuEntries);

  /// **Une seule ligne**, et `null` y est une valeur : pas de décor déposé au
  /// portail n'est pas la même chose que pas encore reçu les réglages.
  LocalCollection<DecorRow> get decorCollection =>
      LocalCollection._(SyncCollectionKey.decor, decor);

  /// **Une seule ligne, et pas de tombstone** : fermer un canal met un booléen
  /// à `false` — la fermeture voyage donc par le flux normal, sur la ligne
  /// elle-même. Une table vide, elle, ne dit pas « aucun canal » mais « pas
  /// encore reçu les réglages », et c'est `AuthChannelsDao` qui en décide.
  LocalCollection<AuthChannelsRow> get authChannelsCollection =>
      LocalCollection._(SyncCollectionKey.authChannels, authChannels);

  /// **Une seule ligne, et pas de tombstone** : retirer le seuil met la colonne
  /// à `null` — le retrait voyage donc par le flux normal, sur la ligne
  /// elle-même. Une table vide, elle, ne dit pas autre chose qu'une colonne
  /// nulle : dans les deux cas il n'y a pas de seuil, donc pas de bandeau, et
  /// c'est `DeviceSettingsDao` qui en décide.
  LocalCollection<DeviceSettingsRow> get deviceSettingsCollection =>
      LocalCollection._(SyncCollectionKey.deviceSettings, deviceSettings);

  /// **Sans tombstone** (#96) : un profil sorti de mon périmètre relationnel ne
  /// produit aucun signal de retrait. Un nom périmé est la nuisance assumée ; la
  /// lecture ne nomme de toute façon que ce qu'un fil affiche encore.
  LocalCollection<ProfileRow> get profilesCollection =>
      LocalCollection._(SyncCollectionKey.profiles, profiles);

  /// **Sans tombstone non plus** : la table serveur n'a pas de `deleted_at`, et
  /// retirer un groupe met `isActive` à `false` — c'est cette ligne-là qui
  /// voyage. Quitter un groupe, en revanche, ne fait voyager que la rétractation
  /// de **mon appartenance** ([groupMembersCollection]) : le groupe reste en
  /// magasin, et c'est la lecture qui cesse de le lister.
  LocalCollection<GroupRow> get groupsCollection =>
      LocalCollection._(SyncCollectionKey.groups, groups);

  /// **Avec tombstone**, et c'est la collection sur laquelle repose la
  /// disparition d'une conversation : ma propre ligne voyage tombstonée quand je
  /// quitte, celle d'un co-membre quand il est retiré.
  LocalCollection<GroupMemberRow> get groupMembersCollection =>
      LocalCollection._(SyncCollectionKey.groupMembers, groupMembers);

  /// **Avec tombstone**, mais le verdict d'une demande voyage par son `status`,
  /// pas par un `deleted_at`.
  LocalCollection<GroupJoinRequestRow> get groupJoinRequestsCollection =>
      LocalCollection._(SyncCollectionKey.groupJoinRequests, groupJoinRequests);

  /// **Avec tombstone** : une suppression de modération retire le message du
  /// magasin, quelle que soit son origine — y compris un message système.
  LocalCollection<GroupMessageRow> get groupMessagesCollection =>
      LocalCollection._(SyncCollectionKey.groupMessages, groupMessages);

  /// **Sans tombstone**, rangée par `groupId` (#140). Le canal `users/{id}`
  /// l'écrit aussi (`read.advanced`), mais seulement vers l'avant — voir
  /// `MessagingStoreWriter`.
  LocalCollection<GroupReadRow> get groupReadsCollection =>
      LocalCollection._(SyncCollectionKey.groupReads, groupReads);

  /// **Sans tombstone**, rangée par `groupId` (#146). Le canal l'écrit aussi
  /// (`arrangement.changed`), jamais en arrière — voir `MessagingStoreWriter`.
  LocalCollection<GroupArrangementRow> get groupArrangementsCollection =>
      LocalCollection._(
        SyncCollectionKey.groupArrangements,
        groupArrangements,
      );

  /// **Sans tombstone**, rangée par l'identifiant du message (#142). Le canal
  /// `users/{id}` l'écrit aussi (`receipt.updated`).
  LocalCollection<MessageReceiptRow> get messageReceiptsCollection =>
      LocalCollection._(SyncCollectionKey.messageReceipts, messageReceipts);

  /// **La seule collection `private` de ce registre.** Elle se remplit comme
  /// les dix autres — par le flux delta, jamais par l'application — et rien
  /// dans ce DAO ne permet d'en retirer une ligne autrement qu'en obéissant à
  /// une rétractation reçue du serveur.
  LocalCollection<PlaybackProgressRow> get playbackProgressCollection =>
      LocalCollection._(SyncCollectionKey.playbackProgress, playbackProgress);

  /// **Avec tombstone** : une requête supprimée côté serveur quitte le magasin.
  LocalCollection<MyInteractionRow> get myInteractionsCollection =>
      LocalCollection._(SyncCollectionKey.myInteractions, myInteractions);

  // ───────────────────────────────────────────────────────────────────────────
  // Application d'une page
  // ───────────────────────────────────────────────────────────────────────────

  /// **Applique une page du flux : ses lignes et son curseur, ou ni l'un ni
  /// l'autre.** C'est l'invariant central du magasin.
  ///
  /// Un curseur écrit séparément des lignes qu'il représente produit, à la
  /// première coupure, l'un de deux états : des lignes appliquées deux fois —
  /// bénin —, ou **un curseur avancé sur des lignes jamais appliquées**. Le
  /// second est un trou permanent : le keyset ne repassera jamais derrière la
  /// borne, rien ne le signalera, et seul un `full_resync` le refermerait —
  /// que rien ne déclenchera.
  ///
  /// [deletedIds] porte les lignes que le serveur a fait quitter le magasin :
  /// tombstone (`deletedAt` non nul) sur la plupart des collections,
  /// **rétractation** `{ id, deletedAt }` sur `teachings`. Un seul mécanisme
  /// create/update/delete, deux formes de charge utile — c'est à l'appelant de
  /// trancher « rétractation ou ligne » **avant** toute construction d'objet,
  /// jamais à un désérialiseur unique et strict, qui lèverait sur la première
  /// rétractation reçue.
  ///
  /// [cursor] est **opaque** : il est stocké et rejoué, jamais décodé ni
  /// construit. Il est écrit tel que le serveur l'a rendu, `null` compris.
  Future<void> applyPage<D>(
    LocalCollection<D> collection, {
    List<Insertable<D>> upserts = const [],
    List<Object> deletedIds = const [],
    required String? cursor,
    DateTime? syncedAt,
  }) {
    return transaction(() async {
      await _writeRows(collection, upserts, deletedIds);
      await crashBetweenRowsAndCursor?.call();
      await _writeCursor(collection.key, cursor, syncedAt);
    });
  }

  /// **Range des lignes arrivées par un autre chemin que le tirage** — le canal
  /// `users/{id}` et l'historique par pages (#140) — **sans toucher au
  /// curseur**.
  ///
  /// Les lignes sont celles du flux delta, mot pour mot (le serveur les produit
  /// par la même fonction, `group_sync_rows.ts`), et elles passent donc par la
  /// même écriture que [applyPage] : même `insertOrReplace`, même jeton
  /// d'écriture. Seul le curseur reste où il est, et c'est l'invariant central
  /// qui l'exige : un curseur ne couvre que ce que le **tirage** a livré. Une
  /// ligne rangée ici sera re-tirée au cycle suivant, et réécrite à l'identique —
  /// l'écriture est idempotente.
  ///
  /// Le jeton est neuf : une ligne rangée pendant un remplacement complet porte
  /// un jeton postérieur au sien, et le balayage final ne l'emporte donc pas.
  Future<void> applyLiveRows<D>(
    LocalCollection<D> collection, {
    List<Insertable<D>> upserts = const [],
    List<Object> deletedIds = const [],
  }) {
    return transaction(() => _writeRows(collection, upserts, deletedIds));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Resynchronisation complète — un remplacement, jamais une destruction
  // ───────────────────────────────────────────────────────────────────────────

  /// **(1) Pose le jeton de resync**, dans la transaction qui l'apprend.
  ///
  /// À composer avec l'application de la page qui portait `full_resync: true` :
  /// `db.transaction(() async { await dao.beginResync(…); … })`. Le jeton
  /// survit à une coupure ; tant qu'il est là, le cycle recommence.
  ///
  /// Rendre le jeton d'écriture alloué n'est pas nécessaire à l'appelant — il
  /// est rendu pour les tests et le diagnostic.
  Future<int> beginResync(String collectionKey, {DateTime? startedAt}) {
    return transaction(() async {
      final stamp = await _allocateStamp();
      await into(resyncTokens).insert(
        ResyncTokensCompanion.insert(
          collection: collectionKey,
          stamp: stamp,
          startedAt: startedAt ?? DateTime.now(),
        ),
        mode: InsertMode.insertOrReplace,
      );
      return stamp;
    });
  }

  /// **Marque des collections « à remplacer »**, sans attendre que le serveur
  /// le demande.
  ///
  /// C'est le seul chemin par lequel le **client** déclenche un remplacement, et
  /// il existe pour un cas précis : la **préférence de branche a changé**. Le
  /// serveur ne le détecte pas — il filtre sur le paramètre de la requête, il
  /// n'a aucune trace de ce que le client demandait au cycle précédent — et ne
  /// posera donc jamais `full_resync_required`. Sans ce marquage, l'application
  /// garderait des lignes qu'elle ne doit plus afficher (le keyset ne repasse
  /// jamais derrière son curseur) ou manquerait celles qu'elle devrait voir.
  /// **Rien côté serveur ne le rattrapera.**
  ///
  /// Ce n'est **pas** un nouveau mécanisme : le jeton posé ici est exactement
  /// celui de [beginResync], et `SyncEngine` le lit déjà (« un jeton survivant
  /// dit qu'un remplacement a été interrompu »). Le cycle suivant re-tire donc
  /// chaque collection marquée **depuis zéro** et balaie, dans la transaction
  /// finale, tout ce qu'il n'a pas revu — c'est-à-dire précisément les lignes
  /// sorties du périmètre. Aucune purge préalable : les écrans continuent de
  /// peindre l'ancien contenu jusqu'au remplacement.
  ///
  /// **Le curseur n'est pas effacé**, et il ne faut pas l'effacer : `_resync` ne
  /// le rejoue pas, et `finishResync` l'écrase. Le laisser en place fait qu'une
  /// coupure avant le remplacement laisse le magasin exactement où il était, au
  /// lieu de le laisser sans borne et sans ses lignes.
  ///
  /// Une collection déjà marquée le reste (`insertOrReplace` sur la table des
  /// jetons) : l'appel est **idempotent**.
  Future<void> markForReplacement(Iterable<String> collectionKeys) {
    return transaction(() async {
      for (final key in collectionKeys) {
        await beginResync(key);
      }
    });
  }

  /// **(2) Applique une page du re-tirage, sans rien effacer et sans avancer le
  /// curseur.**
  ///
  /// Les écrans continuent de rendre l'ancien contenu pendant tout le
  /// re-tirage : c'est tout l'objet du remplacement atomique. Le curseur n'est
  /// pas écrit ici — une coupure en plein cycle doit faire **recommencer** le
  /// re-tirage depuis zéro au tour suivant, pas le reprendre au milieu d'un
  /// magasin dont le balayage final n'a pas eu lieu.
  Future<void> applyResyncPage<D>(
    LocalCollection<D> collection, {
    List<Insertable<D>> upserts = const [],
    List<Object> deletedIds = const [],
  }) {
    return transaction(() => _writeRows(collection, upserts, deletedIds));
  }

  /// **(3) Ferme le cycle** : supprime les lignes que ce cycle n'a pas revues,
  /// écrit le curseur, lève le jeton — le tout en une transaction.
  ///
  /// C'est ici, et seulement ici, que quelque chose est supprimé. Vider d'abord
  /// aurait laissé un fidèle hors ligne **sans son catalogue et sans rien
  /// reçu** : il était hors ligne avec ses enseignements trente secondes plus
  /// tôt, il se retrouverait devant un écran « pas encore synchronisé », ce qui
  /// est un mensonge.
  ///
  /// Lève un [StateError] si aucun cycle n'est ouvert : balayer sans jeton
  /// supprimerait tout ce qui n'a pas été réécrit à l'instant.
  Future<int> finishResync<D>(
    LocalCollection<D> collection, {
    required String? cursor,
    DateTime? syncedAt,
  }) {
    return transaction(() async {
      final token = await _resyncTokenRow(collection.key);
      if (token == null) {
        throw StateError(
          'finishResync sans jeton pour « ${collection.key} » : '
          'le balayage supprimerait des lignes que rien n\'a re-tirées.',
        );
      }

      final swept = await (delete(collection.table)
            ..where((_) => _syncStampOf(collection).isSmallerThanValue(
                  token.stamp,
                )))
          .go();

      await _writeCursor(collection.key, cursor, syncedAt);
      await (delete(resyncTokens)
            ..where((t) => t.collection.equals(collection.key)))
          .go();

      return swept;
    });
  }

  /// Jeton de resync en cours pour [collectionKey], `null` si aucun cycle n'est
  /// ouvert. Le moteur s'en sert pour savoir qu'il doit repartir de zéro plutôt
  /// que de rejouer le curseur persisté.
  Future<int?> resyncToken(String collectionKey) async =>
      (await _resyncTokenRow(collectionKey))?.stamp;

  // ───────────────────────────────────────────────────────────────────────────
  // Curseurs
  // ───────────────────────────────────────────────────────────────────────────

  /// Curseur persisté de [collectionKey] ; `null` si la collection n'a jamais
  /// vu de page appliquée **ou** si le serveur a rendu un curseur nul.
  Future<String?> cursorFor(String collectionKey) async {
    final row = await (select(syncCursors)
          ..where((t) => t.collection.equals(collectionKey)))
        .getSingleOrNull();
    return row?.cursor;
  }

  /// Tous les curseurs connus, prêts à partir en `cursors[<collection>]` sur le
  /// manifeste.
  Future<Map<String, String>> allCursors() async {
    final rows = await select(syncCursors).get();
    return {
      for (final row in rows)
        if (row.cursor != null) row.collection: row.cursor!,
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // État global
  // ───────────────────────────────────────────────────────────────────────────

  /// Version de périmètre persistée ; `null` = jamais synchronisé.
  Future<int?> readScopeVersion() async {
    final row = await (select(syncState)
          ..where((t) => t.id.equals(kSyncStateRowId)))
        .getSingleOrNull();
    return row?.scopeVersion;
  }

  /// Persiste la version de périmètre.
  ///
  /// **À n'appeler qu'en dernier**, une fois que chaque collection marquée
  /// `full_resync_required` a purgé et re-tiré jusqu'à `has_more: false`
  /// (ADR-0027). Persistée trop tôt — a fortiori collection par collection —
  /// elle éteindrait à jamais un resync qui n'a pas eu lieu : le manifeste
  /// suivant recevrait une version à jour et ne le redemanderait plus.
  ///
  /// Volontairement **hors** de toute transaction de page : la rapprocher d'une
  /// écriture de lignes serait la ranger par collection, ce que la table de
  /// curseurs interdit précisément.
  Future<void> writeScopeVersion(int version) async {
    await (update(syncState)..where((t) => t.id.equals(kSyncStateRowId)))
        .write(SyncStateCompanion(scopeVersion: Value(version)));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rouages
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _writeRows<D>(
    LocalCollection<D> collection,
    List<Insertable<D>> upserts,
    List<Object> deletedIds,
  ) async {
    if (upserts.isEmpty && deletedIds.isEmpty) return;

    if (deletedIds.isNotEmpty) {
      await (delete(collection.table)
            ..where((_) => _idIn(collection, deletedIds)))
          .go();
    }

    if (upserts.isEmpty) return;

    // Un seul jeton pour toute la page : les lignes d'une même transaction sont
    // vues ou pas vues ensemble.
    final stamp = await _allocateStamp();
    for (final row in upserts) {
      await into(collection.table).insert(
        _stamped(row, stamp),
        // Le serveur envoie la ligne **entière** à chaque fois : remplacer est
        // exact, et évite d'avoir à distinguer création et mise à jour.
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  Future<void> _writeCursor(
    String collectionKey,
    String? cursor,
    DateTime? syncedAt,
  ) async {
    await into(syncCursors).insert(
      SyncCursorsCompanion.insert(
        collection: collectionKey,
        cursor: Value(cursor),
        syncedAt: syncedAt ?? DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<ResyncTokenRow?> _resyncTokenRow(String collectionKey) {
    return (select(resyncTokens)
          ..where((t) => t.collection.equals(collectionKey)))
        .getSingleOrNull();
  }

  /// Alloue le prochain jeton d'écriture. **Toujours appelé dans une
  /// transaction**, ce qui sérialise les allocations concurrentes.
  Future<int> _allocateStamp() async {
    final row = await (select(syncState)
          ..where((t) => t.id.equals(kSyncStateRowId)))
        .getSingle();
    final stamp = row.nextStamp;
    await (update(syncState)..where((t) => t.id.equals(kSyncStateRowId)))
        .write(SyncStateCompanion(nextStamp: Value(stamp + 1)));
    return stamp;
  }

  /// Recopie [row] en y posant le jeton d'écriture de la transaction.
  ///
  /// Passe par les colonnes brutes plutôt que par un `copyWith` par collection :
  /// le jeton est une mécanique du magasin, pas une donnée que l'appelant a à
  /// connaître — donc pas une chose qu'il puisse oublier de renseigner.
  Insertable<D> _stamped<D>(Insertable<D> row, int stamp) {
    return RawValuesInsertable<D>({
      ...row.toColumns(false),
      _kSyncStampColumn: Variable<int>(stamp),
    });
  }

  GeneratedColumn<int> _syncStampOf<D>(LocalCollection<D> collection) {
    return collection.table.columnsByName[_kSyncStampColumn]!
        as GeneratedColumn<int>;
  }

  /// Prédicat « l'identifiant est dans cette liste ».
  ///
  /// Le protocole préserve le type natif de l'identifiant : entier (SERIAL)
  /// pour les référentiels, chaîne (UUIDv7) pour le contenu (§2.4 du cadrage).
  /// Ce sont les deux seules formes, et une troisième doit lever plutôt que se
  /// deviner.
  Expression<bool> _idIn<D>(LocalCollection<D> collection, List<Object> ids) {
    final key = collection.table.$primaryKey.single;
    if (key is GeneratedColumn<int>) {
      return key.isIn([for (final id in ids) id as int]);
    }
    if (key is GeneratedColumn<String>) {
      return key.isIn([for (final id in ids) id as String]);
    }
    throw StateError(
      'Clé primaire de type inattendu sur « ${collection.key} ».',
    );
  }
}
