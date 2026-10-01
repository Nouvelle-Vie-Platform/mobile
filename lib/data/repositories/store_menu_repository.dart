import '../../models/menu_entry_view.dart';
import '../local/app_database.dart';
import '../local/menu_dao.dart';
import 'menu_repository.dart';

/// Les menus **peints depuis le magasin local**, jamais depuis le réseau.
///
/// C'est **l'unique endroit** où une ligne de `menu_entries` devient une entrée
/// affichable, et où les sept pièges du contrat se paient une fois pour toute
/// l'application :
///
/// 1. **le serveur sert toutes les lignes**, éteintes comprises : le drapeau de
///    surface est filtré par le DAO, la **fenêtre de publication** l'est ici ;
/// 2. **les deux bornes sont des instants**, comparés à l'horloge courante —
///    pas des jours comparés comme des chaînes (`seasons`) ;
/// 3. **le rang est un ordre relatif** : le DAO trie dessus, personne ne le lit ;
/// 4. **les slugs sont des slugs** : `destinationRubric` se rapproche des lignes
///    locales du référentiel de **sa** famille, jamais d'un identifiant ;
/// 5. **`parentId` est un entier nu** : un orphelin est ignoré, il ne lève pas ;
/// 6. **`label = null` veut dire « le libellé du dépôt »**, porté par
///    `labelKey` — les deux voyagent ensemble, et c'est la couche de
///    présentation qui tranche (`l10n/menu_labels.dart`) ;
/// 7. **`destinationKind` est une chaîne libre** : un type inconnu fait
///    disparaître l'entrée, en silence et sans repli.
///
/// Et la règle de réparation, qui vaut pour les deux surfaces : **pas de
/// contenu, pas de section.** La collection n'a pas de tombstone et `SaveMenu`
/// supprime durement — une entrée retirée au portail cesse simplement de
/// paraître au flux, et l'appareil qui l'avait reçue la garde. C'est le compte de
/// contenus qui la retire de l'écran, et rien d'autre ne le fera.
class StoreMenuRepository implements MenuRepository {
  const StoreMenuRepository(this._dao);

  final MenuDao _dao;

  @override
  Stream<List<MenuEntryView>> menu(
    MenuSurface surface, {
    required String locale,
    required DateTime Function() now,
  }) {
    return _dao.watchSurface(surface).map(
          (rows) => _resolve(rows, surface: surface, locale: locale, at: now()),
        );
  }

  /// La résolution, en un seul passage : fenêtre, destination, arbre, contenu.
  List<MenuEntryView> _resolve(
    List<MenuEntryWithContent> rows, {
    required MenuSurface surface,
    required String locale,
    required DateTime at,
  }) {
    final instant = at.toUtc();
    final kept = <int, _Resolved>{};

    // Premier passage : ce qui survit à la fenêtre et à la destination. L'ordre
    // de `rows` est celui du rang de surface, et il est conservé.
    for (final row in rows) {
      if (!_inWindow(row.entry, instant)) continue;
      final destination = _destinationOf(row);
      if (destination == null) continue;
      kept[row.entry.id] =
          _Resolved(row, destination, _countOf(row, destination));
    }

    // Second passage : l'arbre. Une sous-entrée dont le parent n'est pas retenu
    // — absent du magasin, éteint sur cette surface, hors fenêtre, destination
    // inconnue — n'a pas d'onglet sous lequel se poser : elle est **ignorée**, et
    // ne remonte surtout pas à la racine. La faire remonter mettrait dans la
    // barre une entrée que personne n'y a mise.
    final childrenOf = <int, List<_Resolved>>{};
    final roots = <_Resolved>[];
    for (final resolved in kept.values) {
      final parentId = resolved.row.entry.parentId;
      if (parentId == null) {
        roots.add(resolved);
      } else if (kept.containsKey(parentId)) {
        childrenOf.putIfAbsent(parentId, () => []).add(resolved);
      }
    }

    final views = <MenuEntryView>[];
    for (final root in roots) {
      // « Pas de contenu, pas de section », appliqué à l'arbre : une sous-entrée
      // vide s'efface, et un parent vide **survit** si l'une de ses puces a
      // quelque chose à montrer — l'onglet existe alors pour ses puces.
      final children = [
        for (final child
            in childrenOf[root.row.entry.id] ?? const <_Resolved>[])
          if (child.itemCount > 0) _viewOf(child, locale, surface, const []),
      ];
      if (root.itemCount == 0 && children.isEmpty) continue;
      views.add(_viewOf(root, locale, surface, children));
    }
    return List<MenuEntryView>.unmodifiable(views);
  }

