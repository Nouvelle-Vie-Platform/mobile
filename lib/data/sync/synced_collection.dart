/// **Ce que le moteur sait d'une collection répliquée**, et rien de plus : sa
/// clé de protocole, la table locale où ses lignes se rangent, et comment lire
/// un de ses éléments.
///
/// Tout le reste du moteur est écrit **une fois** contre ce descripteur.
/// Quatre copies de « appliquer une page » seraient quatre occasions d'en
/// oublier le curseur, ou de désérialiser une rétractation.
library;

import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../local/sync_dao.dart';
import 'branch_filter.dart';
import 'sync_protocol.dart';
import 'sync_rows.dart';

/// Descripteur d'une collection consommée par ce client.
///
/// Le paramètre de type [D] est la classe de données Drift de la table de
/// destination. Il n'apparaît **que** sur cette classe : le moteur manipule des
/// `SyncedCollection<Object?>` et appelle ses méthodes, qui referment le type
/// pour lui. C'est ce qui permet à la boucle d'être écrite une seule fois sans
/// que le magasin perde sa vérification de types.
final class SyncedCollection<D> {
  SyncedCollection({
    required this.key,
    required LocalCollection<D> Function(SyncDao dao) local,
    required Object Function(Map<String, Object?> item) idOf,
    required Insertable<D> Function(Map<String, Object?> item) rowOf,
  })  : _local = local,
        _idOf = idOf,
        _rowOf = rowOf;

  /// Clé de collection du protocole (`teachings`, `teaching_types`, …).
  ///
  /// **Le seul discriminant du rangement** (ADR-0026, décision 1) : une ligne
  /// se range d'après le canal par lequel elle est arrivée, jamais d'après un
  /// champ qu'elle porte.
  final String key;

  /// **Cette collection est-elle filtrée par la préférence de branche ?**
  ///
  /// Dérivé de [kBranchScopedCollections] plutôt que passé à la construction, et
  /// c'est délibéré : un drapeau posé entrée par entrée serait une seconde
  /// définition de la même liste, libre de diverger de celle que consulte la
  /// remise à zéro des curseurs. Le jour où les deux ne diraient plus la même
  /// chose, le client filtrerait une collection dont il ne nettoie pas les
  /// curseurs — l'incohérence exacte que cette tranche existe pour éviter, et
  /// que rien côté serveur ne rattraperait.
  bool get branchScoped => isBranchScoped(key);

  final LocalCollection<D> Function(SyncDao dao) _local;
  final Object Function(Map<String, Object?> item) _idOf;
  final Insertable<D> Function(Map<String, Object?> item) _rowOf;

  /// La table locale où se rangent les lignes de cette collection.
  ///
  /// Lue par le retour au premier plan (#138) : c'est la liste des tables dont
  /// les flux de l'isolate principal doivent se relire, puisqu'un réveil de
  /// fond a pu y écrire par une autre connexion.
  TableInfo<Table, D> tableIn(SyncDao dao) => _local(dao).table;

  /// Applique une page du régime delta : ses lignes **et** son curseur, ou ni
  /// l'un ni l'autre.
  Future<void> applyPage(SyncDao dao, DeltaPage page) {
    final split = _split(page.items);
    return dao.applyPage<D>(
      _local(dao),
      upserts: split.upserts,
      deletedIds: split.deletedIds,
      cursor: page.nextCursor,
    );
  }

  /// Applique une page d'un re-tirage complet : **sans rien effacer et sans
  /// avancer le curseur**. Les écrans continuent de rendre l'ancien contenu
  /// pendant tout le cycle.
  Future<void> applyResyncPage(SyncDao dao, DeltaPage page) {
    final split = _split(page.items);
    return dao.applyResyncPage<D>(
      _local(dao),
      upserts: split.upserts,
      deletedIds: split.deletedIds,
    );
  }

