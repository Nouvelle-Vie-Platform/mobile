import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../models/teaching_download.dart';
import 'app_database.dart';
import 'tables/mediatheque_tables.dart';

part 'mediatheque_dao.g.dart';

/// Un enseignement **et ce que le magasin possède** de sa rubrique et de son
/// intervenant.
///
/// [type] et [contributor] peuvent être nuls, et c'est le point : les
/// collections arrivent et se resynchronisent séparément, rien ne garantit
/// qu'un enseignement et son intervenant soient à jour au même instant.
/// L'enseignement s'affiche quand même — une jointure stricte le ferait
/// disparaître de l'écran, ce qui est bien pire : on perdrait le contenu au lieu
/// d'une ligne de texte.
///
/// L'absence s'affiche comme une absence, jamais comme un texte inventé : pas
/// d'« Auteur inconnu », qui ressemble à une donnée et sera pris pour une erreur
/// de saisie. La ligne du nom ne se rend pas, et paraîtra au cycle suivant.
@immutable
class TeachingWithRefs {
  const TeachingWithRefs({
    required this.teaching,
    this.contributor,
    this.type,
  });

  final TeachingRow teaching;

  /// Intervenant, `null` tant que la collection `contributors` ne l'a pas
  /// encore livré (ou ne le livrera plus).
  final ContributorRow? contributor;

  /// Rubrique, `null` de la même manière.
  final TeachingTypeRow? type;

  /// **La cascade de couleur, terminée à la lecture.**
  ///
  /// La couleur de la ligne d'abord ; à défaut celle de sa rubrique. Elle n'est
  /// jamais figée à l'écriture : changer la couleur d'une rubrique ne touche
  /// aucune ligne `teachings`, donc les enseignements qui en héritaient
  /// garderaient l'ancienne teinte sur les téléphones, indéfiniment et en
  /// silence.
  ///
  /// `null` = ni l'une ni l'autre : à l'appelant de replier sur la palette du
  /// thème.
  String? get color => teaching.color ?? type?.color;
}

/// Un **invité** d'un contenu de médiathèque, et ce que le magasin possède de
/// l'intervenant qu'il crédite (#77).
///
/// [contributor] peut être nul, exactement comme celui de [TeachingWithRefs] et
/// pour la même raison : `teaching_guests` et `contributors` sont deux
/// collections, qui arrivent et se resynchronisent séparément. La ligne de pivot
/// est rendue **quand même** — c'est ce qui garantit qu'un invité dont
/// l'intervenant n'est pas encore arrivé ne fasse pas disparaître les autres de
/// l'écran.
///
/// L'absence se dessine comme une absence à l'étage du dessus : un invité sans
/// nom ne se rend pas, et paraîtra au cycle suivant. Aucun « Invité inconnu »
/// n'est fabriqué nulle part.
@immutable
class TeachingGuestWithContributor {
  const TeachingGuestWithContributor({required this.guest, this.contributor});

  final TeachingGuestRow guest;

  /// L'intervenant crédité, `null` tant que la collection `contributors` ne l'a
  /// pas encore livré (ou ne le livrera plus).
  final ContributorRow? contributor;
}

/// Une rubrique de l'accueil, avec le nombre d'enseignements que le magasin en
/// possède.
@immutable
class HomeSection {
  const HomeSection({required this.type, required this.teachingCount});

  final TeachingTypeRow type;

  /// Toujours strictement positif : une rubrique sans enseignement n'est pas
  /// une section (voir [MediathequeDao.homeSections]).
  final int teachingCount;
}

