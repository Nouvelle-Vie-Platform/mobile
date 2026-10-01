import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'app_database.dart';
import 'tables/gathering_tables.dart';
import 'tables/mediatheque_tables.dart';

part 'gathering_dao.g.dart';

/// Un rassemblement **et ce que le magasin possède** de sa rubrique et de son
/// intervenant.
///
/// Le pendant exact de `TeachingWithRefs`, et pour les mêmes raisons : [type] et
/// [contributor] peuvent être nuls, les collections se resynchronisent
/// séparément, et le rassemblement s'affiche quand même. Une jointure stricte le
/// ferait disparaître de l'écran — on perdrait le contenu au lieu d'une ligne de
/// texte.
@immutable
class GatheringWithRefs {
  const GatheringWithRefs({
    required this.gathering,
    this.contributor,
    this.type,
  });

  final GatheringRow gathering;

  /// Intervenant, `null` tant que la collection `contributors` — commune aux
  /// deux familles — ne l'a pas encore livré.
  final ContributorRow? contributor;

  /// Rubrique de **rassemblement**, `null` de la même manière.
  final GatheringTypeRow? type;

  /// **La cascade de couleur, terminée à la lecture** : la couleur de la ligne
  /// d'abord, à défaut celle de sa rubrique. `null` = ni l'une ni l'autre, à
  /// l'appelant de replier sur la palette.
  String? get color => gathering.color ?? type?.color;
}

/// Une rubrique de rassemblement, avec le nombre de rassemblements que le
/// magasin en possède. Toujours strictement positif — voir
/// [GatheringDao.homeSections].
@immutable
class GatheringSection {
  const GatheringSection({required this.type, required this.gatheringCount});

  final GatheringTypeRow type;
  final int gatheringCount;
}

