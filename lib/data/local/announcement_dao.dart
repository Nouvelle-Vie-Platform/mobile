import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'app_database.dart';
import 'tables/announcement_tables.dart';

part 'announcement_dao.g.dart';

/// Une annonce **et ce que le magasin possède** de son compte officiel et de
/// son fond.
///
/// Le pendant de `TeachingWithRefs` et de `GatheringWithRefs`, et pour les mêmes
/// raisons : [account] et [background] peuvent être nuls, les collections se
/// resynchronisent séparément, et l'annonce s'affiche quand même. Une jointure
/// stricte la ferait disparaître du mur — on perdrait le statut au lieu d'une
/// ligne d'en-tête ou d'un dégradé.
@immutable
class AnnouncementWithRefs {
  const AnnouncementWithRefs({
    required this.announcement,
    this.account,
    this.background,
  });

  final AnnouncementRow announcement;

  /// Compte officiel signataire, `null` tant que `official_accounts` ne l'a pas
  /// encore livré.
  final OfficialAccountRow? account;

  /// Fond servi, `null` quand l'annonce n'en porte pas **ou** quand
  /// `status_backgrounds` ne l'a pas encore livré. Les deux cas se rendent de la
  /// même façon — teinte dérivée du hash de l'identifiant — et c'est voulu :
  /// dans les deux cas le magasin n'a rien à peindre, et un statut sans fond
  /// n'existe pas.
  final StatusBackgroundRow? background;

  /// **L'en-tête, résolu à la lecture** : le nom court d'abord, le nom complet
  /// à défaut. `null` = le compte manque, et l'absence se dessine comme une
  /// absence — jamais de « Compte inconnu », qui ressemble à une donnée et
  /// serait pris pour une erreur de saisie.
  String? get accountName => account?.shortName ?? account?.name;
}

