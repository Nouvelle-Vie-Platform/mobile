/// **La médiathèque en pages** (#167, plan serveur
/// `docs/mediatheque-pages-plan.md`) : ce qu'un écran affiche d'une page, de
/// ses puces et de ses sections — et la **règle de composition** d'une section,
/// écrite une fois, hors de tout widget.
///
/// Les règles sont celles de l'aperçu du portail, qui font foi :
///
/// - la source effective d'une section `latest` / `popular` est le filtre de la
///   page **et** la source de la section **et** la puce choisie **et** la
///   loupe — la page borne, la section affine ;
/// - `latest` : les plus récents d'abord ; `popular` : l'ordre de `rankedIds`,
///   ou les plus récents tant qu'il est nul ; `manual` : l'ordre de
///   `manualIds`, où **seule la famille de la source compte** — les puces et la
///   loupe s'y appliquent encore, et un identifiant absent est sauté ;
/// - le plafond s'applique en dernier ; une section vide ne paraît pas.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../utils/search_terms.dart';
import 'content_view.dart';
import 'menu_entry_view.dart';

/// Les quatre gabarits (décision 3). Une clé inconnue de ce binaire se replie
/// sur la **liste** plutôt que de faire disparaître la section : le contenu
/// qu'elle désigne reste juste, seul le dessin manque — même doctrine que
/// `HomeSectionLayout.of`.
enum MediaSectionLayout {
  hero,
  carousel,
  list,
  grid;

  static MediaSectionLayout of(String raw) => switch (raw.trim()) {
        'hero' => hero,
        'carousel' => carousel,
        'grid' => grid,
        _ => list,
      };
}

/// Les trois tris (décision 2). Un tri inconnu se lit `latest` : la source
/// reste celle réglée, seul l'ordre est celui par défaut.
enum MediaSectionSort {
  latest,
  popular,
  manual;

  static MediaSectionSort of(String raw) => switch (raw.trim()) {
        'popular' => popular,
        'manual' => manual,
        _ => latest,
      };
}

/// Un filtre : rubrique, branche, recherche — trois bornes, toutes
/// facultatives, en **slugs** pour les deux premières.
@immutable
class MediaFilter {
  const MediaFilter({this.rubric, this.branch, this.search});

  final String? rubric;
  final String? branch;
  final String? search;

  /// [rubricIds] : slug → identifiant, dans le référentiel de **la famille de
  /// la section** (les deux référentiels ne garantissent pas des slugs
  /// disjoints).
  bool matches(ContentView content, Map<String, int> rubricIds) {
    final rubric = _present(this.rubric);
    if (rubric != null) {
      // Un slug inconnu du magasin ne ramène rien — jamais tout le catalogue.
      final id = rubricIds[rubric];
      if (id == null || content.teachingTypeId != id) return false;
    }
    // ponytail: le slug de branche n'est pas résoluble sur ce client
    // (`BranchTransformer` n'en sert pas) — une borne de branche ne ramène
    // donc rien, comme pour les menus. À brancher ici le jour où il descendra.
    if (_present(branch) != null) return false;
    final term = normalizeSearchTerm(search)?.toLowerCase();
    return term == null || content.title.toLowerCase().contains(term);
  }