/// **Les lectures du magasin.** Elles ne servent qu'à peindre des écrans, et
/// deux règles les gouvernent :
///
/// - **toute jointure tolère l'absence** — un enseignement dont l'intervenant
///   manque s'affiche quand même ;
/// - **pas d'enseignement, pas de section** — une rubrique sans enseignement
///   local ne sort pas.
///
/// Rien ici ne choisit une langue : la carte de traduction est rendue entière,
/// et `utils/i18n_text.dart` → `pick(map, locale)` reste l'**unique** endroit où
/// la règle de repli est écrite.
@DriftAccessor(
  tables: [Branches, TeachingTypes, Contributors, Teachings, TeachingGuests],
)
class MediathequeDao extends DatabaseAccessor<AppDatabase>
    with _$MediathequeDaoMixin {
  MediathequeDao(super.db);

  /// **Les rubriques de l'accueil, dans l'ordre voulu par le serveur.**
  ///
  /// Une rubrique n'en sort que si elle est visible **et** si le magasin
  /// possède au moins un de ses enseignements. Ce second filtre n'est pas une
  /// optimisation d'affichage : c'est ce qui fait disparaître d'elle-même une
  /// rubrique supprimée côté serveur.
  ///
  /// `teaching_types` est la seule collection de référence qu'un administrateur
  /// peut supprimer, et elle se supprime **durement, sans tombstone** : la ligne
  /// cesse simplement d'apparaître dans le flux, aucun message de retrait ne
  /// voyage, et le téléphone qui l'avait téléchargée la garde. Sans cette règle,
  /// l'accueil porterait une section fantôme définitivement vide que rien ne
  /// viendrait jamais retirer. La base serveur refusant de supprimer une
  /// rubrique encore référencée, les reclassements ont forcément voyagé avant :
  /// la section se vide, puis disparaît.
  ///
  /// Elle couvre au passage la rubrique fraîchement créée mais pas encore
  /// remplie. Le client ne suppose jamais que son référentiel local est exact —
  /// seulement qu'il est *au moins aussi grand* que le vrai.
  Selectable<HomeSection> homeSections() {
    final count = teachings.id.count();

    // Jointure externe **et** garde `> 0` : la règle doit rester lisible et
    // survivre à quiconque changerait le type de jointure.
    final query = select(teachingTypes).join([
      leftOuterJoin(
        teachings,
        teachings.teachingTypeId.equalsExp(teachingTypes.id),
        useColumns: false,
      ),
    ])
      ..where(teachingTypes.visibleOnHome.equals(true))
      ..addColumns([count])
      ..groupBy(
        [teachingTypes.id],
        having: count.isBiggerThanValue(0),
      )
      ..orderBy([
        OrderingTerm.asc(teachingTypes.position),
        OrderingTerm.asc(teachingTypes.id),
      ]);

    return query.map(
      (row) => HomeSection(
        type: row.readTable(teachingTypes),
        teachingCount: row.read(count)!,
      ),
    );
  }

  /// Les enseignements d'une rubrique, du plus récemment mis à disposition au
  /// plus ancien.
  Selectable<TeachingWithRefs> teachingsOfType(int teachingTypeId) {
    return _teachingsQuery(
      where: teachings.teachingTypeId.equals(teachingTypeId),
    );
  }

  /// Les derniers enseignements, toutes rubriques confondues.
  Selectable<TeachingWithRefs> latestTeachings({int? limit}) {
    return _teachingsQuery(limit: limit);
  }

  /// **Les enseignements que la destination d'une entrée de menu désigne** —
  /// c'est ce qui fait enfin filtrer les onglets de la médiathèque (#82).
  ///
  /// Deux bornes, et elles se **composent** : la rubrique que l'entrée a
  /// choisie, et la recherche. Le tri ne change pas d'un onglet à l'autre —
  /// c'est le même `publishedAt DESC, recordedAt DESC, id DESC` que partout,
  /// parce qu'un onglet borne un périmètre, il ne réordonne pas le catalogue.
  ///
  /// ⚠️ **Les cultes entiers ne sont pas écartés ici, et c'est une décision.**
  /// Le modèle de menu ne porte aucune colonne qui les concerne : décider dans
  /// le client qu'une entrée les exclut serait une règle éditoriale figée dans le
  /// binaire, invisible depuis le portail et impossible à défaire sans
  /// livraison — exactement ce que la décision 13 du cadrage refuse. Le portail
  /// a déjà le moyen de les écarter là où il appartient, dans la donnée : les
  /// ranger dans leur rubrique et ne pointer aucune entrée dessus. Le seul
  /// endroit qui continue de les exclure est `latestTeachingsProvider`, et sa
  /// raison lui est propre (voir son en-tête).
  Selectable<TeachingWithRefs> teachingsMatching({
    int? teachingTypeId,
    String? searchPattern,
  }) {
    final clauses = <Expression<bool>>[
      if (teachingTypeId != null)
        teachings.teachingTypeId.equals(teachingTypeId),
      if (searchPattern != null) teachings.title.like(searchPattern),
    ];
    if (clauses.isEmpty) return _teachingsQuery();
    return _teachingsQuery(
      where: clauses.reduce((a, b) => a & b),
    );
  }

  /// Un enseignement par son identifiant.
  ///
  /// **La navigation transporte l'identifiant ; l'écran observe le magasin.**
  /// Passer un objet de domaine par la navigation en ferait une photographie
  /// prise au moment du clic : un fidèle qui regarde un enseignement pendant que
  /// la rétractation arrive continuerait de le voir, puis le trouverait disparu
  /// en revenant à la liste. Ici, il disparaît, et l'écran peut l'annoncer comme
  /// retiré.
  Selectable<TeachingWithRefs> teachingById(String id) {
    return _teachingsQuery(where: teachings.id.equals(id));
  }

  /// **Les invités d'un contenu, dans l'ordre saisi** (#77).
  ///
  /// La jointure est **tolérante**, comme celle de [_teachingsQuery] et pour une
  /// raison plus forte encore : ici la jointure stricte ne perdrait pas une
  /// ligne de texte, elle perdrait **les autres invités**. SQLite ne rendrait
  /// simplement pas la ligne dont l'intervenant manque, et un générique de trois
  /// noms s'afficherait à deux sans que rien ne le signale — jusqu'au cycle qui
  /// livre le contributeur manquant, ou jamais.
  ///
  /// L'ordre est celui de `position`, **saisi au portail** : le générique d'un
  /// enseignement à plusieurs voix n'est pas une liste alphabétique. Deux invités
  /// au même rang sont départagés par l'identifiant du pivot, pour que l'ordre
  /// soit **stable** d'un appel à l'autre.
  ///
  /// Rien ici ne sait ce qu'est un podcast : la requête vaut pour **tout**
  /// enseignement, et un message du dimanche auquel un invité a été crédité la
  /// rend aussi bien.
  Selectable<TeachingGuestWithContributor> guestsOfTeaching(String teachingId) {
    final query = select(teachingGuests).join([
      leftOuterJoin(
        contributors,
        contributors.id.equalsExp(teachingGuests.contributorId),
      ),
    ])
      ..where(teachingGuests.teachingId.equals(teachingId))
      ..orderBy([
        OrderingTerm.asc(teachingGuests.position),
        OrderingTerm.asc(teachingGuests.id),
      ]);

    // `readTableOrNull` est ce qui rend la jointure tolérante : sur une jointure
    // externe sans correspondance, il rend `null` au lieu de lever.
    return query.map(
      (row) => TeachingGuestWithContributor(
        guest: row.readTable(teachingGuests),
        contributor: row.readTableOrNull(contributors),
      ),
    );
  }

  /// **Une rubrique par son slug** — ce qui survit à son renommage, et ce que
  /// portent les destinations de menu comme les URL publiques.
  ///
  /// Aucune contrainte d'unicité locale : le serveur la garantit, et le magasin
  /// n'a pas à refuser ce qu'il reçoit. `watchSingleOrNull` suffit donc, et un
  /// doublon serveur se verrait comme une erreur de lecture plutôt que comme un
  /// choix arbitraire.
  Selectable<TeachingTypeRow> teachingTypeBySlug(String slug) {
    return select(teachingTypes)..where((t) => t.slug.equals(slug));
  }

  /// Toutes les branches connues, par ordre alphabétique.
  Selectable<BranchRow> allBranches() {
    return select(branches)..orderBy([(t) => OrderingTerm.asc(t.name)]);
  }

  /// Construit la requête d'enseignements avec ses **deux jointures
  /// tolérantes** — l'intervenant et la rubrique manquants sont admis.
  Selectable<TeachingWithRefs> _teachingsQuery({
    Expression<bool>? where,
    int? limit,
  }) {
    final query = select(teachings).join([
      leftOuterJoin(
        contributors,
        contributors.id.equalsExp(teachings.contributorId),
      ),
      leftOuterJoin(
        teachingTypes,
        teachingTypes.id.equalsExp(teachings.teachingTypeId),
      ),
    ]);

    if (where != null) query.where(where);

    // `publishedAt` date la mise à disposition — c'est l'ordre éditorial. Les
    // lignes qui n'en portent pas passent derrière (SQLite range les NULL en
    // dernier sur un tri décroissant), départagées par `recordedAt` puis par
    // l'identifiant, pour que l'ordre soit **stable** d'un appel à l'autre.
    query.orderBy([
      OrderingTerm.desc(teachings.publishedAt),
      OrderingTerm.desc(teachings.recordedAt),
      OrderingTerm.desc(teachings.id),
    ]);

    if (limit != null) query.limit(limit);

    // `readTableOrNull` est ce qui rend la jointure tolérante : sur une
    // jointure externe sans correspondance, il rend `null` au lieu de lever.
    return query.map(
      (row) => TeachingWithRefs(
        teaching: row.readTable(teachings),
        contributor: row.readTableOrNull(contributors),
        type: row.readTableOrNull(teachingTypes),
      ),
    );
  }

  /// **Le contrat de téléchargement d'un enseignement** (`teachings.download`,
  /// ADR-0038), ou `null` s'il n'est pas téléchargeable / pas connu.
  ///
  /// C'est la **source de vérité** des URLs et des tailles, connue **hors
  /// ligne** : le `DownloadManager` s'en sert pour lancer un téléchargement et
  /// pour le ré-enqueuer à la réconciliation, sans jamais toucher au réseau. En
  /// `Future` et non en `Stream` : le moteur la lit au moment d'agir, il n'a pas
  /// à l'observer.
  Future<TeachingDownload?> downloadFor(String contentId) async {
    final row = await (select(teachings)..where((t) => t.id.equals(contentId)))
        .getSingleOrNull();
    return row?.download;
  }

  /// **Le titre d'un enseignement**, ou `null` s'il n'est pas dans le magasin.
  ///
  /// Le `DownloadManager` le lit au moment du `download()` pour le
  /// **dénormaliser** sur la ligne `downloads` (#194) : après un retrait,
  /// l'enseignement quitte le magasin et la notification de purge n'aurait plus
  /// de quoi le nommer.
  Future<String?> titleFor(String contentId) async {
    final row = await (select(teachings)..where((t) => t.id.equals(contentId)))
        .getSingleOrNull();
    return row?.title;
  }

  /// **L'état serveur d'un enseignement téléchargé**, lu APRÈS une sync pour le
  /// cycle de vie (#194) — ou `null` si l'enseignement **n'est plus dans le
  /// magasin**.
  ///
  /// Le magasin est autoritaire (ADR-0026) : on s'appuie sur ce qu'il contient
  /// après réconciliation, jamais sur le delta brut. `null` signifie donc
  /// « retiré » (rétractation, ADR-0025) → purge. Une version de téléchargement
  /// différente de celle stockée signifie « révisé » (ADR-0039) → `outdated`.
  Future<TeachingSyncState?> syncStateFor(String contentId) async {
    final row = await (select(teachings)..where((t) => t.id.equals(contentId)))
        .getSingleOrNull();
    if (row == null) return null;
    return TeachingSyncState(downloadVersion: row.download?.version);
  }
}

/// Ce que le magasin sait d'un enseignement téléchargé après une sync, pour
/// trancher **révision** vs **rien** (le retrait, lui, se lit à l'absence de la
/// ligne — voir [MediathequeDao.syncStateFor]).
@immutable
class TeachingSyncState {
  const TeachingSyncState({required this.downloadVersion});

  /// La version courante du contrat de téléchargement (`download.version`), ou
  /// `null` si l'enseignement n'est pas / plus téléchargeable.
  final String? downloadVersion;
}