/// **Les lectures du magasin, côté annonces.**
///
/// Un DAO distinct, comme `GatheringDao` l'est de `MediathequeDao` : ce sont
/// d'autres collections, un autre modèle, un autre écran.
///
/// Deux choses qu'il ne fait **pas**, et qui appartiennent au provider :
///
/// - **il ne filtre pas l'expiration.** Une requête SQL est évaluée quand la
///   table change, pas quand l'heure passe : une annonce expirée pendant qu'un
///   fidèle la regarde resterait à l'écran jusqu'à la synchronisation suivante.
///   Le filtre appartient donc à la lecture, au plus près du rendu ;
/// - **il ne trie pas** épinglés d'abord. La règle de tri est écrite une seule
///   fois, dans `announcementsProvider`, avec le filtre d'expiration qu'elle
///   accompagne. L'ordre rendu ici n'est stable que pour que deux lectures
///   successives d'un magasin inchangé donnent la même liste.
@DriftAccessor(
  tables: [
    Announcements,
    OfficialAccounts,
    OfficialAccountMemberships,
    StatusBackgrounds,
  ],
)
class AnnouncementDao extends DatabaseAccessor<AppDatabase>
    with _$AnnouncementDaoMixin {
  AnnouncementDao(super.db);

  /// Toutes les annonces du magasin, avec leurs **deux jointures tolérantes**.
  ///
  /// Aucun plafond : le mur contient tout ce que le serveur a servi, c'est à lui
  /// de décider ce qu'il expose. Les expirées en font partie — c'est la lecture
  /// qui les retire, à la seconde.
  Selectable<AnnouncementWithRefs> allAnnouncements() {
    final query = select(announcements).join([
      leftOuterJoin(
        officialAccounts,
        officialAccounts.id.equalsExp(announcements.accountId),
      ),
      leftOuterJoin(
        statusBackgrounds,
        statusBackgrounds.id.equalsExp(announcements.backgroundId),
      ),
    ])
      ..orderBy([
        OrderingTerm.desc(announcements.publishedAt),
        OrderingTerm.asc(announcements.id),
      ]);

    // `readTableOrNull` est ce qui rend la jointure tolérante : sur une jointure
    // externe sans correspondance, il rend `null` au lieu de lever.
    return query.map(
      (row) => AnnouncementWithRefs(
        announcement: row.readTable(announcements),
        account: row.readTableOrNull(officialAccounts),
        background: row.readTableOrNull(statusBackgrounds),
      ),
    );
  }

  /// **Suis-je membre d'au moins un compte officiel ?**
  ///
  /// La collection ne contient que mes propres appartenances (le serveur la
  /// scope sur l'acteur) : une ligne suffit, et il n'y a personne d'autre à
  /// écarter. C'est ce qui décide de l'affordance d'écriture — pour une poignée
  /// de personnes ; pour tous les autres, l'onglet reste une visionneuse.
  ///
  /// **Un confort d'affichage, jamais une autorisation** : le serveur revérifie
  /// à chaque écriture, et un membre retiré du bureau dont le téléphone n'a pas
  /// synchronisé verra encore le bouton et recevra un 403.
  Selectable<bool> hasMembership() {
    final count = officialAccountMemberships.id.count();
    final query = selectOnly(officialAccountMemberships)..addColumns([count]);
    return query.map((row) => (row.read(count) ?? 0) > 0);
  }

  /// **Les comptes officiels sous lesquels je peux publier.**
  ///
  /// Une jointure **interne**, à rebours de tout le reste de ce DAO, et c'est
  /// délibéré : ailleurs on tolère l'absence parce qu'il vaut mieux un statut
  /// sans en-tête qu'un statut disparu. Ici l'absence est bloquante — on ne peut
  /// pas offrir de signer au nom d'un compte qu'on ne sait pas nommer. Une
  /// appartenance dont le compte n'est pas encore arrivé sort donc de la liste
  /// et y entrera au cycle suivant.
  ///
  /// Les comptes désactivés (`isActive` faux) sont écartés : un compte se
  /// désactive au portail, jamais ne se supprime, et ses annonces continuent de
  /// s'afficher — mais on n'en publie plus de nouvelles.
  ///
  /// Trié par nom, avec l'identifiant en départage : deux comptes homonymes de
  /// branches différentes ne doivent pas échanger leur place d'un `build` à
  /// l'autre.
  Selectable<OfficialAccountRow> myAccounts() {
    final query = select(officialAccounts).join([
      innerJoin(
        officialAccountMemberships,
        officialAccountMemberships.accountId.equalsExp(officialAccounts.id),
      ),
    ])
      ..where(officialAccounts.isActive.equals(true))
      ..orderBy([
        OrderingTerm.asc(officialAccounts.name),
        OrderingTerm.asc(officialAccounts.id),
      ]);
    return query.map((row) => row.readTable(officialAccounts));
  }

  /// **Les fonds encore proposés à la composition**, dans l'ordre du portail.
  ///
  /// `isActive` est une **donnée, pas un filtre de stockage** : un fond retiré
  /// du catalogue n'est plus offert ici, mais les annonces qui le portent déjà
  /// gardent leur habillage — c'est pour ça qu'`allAnnouncements` le joint sans
  /// condition. Filtrer au stockage aurait fait perdre leur dégradé à des
  /// statuts parfaitement valides.
  Selectable<StatusBackgroundRow> composableBackgrounds() =>
      select(statusBackgrounds)
        ..where((t) => t.isActive.equals(true))
        ..orderBy([
          (t) => OrderingTerm.asc(t.position),
          (t) => OrderingTerm.asc(t.id),
        ]);

  /// **Une annonce brute, par identifiant** — les valeurs telles que le serveur
  /// les a servies, sans jointure ni résolution.
  ///
  /// C'est ce que lit le composeur pour préremplir une modification, et
  /// justement pas `AnnouncementView` : le modèle de lecture a remplacé
  /// `accountId` et `backgroundId` par un nom de compte et trois arrêts de
  /// dégradé. Repartir de lui obligerait à **défaire la jointure** — retrouver
  /// un identifiant à partir d'un libellé, ce qui n'a pas de solution quand deux
  /// comptes portent le même nom court.
  ///
  /// Se lit en `watchSingleOrNull` : `null` = l'annonce a été retirée (par le
  /// serveur, ou par un autre membre du même compte) pendant qu'on la modifiait.
  Selectable<AnnouncementRow> announcementById(String id) =>
      select(announcements)..where((t) => t.id.equals(id));
}