  static String? _present(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Une puce : un libellé (déjà replié) et le filtre qu'elle compose avec chaque
/// section de sa page.
@immutable
class MediaChipView {
  const MediaChipView({
    required this.id,
    required this.label,
    this.filter = const MediaFilter(),
  });

  final int id;

  /// Chaîne vide = pas de libellé affichable, et la puce ne paraît pas.
  final String label;
  final MediaFilter filter;
}

/// Une section : source, tri, gabarit, plafond.
@immutable
class MediaSectionView {
  const MediaSectionView({
    required this.id,
    required this.layout,
    required this.sort,
    required this.family,
    this.maxItems = 10,
    this.titleKey,
    this.title = '',
    this.filter = const MediaFilter(),
    this.manualIds,
    this.rankedIds,
  });

  final int id;
  final MediaSectionLayout layout;
  final MediaSectionSort sort;

  /// La collection à lire. `null` = une famille que ce binaire ne connaît pas :
  /// la section ne ramène rien, sans repli sur l'autre famille.
  final MenuContentFamily? family;
  final int maxItems;

  /// Un mot du vocabulaire réglable, prioritaire sur [title].
  final String? titleKey;

  /// La surcharge, déjà repliée. Chaîne vide = pas de titre.
  final String title;
  final MediaFilter filter;
  final List<String>? manualIds;
  final List<String>? rankedIds;
}

/// Une page : un onglet.
@immutable
class MediaPageView {
  const MediaPageView({
    required this.id,
    this.label = '',
    this.labelKey,
    this.family,
    this.filter = const MediaFilter(),
    this.chips = const [],
    this.sections = const [],
  });

  final int id;

  /// La surcharge, déjà repliée. Chaîne vide = le libellé du dépôt porté par
  /// [labelKey] (`l10n/menu_labels.dart`).
  final String label;
  final String? labelKey;

  /// La famille du filtre de page, **brute** (facultative côté serveur).
  final String? family;
  final MediaFilter filter;
  final List<MediaChipView> chips;
  final List<MediaSectionView> sections;
}

/// Tout ce que l'écran de la médiathèque lit du magasin, hors contenus : les
/// pages dans leur ordre, et la résolution des slugs de rubrique par famille.
@immutable
class MediaLibraryLayout {
  const MediaLibraryLayout({
    this.pages = const [],
    this.teachingRubricIds = const {},
    this.gatheringRubricIds = const {},
  });

  static const MediaLibraryLayout empty = MediaLibraryLayout();

  final List<MediaPageView> pages;
  final Map<String, int> teachingRubricIds;
  final Map<String, int> gatheringRubricIds;

  Map<String, int> rubricIdsOf(MenuContentFamily family) => switch (family) {
        MenuContentFamily.teaching => teachingRubricIds,
        MenuContentFamily.gathering => gatheringRubricIds,
      };
}

/// **Ce qu'une section montre** — la fonction pure que l'écran appelle pour
/// chaque section de la page active.
///
/// [latestFirst] : les contenus de la famille de la section, les plus récents
/// d'abord (l'ordre du magasin). [chip] : le filtre de la puce choisie ;
/// [query] : la loupe.
List<C> composeSection<C extends ContentView>({
  required MediaSectionView section,
  required MediaPageView page,
  required List<C> latestFirst,
  required Map<String, int> rubricIds,
  MediaFilter? chip,
  String? query,
}) {
  final family = section.family;
  if (family == null) return const [];
  final manual = section.sort == MediaSectionSort.manual;
  // La page borne la famille aussi — sauf pour une sélection manuelle, où
  // seule la famille de la section compte.
  if (!manual &&
      page.family != null &&
      MenuContentFamily.of(page.family) != family) {
    return const [];
  }
  final filters = [
    if (!manual) page.filter,
    if (!manual) section.filter,
    if (chip != null) chip,
    MediaFilter(search: query),
  ];

  final ordered = switch (section.sort) {
    MediaSectionSort.latest => latestFirst,
    MediaSectionSort.popular => section.rankedIds == null
        ? latestFirst
        : _byIds(section.rankedIds!, latestFirst),
    MediaSectionSort.manual =>
      _byIds(section.manualIds ?? const [], latestFirst),
  };

  return List<C>.unmodifiable(
    ordered
        .where((c) => filters.every((f) => f.matches(c, rubricIds)))
        .take(math.max(section.maxItems, 0)),
  );
}

/// Les contenus de [ids], dans cet ordre ; un identifiant absent du magasin
/// est sauté sans bruit.
List<C> _byIds<C extends ContentView>(List<String> ids, List<C> contents) {
  final byId = {for (final c in contents) c.id: c};
  return [
    for (final id in ids)
      if (byId[id] case final content?) content,
  ];
}