/// **Les lectures du magasin, côté rassemblements.**
///
/// Un DAO distinct de `MediathequeDao`, et pas une extension de celui-ci : les
/// deux familles sont deux collections, deux types, deux écrans (ADR-0026,
/// décision 1). Un DAO commun paramétré par une famille rendrait possible
/// — donc, un jour, réel — un appel qui mélange les deux.
///
/// Les deux règles de lecture sont **celles de la médiathèque**, à l'identique :
///
/// - **toute jointure tolère l'absence** — un rassemblement dont la rubrique
///   manque s'affiche quand même ;
/// - **pas de rassemblement, pas de section** — une rubrique dont le magasin ne
///   possède aucun rassemblement ne sort pas de l'accueil.
///
/// Rien ici ne choisit une langue : la carte de traduction est rendue entière,
/// et `pick` reste l'unique endroit où le repli est écrit.
@DriftAccessor(tables: [GatheringTypes, Gatherings, Contributors])
class GatheringDao extends DatabaseAccessor<AppDatabase>
    with _$GatheringDaoMixin {
  GatheringDao(super.db);

  /// **Les rubriques de rassemblement de l'accueil, dans l'ordre du serveur.**
  ///
  /// Une rubrique n'en sort que si elle est visible **et** si le magasin
  /// possède au moins un de ses rassemblements. Ce second filtre n'est pas une
  /// optimisation d'affichage : `gathering_types` se supprime durement et sans
  /// tombstone, exactement comme `teaching_types`, et c'est lui qui fait
  /// disparaître d'elle-même une rubrique retirée côté serveur.
  Selectable<GatheringSection> homeSections() {
    final count = gatherings.id.count();

    final query = select(gatheringTypes).join([
      leftOuterJoin(
        gatherings,
        gatherings.teachingTypeId.equalsExp(gatheringTypes.id),
        useColumns: false,
      ),
    ])
      ..where(gatheringTypes.visibleOnHome.equals(true))
      ..addColumns([count])
      ..groupBy(
        [gatheringTypes.id],
        having: count.isBiggerThanValue(0),
      )
      ..orderBy([
        OrderingTerm.asc(gatheringTypes.position),
        OrderingTerm.asc(gatheringTypes.id),
      ]);

    return query.map(
      (row) => GatheringSection(
        type: row.readTable(gatheringTypes),
        gatheringCount: row.read(count)!,
      ),
    );
  }

  /// Les rassemblements d'une rubrique, du plus récemment mis à disposition au
  /// plus ancien.
  ///
  /// L'identifiant attendu est celui d'une ligne de **`gathering_types`** : la
  /// colonne s'appelle `teachingTypeId` (la verrue du protocole, voir
  /// `tables/gathering_tables.dart`), la table jointe est bien celle des
  /// rubriques de rassemblement.
  Selectable<GatheringWithRefs> gatheringsOfType(int gatheringTypeId) {
    return _gatheringsQuery(
      where: gatherings.teachingTypeId.equals(gatheringTypeId),
    );
  }

  /// Les derniers rassemblements, toutes rubriques confondues.
  Selectable<GatheringWithRefs> latestGatherings({int? limit}) {
    return _gatheringsQuery(limit: limit);
  }

  /// **Les rassemblements que la destination d'une entrée de menu désigne**
  /// (#82) — le pendant strict de `MediathequeDao.teachingsMatching`.
  ///
  /// Deux jeux de providers et deux DAO plutôt qu'un seul paramétré par la
  /// famille : c'est ce qui rend impossible qu'un rassemblement se glisse dans
  /// une liste d'enseignements. `destinationFamily` dit **quelle collection
  /// lire** ; elle ne range pas une ligne.
  Selectable<GatheringWithRefs> gatheringsMatching({
    int? gatheringTypeId,
    String? searchPattern,
  }) {
    final clauses = <Expression<bool>>[
      if (gatheringTypeId != null)
        gatherings.teachingTypeId.equals(gatheringTypeId),
      if (searchPattern != null) gatherings.title.like(searchPattern),
    ];
    if (clauses.isEmpty) return _gatheringsQuery();
    return _gatheringsQuery(where: clauses.reduce((a, b) => a & b));
  }

  /// Un rassemblement par son identifiant.
  ///
  /// **La navigation transporte l'identifiant ; l'écran observe le magasin.**
  /// Une rétractation reçue pendant la consultation retire le contenu de
  /// l'écran ouvert, au lieu de laisser une copie figée au clic continuer de
  /// l'afficher.
  Selectable<GatheringWithRefs> gatheringById(String id) {
    return _gatheringsQuery(where: gatherings.id.equals(id));
  }

  /// Construit la requête de rassemblements avec ses **deux jointures
  /// tolérantes** — l'intervenant et la rubrique manquants sont admis.
  Selectable<GatheringWithRefs> _gatheringsQuery({
    Expression<bool>? where,
    int? limit,
  }) {
    final query = select(gatherings).join([
      leftOuterJoin(
        contributors,
        contributors.id.equalsExp(gatherings.contributorId),
      ),
      leftOuterJoin(
        gatheringTypes,
        gatheringTypes.id.equalsExp(gatherings.teachingTypeId),
      ),
    ]);

    if (where != null) query.where(where);

    // **Le même tri que la médiathèque**, et ce n'est pas une reprise
    // machinale : `publishedAt` date la mise à disposition, c'est-à-dire
    // l'ordre éditorial, et un rassemblement se publie comme un enseignement.
    // Trier sur `recordedAt` — la date du concert — rangerait le catalogue par
    // date d'évènement, ce qui est le travail du calendrier (`events`), pas
    // d'une médiathèque. Les lignes sans date passent derrière, départagées par
    // `recordedAt` puis l'identifiant, pour un ordre **stable**.
    query.orderBy([
      OrderingTerm.desc(gatherings.publishedAt),
      OrderingTerm.desc(gatherings.recordedAt),
      OrderingTerm.desc(gatherings.id),
    ]);

    if (limit != null) query.limit(limit);

    // `readTableOrNull` est ce qui rend la jointure tolérante : sur une
    // jointure externe sans correspondance, il rend `null` au lieu de lever.
    return query.map(
      (row) => GatheringWithRefs(
        gathering: row.readTable(gatherings),
        contributor: row.readTableOrNull(contributors),
        type: row.readTableOrNull(gatheringTypes),
      ),
    );
  }
}
