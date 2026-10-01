import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../models/menu_entry_view.dart';
import 'app_database.dart';
import 'tables/gathering_tables.dart';
import 'tables/mediatheque_tables.dart';
import 'tables/menu_tables.dart';

part 'menu_dao.g.dart';

/// Une entrée de menu **et ce que le magasin sait de sa destination** : les deux
/// rubriques que son slug désigne (une par famille) et le nombre de contenus
/// qu'elle ramènerait.
///
/// Les trois valeurs calculées sont là pour une seule raison : **« pas de
/// contenu, pas de section »**. La collection `menu_entries` n'a pas de
/// tombstone et `SaveMenu` supprime durement — une entrée retirée au portail
/// cesse simplement d'apparaître au flux, et l'appareil qui l'avait reçue la
/// garde pour toujours. C'est le compte de contenus qui la retire de l'écran, et
/// c'est le seul mécanisme qui le fera jamais.
@immutable
class MenuEntryWithContent {
  const MenuEntryWithContent({
    required this.entry,
    required this.teachingCount,
    required this.gatheringCount,
    this.teachingRubricId,
    this.gatheringRubricId,
  });

  final MenuEntryRow entry;

  /// Contenus de `teachings` que la destination ramènerait.
  final int teachingCount;

  /// Contenus de `gatherings` que la destination ramènerait.
  final int gatheringCount;

  /// L'identifiant de `teaching_types` dont le slug est celui demandé, ou
  /// `null` — soit aucun slug n'est demandé, soit le magasin ne le connaît pas
  /// (encore).
  final int? teachingRubricId;

  /// Le même, dans le référentiel de l'autre famille. Les deux référentiels sont
  /// deux collections et rien ne garantit que leurs slugs soient disjoints :
  /// c'est la **famille de la destination** qui dit lequel lire, jamais
  /// l'inverse.
  final int? gatheringRubricId;
}

/// **Les lectures du menu.** Elles ne servent qu'à peindre des écrans.
///
/// Trois règles les gouvernent, et aucune n'est négociable :
///
/// - **rien ne se filtre à l'écriture** : la visibilité de surface est une
///   colonne, la fenêtre de publication est deux colonnes, et le serveur sert
///   toutes les lignes. Ce qui se filtre ici est la seule chose qui ne dépende
///   pas de l'heure : le drapeau de surface ;
/// - **la fenêtre ne se lit pas en SQL** : une requête est évaluée quand la
///   table change, pas quand l'heure passe. Une entrée « jusqu'à ce soir » doit
///   disparaître à la seconde, y compris hors ligne — c'est la règle de
///   l'expiration des annonces, mot pour mot, et c'est
///   `StoreMenuRepository` qui l'applique ;
/// - **le rang est un ordre relatif, jamais un numéro** : `SaveMenu` renumérote
///   `1..n` par surface à chaque enregistrement. On trie dessus, on ne le lit
///   jamais.
@DriftAccessor(
  tables: [MenuEntries, TeachingTypes, GatheringTypes, Teachings, Gatherings],
)
class MenuDao extends DatabaseAccessor<AppDatabase> with _$MenuDaoMixin {
  MenuDao(super.db);

  /// Les entrées **visibles sur une surface**, dans leur ordre, chacune avec la
  /// résolution de son slug et le compte de contenus de sa destination.
  ///
  /// Une requête brute et non un `select` composé, pour une raison et une
  /// seule : les deux comptes et les deux résolutions de slug sont des
  /// sous-requêtes corrélées à la ligne d'entrée, et `readsFrom` est ce qui rend
  /// le flux **réactif aux cinq tables** — un enseignement qui arrive doit faire
  /// paraître l'onglet qui l'attendait, sans qu'on relise le menu à la main.
  ///
  /// Trois choses s'y décident, et elles se lisent dans le SQL :
  ///
  /// 1. **un slug demandé et introuvable ne ramène rien.** La sous-requête rend
  ///    `NULL`, la comparaison devient `NULL`, aucune ligne ne passe — donc
  ///    compte zéro, donc entrée retirée. C'est le bon sens de la panne : mieux
  ///    vaut une entrée absente qu'un onglet « Prières » montrant tout le
  ///    catalogue ;
  /// 2. **une branche demandée ne ramène rien non plus**, et ce n'est pas un
  ///    oubli : `BranchTransformer` ne sert pas de slug au flux delta, la copie
  ///    locale de `branches` n'en porte donc aucun, et il n'y a rien à quoi
  ///    comparer. Le jour où le slug descendra, cette clause est l'unique
  ///    endroit à changer ;
  /// 3. **la recherche figée de l'entrée compte dans le compte**, parce qu'elle
  ///    fait partie de la destination. Celle que la loupe saisit, non : un
  ///    onglet ne doit pas disparaître parce que quelqu'un tape trois lettres.
  Stream<List<MenuEntryWithContent>> watchSurface(MenuSurface surface) {
    final visible = switch (surface) {
      MenuSurface.mediaLibrary => 'media_visible',
      MenuSurface.home => 'home_visible',
    };
    final position = switch (surface) {
      MenuSurface.mediaLibrary => 'media_position',
      MenuSurface.home => 'home_position',
    };

    // Les deux noms de colonne viennent du `switch` ci-dessus, jamais d'un
    // appelant : il n'y a pas de valeur extérieure dans cette chaîne.
    final query = customSelect(
      '''
      SELECT
        e.*,
        (SELECT tt.id FROM teaching_types tt
          WHERE tt.slug = e.destination_rubric) AS teaching_rubric_id,
        (SELECT gt.id FROM gathering_types gt
          WHERE gt.slug = e.destination_rubric) AS gathering_rubric_id,
        (
          SELECT COUNT(*) FROM teachings t
          WHERE e.destination_branch IS NULL
            AND (
              e.destination_rubric IS NULL
              OR t.teaching_type_id = (
                SELECT tt.id FROM teaching_types tt
                WHERE tt.slug = e.destination_rubric
              )
            )
            AND (
              e.destination_search IS NULL
              OR e.destination_search = ''
              OR t.title LIKE '%' || e.destination_search || '%'
            )
        ) AS teaching_count,
        (
          SELECT COUNT(*) FROM gatherings g
          WHERE e.destination_branch IS NULL
            AND (
              e.destination_rubric IS NULL
              OR g.teaching_type_id = (
                SELECT gt.id FROM gathering_types gt
                WHERE gt.slug = e.destination_rubric
              )
            )
            AND (
              e.destination_search IS NULL
              OR e.destination_search = ''
              OR g.title LIKE '%' || e.destination_search || '%'
            )
        ) AS gathering_count
      FROM menu_entries e
      WHERE e.$visible = 1
      ORDER BY e.$position ASC, e.id ASC
      ''',
      readsFrom: {
        menuEntries,
        teachingTypes,
        gatheringTypes,
        teachings,
        gatherings,
      },
    );

    return query.watch().map(
          (rows) => List<MenuEntryWithContent>.unmodifiable(
            rows.map(
              (row) => MenuEntryWithContent(
                entry: menuEntries.map(row.data),
                teachingCount: row.read<int>('teaching_count'),
                gatheringCount: row.read<int>('gathering_count'),
                teachingRubricId: row.readNullable<int>('teaching_rubric_id'),
                gatheringRubricId: row.readNullable<int>('gathering_rubric_id'),
              ),
            ),
          ),
        );
  }
}
