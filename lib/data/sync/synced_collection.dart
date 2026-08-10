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

  final LocalCollection<D> Function(SyncDao dao) _local;
  final Object Function(Map<String, Object?> item) _idOf;
  final Insertable<D> Function(Map<String, Object?> item) _rowOf;

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
/// Les neuf autres collections du registre serveur n'ont pas de table locale :
/// le manifeste les liste, le moteur ne les tire pas. Elles entreront ici avec
/// leur table, jamais avant.
///
/// **Deux familles, deux paires d'entrées** (issue #34) : `teaching_types` /
/// `teachings` d'un côté, `gathering_types` / `gatherings` de l'autre. Ce sont
/// quatre clés distinctes et non deux clés « élargies », parce qu'une
/// collection neuve est **ignorée** par un client qui ne la demande pas, là où
/// une collection élargie **contamine** ceux qui ne savent pas la lire : un
/// concert arrivé dans `teachings` se rangerait dans les rubriques d'accueil de
/// la médiathèque et s'y afficherait comme un message du dimanche.
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
      SyncedCollection<GatheringRow>(
        key: SyncCollectionKey.gatherings,
        local: (dao) => dao.gatheringsCollection,
        idOf: (item) => contentId(SyncCollectionKey.gatherings, item),
        rowOf: gatheringRowOf,
      ),
    ];