  /// **Range des lignes arrivées hors du tirage** — le canal `users/{id}` et
  /// l'historique par pages (#140) — par **la même** désérialisation et le même
  /// tri « rétractation ou ligne » que le flux delta, **sans curseur**.
  ///
  /// C'est la règle du contrat serveur (« une ligne, trois chemins ») : le
  /// client range un événement exactement comme il rangerait la même ligne
  /// tirée par la synchronisation. Un tombstone (`deletedAt` posé) retire la
  /// ligne ; une ligne vivante **remplace** la locale, jamais ne la fusionne —
  /// le détachement d'un auteur (ADR-0032) arrive sur une ligne déjà stockée.
  Future<void> applyLive(SyncDao dao, List<Map<String, Object?>> items) {
    final split = _split(items);
    return dao.applyLiveRows<D>(
      _local(dao),
      upserts: split.upserts,
      deletedIds: split.deletedIds,
    );
  }

  /// Ferme le cycle de re-tirage : balaie ce que le cycle n'a pas revu, écrit
  /// le curseur, lève le jeton — en une transaction. Rend le nombre de lignes
  /// balayées.
  Future<int> finishResync(SyncDao dao, {required String? cursor}) =>
      dao.finishResync<D>(_local(dao), cursor: cursor);

  /// **Le tri « rétractation ou ligne », fait avant toute construction.**
  ///
  /// C'est ici, et nulle part ailleurs, que la question est posée. Un élément
  /// qui porte un `deletedAt` non nul quitte le magasin par son identifiant, et
  /// **rien n'en est désérialisé** : la ligne existe toujours côté serveur et
  /// n'a pas le droit d'être vue, garder son titre annulerait le geste.
  _PageSplit<D> _split(List<Map<String, Object?>> items) {
    final upserts = <Insertable<D>>[];
    final deletedIds = <Object>[];
    for (final item in items) {
      if (readsAsRetraction(item)) {
        deletedIds.add(_idOf(item));
      } else {
        upserts.add(_rowOf(item));
      }
    }
    return _PageSplit(upserts: upserts, deletedIds: deletedIds);
  }
}

class _PageSplit<D> {
  const _PageSplit({required this.upserts, required this.deletedIds});

  final List<Insertable<D>> upserts;
  final List<Object> deletedIds;
}