  MenuEntryView _viewOf(
    _Resolved resolved,
    String locale,
    MenuSurface surface,
    List<MenuEntryView> children,
  ) {
    final entry = resolved.row.entry;
    return MenuEntryView.resolve(
      id: entry.id,
      destination: resolved.destination,
      locale: locale,
      label: entry.label,
      labelKey: entry.labelKey,
      icon: entry.icon,
      featured: entry.featured,
      divided: entry.divided,
      // Le gabarit n'a de sens que sur l'accueil : le servir à la médiathèque
      // laisserait croire qu'une barre d'onglets a des formes.
      layout: surface == MenuSurface.home ? entry.homeLayout : null,
      offersSearch: entry.filterSearch,
      pageTitle: entry.pageTitle,
      pageDescription: entry.pageDescription,
      children: children,
      itemCount: resolved.itemCount,
    );
  }

  /// **La fenêtre de publication, évaluée à l'heure courante.**
  ///
  /// Les deux bornes sont indépendantes et facultatives ; `publishedFrom` est
  /// **incluse** (l'entrée paraît à la minute dite) et `publishedUntil`
  /// **exclusive** (elle cesse à la minute dite). Le serveur les sert brutes
  /// exprès : les appliquer là-bas ferait un fantôme — une entrée sortie de sa
  /// fenêtre quitterait le flux sans se retirer, et celle qui y **rentre** ne
  /// reviendrait jamais, son `updated_at` étant resté derrière le curseur.
  bool _inWindow(MenuEntryRow entry, DateTime instant) {
    final from = entry.publishedFrom;
    if (from != null && instant.isBefore(from.toUtc())) return false;
    final until = entry.publishedUntil;
    if (until != null && !instant.isBefore(until.toUtc())) return false;
    return true;
  }

  /// **La chaîne libre traduite en destination, ou rien.**
  ///
  /// `null` veut dire « cette version de l'application ne sait pas rendre cette
  /// entrée », et l'entrée disparaît alors **en silence**, sans repli sur une
  /// destination de substitution (décision 13 du cadrage). Une entrée « Faire un
  /// don » qui ouvrirait la liste des prêches est pire qu'une entrée absente, et
  /// le visiteur ne peut pas savoir que son application est en retard.
  ///
  /// Quatre cas rendent `null`, et chacun pour une raison qui lui est propre :
  ///
  /// - **un type inconnu** : le portail est plus récent que ce binaire ;
  /// - **`theme` et `intervenant`** : aucune collection de séries n'est
  ///   répliquée ici, et il n'existe pas d'écran d'intervenant. Ce ne sont pas
  ///   des oublis de cette tranche, ce sont des écrans qui n'existent pas ;
  /// - **une page du site autre que la médiathèque** (`accueil`, `contact`,
  ///   `themes`, `rencontres`) : la seule que ce client sache ouvrir depuis un
  ///   menu de contenu est la médiathèque, et c'est elle que porte l'entrée
  ///   indélébile du garde-fou 2 ;
  /// - **un `externe` sans adresse `http(s)`** : rien à ouvrir.
  MenuDestination? _destinationOf(MenuEntryWithContent row) {
    final entry = row.entry;
    switch (entry.destinationKind.trim().toLowerCase()) {
      case 'page':
        // `mediatheque` = le catalogue entier, famille enseignement. Ce n'est
        // pas une forme de destination à part : un « tout » est un catalogue
        // dont aucune borne n'est posée.
        if (entry.destinationPage?.trim().toLowerCase() != 'mediatheque') {
          return null;
        }
        return const MenuCatalogue(family: MenuContentFamily.teaching);
      case 'catalogue':
        final family = MenuContentFamily.of(entry.destinationFamily);
        if (family == null) return null;
        return MenuCatalogue(
          family: family,
          // Le référentiel de **sa** famille, jamais l'autre : les deux sont deux
          // collections, et rien ne garantit que leurs slugs soient disjoints.
          rubricId: family == MenuContentFamily.teaching
              ? row.teachingRubricId
              : row.gatheringRubricId,
          rubricSlug: entry.destinationRubric,
          branchSlug: entry.destinationBranch,
          search: entry.destinationSearch,
        );
      case 'externe':
        final url = entry.destinationUrl?.trim();
        if (url == null || !url.startsWith('http')) return null;
        return MenuExternalLink(url);
      default:
        return null;
    }
  }

  /// Le compte de contenus de la destination.
  ///
  /// Un **lien externe porte `1`** : son contenu est son adresse, et il n'y a
  /// aucune collection à interroger. Sans cela « pas de contenu, pas de section »
  /// l'effacerait systématiquement, ce qui serait prendre une règle écrite pour
  /// les listes et la retourner contre le seul type qui n'en est pas une.
  int _countOf(MenuEntryWithContent row, MenuDestination destination) =>
      switch (destination) {
        MenuCatalogue(:final family) => family == MenuContentFamily.teaching
            ? row.teachingCount
            : row.gatheringCount,
        MenuExternalLink() => 1,
      };
}

/// Une entrée retenue au premier passage, avec ce qu'on a déjà calculé d'elle.
class _Resolved {
  const _Resolved(this.row, this.destination, this.itemCount);

  final MenuEntryWithContent row;
  final MenuDestination destination;
  final int itemCount;
}