/// **Les collections que ce client réplique, dans l'ordre d'application.**
///
/// **Les référentiels avant le contenu.** Ça ne supprime pas la fenêtre où un
/// enseignement arrive sans son intervenant — les collections se tirent et se
/// resynchronisent séparément, et la jointure de lecture reste tolérante pour
/// cette raison —, mais ça supprime le **cas fréquent** : la toute première
/// synchronisation, où tout arrive en même temps et où l'ordre décide de ce que
/// le fidèle voit à l'ouverture.
///
/// Les autres collections du registre serveur n'ont pas de table locale : le
/// manifeste les liste, le moteur ne les tire pas. Elles entreront ici avec leur
/// table, jamais avant.
///
/// **Les annonces amènent quatre entrées** (issue #35), et l'ordre y compte
/// autant qu'ailleurs : `status_backgrounds`, `official_accounts` et
/// `official_account_memberships` précèdent `announcements`. Une annonce dont le
/// compte manque s'affiche quand même — la jointure est tolérante —, mais elle
/// s'affiche alors **sans en-tête**, ce qu'un fidèle lit comme une donnée
/// perdue. Ranger les trois référentiels avant supprime le cas fréquent : la
/// toute première synchronisation.
///
/// **Deux familles, deux paires d'entrées** (issue #34) : `teaching_types` /
/// `teachings` d'un côté, `gathering_types` / `gatherings` de l'autre. Ce sont
/// quatre clés distinctes et non deux clés « élargies », parce qu'une
/// collection neuve est **ignorée** par un client qui ne la demande pas, là où
/// une collection élargie **contamine** ceux qui ne savent pas la lire : un
/// concert arrivé dans `teachings` se rangerait dans les rubriques d'accueil de
/// la médiathèque et s'y afficherait comme un message du dimanche.
///
/// **`legal_documents` entre parmi les référentiels** (issue #55), et non parmi
/// les contenus : un document légal n'appartient à aucune branche, ne s'adresse
/// à aucune audience, et ne se joint à rien. Il est rangé avec les autres
/// référentiels pour la raison habituelle — la toute première synchronisation,
/// où la barrière de consentement doit pouvoir se lever sur un document
/// **déjà** arrivé. La collection n'a **pas de tombstone** : un document ne se
/// supprime pas, il s'édite.
///
/// **`seasons` et `decor` entrent au même étage** : un référentiel de quelques lignes, dont
/// le fond vertical habille les deux lecteurs. Rangée avant les contenus pour
/// la raison habituelle — un enseignement ouvert au premier lancement doit
/// trouver son décor déjà là, faute de quoi l'écran se peint deux fois.
///
/// **`presentation_vocabulary` se range avec les référentiels, et tôt** (#81).
/// Un mot doit être arrivé **avant la liste qu'il intitule** : une section
/// d'accueil tirée avant sa surcharge s'afficherait sous le mot du dépôt, puis
/// changerait de titre sous les yeux du fidèle au cycle suivant. Et c'est la
/// collection la moins susceptible d'échouer du registre — aucun filtre de
/// périmètre, aucune jointure, aucune date —, ce qui compte pour une raison qui
/// n'a rien d'esthétique : **toute erreur autre qu'un `404` coupe le cycle**,
/// donc toutes les collections rangées après la fautive. Un `404`, lui, saute la
/// collection sans rien dégrader — un serveur en retard d'une version laisse
/// simplement l'application sur ses `.arb`.
///
/// **`menu_entries` se range juste après le vocabulaire, et pour deux raisons**
/// (#82). La première est celle des mots : **un menu doit arriver avant les
/// listes qu'il intitule**, puisque c'est lui qui dit quels onglets existent et
/// ce que chacun filtre — tiré après les contenus, la médiathèque s'ouvrirait
/// une fois sans aucun onglet, puis en pousserait quatre sous les yeux du
/// fidèle. La seconde est celle du risque : la collection ne filtre rien, ne
/// joint rien et ne lit aucune date, elle est donc parmi les moins susceptibles
/// d'échouer — et **toute erreur autre qu'un `404` coupe le cycle**, donc toutes
/// les collections rangées après la fautive.
///
/// ⚠️ **Elle précède donc `branches`, et ce n'est pas un oubli.** Une entrée dont
/// la destination nomme un slug de rubrique ou de branche a besoin du
/// référentiel pour le résoudre — mais cette résolution se fait **à la lecture**,
/// pas à l'écriture, et elle est tolérante dans le seul sens qui soit sûr : un
/// slug qu'on ne sait pas résoudre ne ramène aucun contenu, donc l'entrée ne
/// paraît pas (« pas de contenu, pas de section »). Le pire cas d'un ordre
/// « trop tôt » est un onglet qui manque pendant un cycle ; le pire cas d'un
/// ordre « trop tard » serait une médiathèque sans barre d'onglets à la toute
/// première ouverture, qui est le seul moment où l'ordre compte vraiment.
///
/// **`auth_channels` se range avec les référentiels, et tôt** (#83). C'est la
/// première chose qu'un porteur **sans compte** a besoin de savoir, puisque
/// c'est tout ce que son écran lui propose de faire : par quelle porte entrer.
/// Même raison d'être tôt que le vocabulaire — toute erreur autre qu'un `404`
/// coupe le cycle, donc toutes les collections rangées après la fautive, et une
/// collection d'une ligne sans filtre ni jointure est parmi les moins
/// susceptibles d'échouer. Un `404` la saute sans rien dégrader : l'application
/// reste sur son repli, **l'e-mail seul**, qui est le canal qui envoie
/// réellement un code.
///
/// **`device_settings` se range avec les référentiels, et tôt** (#91). C'est le
/// **réglage d'exploitation du parc** — aujourd'hui le seul seuil du bandeau de
/// mise à jour —, et il vaut pour tout le monde, porteur **sans compte**
/// compris : un invité ouvre l'application avec un APK exactement aussi vieux
/// que celui du membre assis à côté de lui. Même raison d'être tôt que le
/// vocabulaire et les canaux : toute erreur autre qu'un `404` coupe le cycle,
/// donc toutes les collections rangées après la fautive, et une collection d'une
/// ligne sans filtre ni jointure est parmi les moins susceptibles d'échouer. Un
/// `404` la saute sans rien dégrader : le magasin reste sans seuil, et **sans
/// seuil il n'y a pas de bandeau** — un serveur en retard d'une version ne
/// dégrade donc rien du tout.
///
/// **`teaching_guests` se range après `contributors` ET après `teachings`**
/// (#77). C'est un **pivot** : ses deux colonnes ne désignent rien par
/// elles-mêmes, et il ne s'affiche qu'en joignant les deux collections qu'il
/// relie. Le tirer avant l'une ou l'autre donnerait, à la toute première
/// synchronisation, une liste d'invités que le magasin ne saurait pas nommer —
/// la jointure reste tolérante pour la fenêtre inévitable, mais l'ordre
/// supprime le cas fréquent. Il est rangé juste derrière son parent, dont il
/// emprunte le périmètre de livraison côté serveur.
///
/// **`playback_progress` ferme la marche** (issue #43), et c'est la première
/// collection `private` que ce client réplique. Elle se **joint** aux deux
/// familles de contenu et se range donc après elles, par la même règle que
/// partout : une progression arrivée avant son enseignement n'aurait rien à
/// quoi se raccrocher. Elle est en **lecture-depuis-la-synchro seulement** —
/// l'application n'y écrit jamais, elle rapporte au serveur par
/// `POST /teachings/:teachingId/progress` et attend que le flux delta ramène
/// la ligne. Sa position à chaud vit dans `local_playback_positions`, qui n'est
/// pas une collection et n'apparaîtra jamais ici.
///
/// **Les cinq collections d'« Échanges » ferment la marche** (#96), et dans cet
/// ordre-ci : `profiles`, `groups`, `group_members`, `group_join_requests`,
/// `group_messages`.
///
/// `profiles` passe **avant** `group_messages`, et c'est la seule contrainte
/// d'ordre que le cadrage impose en toutes lettres : elle **nomme ce que les
/// messages désignent**, et un référentiel qui ne filtre ni ne joint rien est le
/// moins susceptible d'échouer. Un fil arrivé avant les noms s'afficherait sous
/// des avatars anonymes, puis changerait de visage au cycle suivant — la même
/// gêne que le vocabulaire arrivé après les listes qu'il intitule.
///
/// `group_members` vient après `groups` pour la raison du pivot
/// `teaching_guests` : une appartenance ne désigne rien par elle-même, elle relie
/// un groupe et un profil. Et `group_messages` ferme, parce que c'est la plus
/// volumineuse des cinq et celle dont le périmètre se calcule — donc celle qu'on
/// ne veut jamais voir précéder quoi que ce soit.
///
/// ⚠️ **Aucune des cinq n'entre dans `kBranchScopedCollections`**, bien que
/// `groups` et `group_messages` soient `partition: 'branch'` côté serveur. Leur
/// périmètre réel est l'**appartenance** : filtrer côté client par la préférence
/// de branche retirerait du téléphone un groupe dont je suis membre et qui est
/// rattaché à une autre assemblée — c'est-à-dire ma propre conversation. Les trois
/// autres sont `private`, et une collection privée ne relève d'aucune branche.
/// **`group_reads` se range juste avant `group_messages`** (#140) : à la toute
/// première synchronisation, une lecture arrivée après le fil allumerait tout
/// l'historique en non-lu le temps d'un tirage. Arrivée avant, elle désigne un
/// message que le magasin n'a pas encore — et le compteur retombe alors sur
/// `lastReadAt`, ce qui est juste.
List<SyncedCollection<Object?>> syncedCollections() => [
      SyncedCollection<TeachingTypeRow>(
        key: SyncCollectionKey.teachingTypes,
        local: (dao) => dao.teachingTypesCollection,
        idOf: (item) => referenceId(SyncCollectionKey.teachingTypes, item),
        rowOf: teachingTypeRowOf,
      ),
      SyncedCollection<GatheringTypeRow>(
        key: SyncCollectionKey.gatheringTypes,
        local: (dao) => dao.gatheringTypesCollection,
        idOf: (item) => referenceId(SyncCollectionKey.gatheringTypes, item),
        rowOf: gatheringTypeRowOf,
      ),
      SyncedCollection<StatusBackgroundRow>(
        key: SyncCollectionKey.statusBackgrounds,
        local: (dao) => dao.statusBackgroundsCollection,
        idOf: (item) => referenceId(SyncCollectionKey.statusBackgrounds, item),
        rowOf: statusBackgroundRowOf,
      ),
      SyncedCollection<OfficialAccountRow>(
        key: SyncCollectionKey.officialAccounts,
        local: (dao) => dao.officialAccountsCollection,
        idOf: (item) => referenceId(SyncCollectionKey.officialAccounts, item),
        rowOf: officialAccountRowOf,
      ),
      SyncedCollection<OfficialAccountMembershipRow>(
        key: SyncCollectionKey.officialAccountMemberships,
        local: (dao) => dao.officialAccountMembershipsCollection,
        idOf: (item) =>
            referenceId(SyncCollectionKey.officialAccountMemberships, item),
        rowOf: officialAccountMembershipRowOf,
      ),
      SyncedCollection<LegalDocumentRow>(
        key: SyncCollectionKey.legalDocuments,
        local: (dao) => dao.legalDocumentsCollection,
        idOf: (item) => referenceId(SyncCollectionKey.legalDocuments, item),
        rowOf: legalDocumentRowOf,
      ),
      SyncedCollection<SeasonRow>(
        key: SyncCollectionKey.seasons,
        local: (dao) => dao.seasonsCollection,
        idOf: (item) => referenceId(SyncCollectionKey.seasons, item),
        rowOf: seasonRowOf,
      ),
      SyncedCollection<VocabularyRow>(
        key: SyncCollectionKey.presentationVocabulary,
        local: (dao) => dao.presentationVocabularyCollection,
        // `contentId` et non `referenceId` : l'identifiant est la **clé du
        // catalogue**, une chaîne (`teaching`, `sectionLatestTeachings`), là où
        // les autres référentiels portent un `SERIAL`.
        idOf: (item) =>
            contentId(SyncCollectionKey.presentationVocabulary, item),
        rowOf: presentationVocabularyRowOf,
      ),
      SyncedCollection<MenuEntryRow>(
        key: SyncCollectionKey.menuEntries,
        local: (dao) => dao.menuEntriesCollection,
        // `referenceId` : la PK est un **SERIAL**, donc un entier dans le curseur
        // composé — le patron des référentiels, pas celui du vocabulaire, dont
        // la clé est la chaîne du catalogue.
        idOf: (item) => referenceId(SyncCollectionKey.menuEntries, item),
        rowOf: menuEntryRowOf,
      ),
      SyncedCollection<AuthChannelsRow>(
        key: SyncCollectionKey.authChannels,
        local: (dao) => dao.authChannelsCollection,
        // `referenceId` : la PK du singleton est un **entier** (`id = 1`), pas
        // un UUID — c'est le patron de `decor`, pas celui du vocabulaire.
        idOf: (item) => referenceId(SyncCollectionKey.authChannels, item),
        rowOf: authChannelsRowOf,
      ),
      SyncedCollection<DeviceSettingsRow>(
        key: SyncCollectionKey.deviceSettings,
        local: (dao) => dao.deviceSettingsCollection,
        // `referenceId` : la PK du singleton est un **entier** (`id = 1`), pas
        // un UUID — c'est le patron de `decor` et d'`auth_channels`, pas celui
        // du vocabulaire.
        idOf: (item) => referenceId(SyncCollectionKey.deviceSettings, item),
        rowOf: deviceSettingsRowOf,
      ),
      SyncedCollection<DecorRow>(
        key: SyncCollectionKey.decor,
        local: (dao) => dao.decorCollection,
        idOf: (item) => referenceId(SyncCollectionKey.decor, item),
        rowOf: decorRowOf,
      ),
      SyncedCollection<ContributorRow>(
        key: SyncCollectionKey.contributors,
        local: (dao) => dao.contributorsCollection,
        idOf: (item) => referenceId(SyncCollectionKey.contributors, item),
        rowOf: contributorRowOf,
      ),
      SyncedCollection<BranchRow>(
        key: SyncCollectionKey.branches,
        local: (dao) => dao.branchesCollection,
        idOf: (item) => referenceId(SyncCollectionKey.branches, item),
        rowOf: branchRowOf,
      ),
      SyncedCollection<TeachingRow>(
        key: SyncCollectionKey.teachings,
        local: (dao) => dao.teachingsCollection,
        idOf: (item) => contentId(SyncCollectionKey.teachings, item),
        rowOf: teachingRowOf,
      ),
      SyncedCollection<TeachingGuestRow>(
        key: SyncCollectionKey.teachingGuests,
        local: (dao) => dao.teachingGuestsCollection,
        // `referenceId` et non `contentId` : l'identifiant du pivot est un
        // **entier** (`increments` côté serveur). Seul `teachingId`, qu'il
        // porte, est un UUIDv7.
        idOf: (item) => referenceId(SyncCollectionKey.teachingGuests, item),
        rowOf: teachingGuestRowOf,
      ),
      SyncedCollection<GatheringRow>(
        key: SyncCollectionKey.gatherings,
        local: (dao) => dao.gatheringsCollection,
        idOf: (item) => contentId(SyncCollectionKey.gatherings, item),
        rowOf: gatheringRowOf,
      ),
      SyncedCollection<AnnouncementRow>(
        key: SyncCollectionKey.announcements,
        local: (dao) => dao.announcementsCollection,
        idOf: (item) => contentId(SyncCollectionKey.announcements, item),
        rowOf: announcementRowOf,
      ),
      SyncedCollection<PlaybackProgressRow>(
        key: SyncCollectionKey.playbackProgress,
        local: (dao) => dao.playbackProgressCollection,
        idOf: (item) => contentId(SyncCollectionKey.playbackProgress, item),
        rowOf: playbackProgressRowOf,
      ),
      SyncedCollection<ProfileRow>(
        key: SyncCollectionKey.profiles,
        local: (dao) => dao.profilesCollection,
        // `contentId` : l'identifiant est l'**UUID** de `users`, pas un SERIAL.
        idOf: (item) => contentId(SyncCollectionKey.profiles, item),
        rowOf: profileRowOf,
      ),
      SyncedCollection<GroupRow>(
        key: SyncCollectionKey.groups,
        local: (dao) => dao.groupsCollection,
        idOf: (item) => contentId(SyncCollectionKey.groups, item),
        rowOf: groupRowOf,
      ),
      SyncedCollection<GroupMemberRow>(
        key: SyncCollectionKey.groupMembers,
        local: (dao) => dao.groupMembersCollection,
        // `referenceId` et non `contentId` : l'identifiant d'une appartenance est
        // un **entier** (`increments` côté serveur). Seuls `groupId` et `userId`,
        // qu'elle porte, sont des UUID.
        idOf: (item) => referenceId(SyncCollectionKey.groupMembers, item),
        rowOf: groupMemberRowOf,
      ),
      SyncedCollection<GroupJoinRequestRow>(
        key: SyncCollectionKey.groupJoinRequests,
        local: (dao) => dao.groupJoinRequestsCollection,
        // `referenceId`, pour la raison de `group_members`.
        idOf: (item) => referenceId(SyncCollectionKey.groupJoinRequests, item),
        rowOf: groupJoinRequestRowOf,
      ),
      SyncedCollection<GroupReadRow>(
        key: SyncCollectionKey.groupReads,
        local: (dao) => dao.groupReadsCollection,
        // **`groupId`**, la clé locale (#140) : le contrat demande de ranger la
        // lecture par groupe. L'`id` serveur est celui de l'appartenance.
        idOf: groupReadKey,
        rowOf: groupReadRowOf,
      ),
      SyncedCollection<GroupMessageRow>(
        key: SyncCollectionKey.groupMessages,
        local: (dao) => dao.groupMessagesCollection,
        idOf: (item) => contentId(SyncCollectionKey.groupMessages, item),
        rowOf: groupMessageRowOf,
      ),
    ];

/// **Le descripteur d'une collection, par sa clé**, ou `null` si ce client ne
/// la réplique pas.
///
/// Sert aux chemins qui rangent une ligne **hors du tirage** (#140) : un
/// événement du canal `users/{id}` nomme sa collection, et c'est le descripteur
/// du registre — le même que celui du moteur — qui la range. Il n'y a pas de
/// seconde table de correspondance à tenir.
SyncedCollection<Object?>? syncedCollectionFor(String key) {
  for (final collection in syncedCollections()) {
    if (collection.key == key) return collection;
  }
  return null;
}
