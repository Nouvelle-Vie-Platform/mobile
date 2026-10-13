/// **Les emplacements du module Bible** (M1, #199) — ce que M2 à M7
/// remplissent sans toucher à la coquille ni au lecteur.
///
/// Chaque tranche possède **son** fichier d'emplacements, créé vide par M1
/// (`home/home_slots.dart`, `marks/marks_slots.dart`, …) : elle n'édite que
/// lui, et deux tranches menées en parallèle ne se disputent aucune ligne.
/// [bibleSlotsProvider] les fusionne et les trie par `order`. Mode d'emploi
/// complet : `lib/features/bible/README.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/canon.dart';
import '../home/home_slots.dart';
import '../marks/marks_slots.dart';
import '../personalize/personalize_slots.dart';
import '../plans/plans_slots.dart';
import '../quiz/quiz_slots.dart';
import '../search/search_slots.dart';

/// Un libellé, résolu au moment de peindre (l10n ou vocabulaire).
typedef BibleLabel = String Function(BuildContext context);

/// Un geste : il reçoit le contexte et la `WidgetRef` de l'écran qui l'offre.
/// Pour naviguer : `ref.read(routerProvider)`, jamais le `BuildContext`.
typedef BibleTap = void Function(BuildContext context, WidgetRef ref);

/// **Une section de l'onglet Accueil** (M7 : verset du jour, passage du
/// dimanche, quiz de la semaine, « Continuer la lecture »…). Rendue pleine
/// largeur, dans l'ordre. Une section qui n'a rien à montrer rend
/// `SizedBox.shrink()`.
final class BibleHomeSection {
  const BibleHomeSection({
    required this.id,
    required this.order,
    required this.builder,
  });

  final String id;
  final int order;
  final WidgetBuilder builder;
}

/// **Un raccourci de l'accueil** (Plans, Défis, Quiz, Hors ligne) : posé par
/// la tranche qui possède la destination, disposé par M7.
final class BibleHomeShortcut {
  const BibleHomeShortcut({
    required this.id,
    required this.order,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String id;
  final int order;
  final IconData icon;
  final BibleLabel label;
  final BibleTap onTap;
}

/// **Une entrée de l'onglet Plus** (Plans, Quiz, Versions, Mon espace,
/// Paramètres…).
final class BibleMoreEntry {
  const BibleMoreEntry({
    required this.id,
    required this.order,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String id;
  final int order;
  final IconData icon;
  final BibleLabel label;
  final BibleTap onTap;
}

/// **Une action du menu d'un verset** (M2 : copier, favori, surligner, note,
/// partager ; M4 : écouter…). [run] reçoit la sélection — un livre, un
/// chapitre, une plage contiguë `from..to` — et la version affichée.
final class BibleVerseAction {
  const BibleVerseAction({
    required this.id,
    required this.order,
    required this.icon,
    required this.label,
    required this.run,
  });

  final String id;
  final int order;
  final IconData icon;
  final BibleLabel label;
  final void Function(
    BuildContext context,
    WidgetRef ref,
    BibleLink selection,
    String versionCode,
  ) run;
}

/// **Une puce de filtre de l'onglet Favori** (M2 : Tous, Versets, Chapitres,
/// Surlignés). La première est sélectionnée à l'ouverture ; [builder] peint la
/// liste filtrée sous les puces.
final class BibleFavoriteFilter {
  const BibleFavoriteFilter({
    required this.id,
    required this.order,
    required this.label,
    required this.builder,
  });

  final String id;
  final int order;
  final BibleLabel label;
  final WidgetBuilder builder;
}

/// **L'habillage d'un verset dans le lecteur** (M2 : fond de surlignage,
/// icônes de marge — favori, note, marque-page).
final class BibleVerseDecoration {
  const BibleVerseDecoration({this.background, this.marginIcons = const []});

  final Color? background;
  final List<IconData> marginIcons;
}

/// Rend l'habillage des versets d'un chapitre, par numéro de verset. Appelé
/// pendant le `build` de la page : il peut `ref.watch` ce qu'il lui faut.
typedef BibleChapterDecorator = Map<int, BibleVerseDecoration> Function(
  WidgetRef ref,
  String book,
  int chapter,
);

/// Les emplacements d'une tranche — ou de toutes, une fois fusionnés.
final class BibleSlots {
  const BibleSlots({
    this.homeSections = const [],
    this.homeShortcuts = const [],
    this.moreEntries = const [],
    this.verseActions = const [],
    this.favoriteFilters = const [],
    this.chapterDecorators = const [],
  });

  final List<BibleHomeSection> homeSections;
  final List<BibleHomeShortcut> homeShortcuts;
  final List<BibleMoreEntry> moreEntries;
  final List<BibleVerseAction> verseActions;
  final List<BibleFavoriteFilter> favoriteFilters;
  final List<BibleChapterDecorator> chapterDecorators;

  /// Concatène les emplacements de [parts] et trie chaque liste par `order`
  /// (stable : à ordre égal, l'ordre des tranches).
  static BibleSlots merge(List<BibleSlots> parts) {
    List<T> all<T>(List<T> Function(BibleSlots s) of, int Function(T) order) {
      final items = [for (final p in parts) ...of(p)];
      // `sort` n'est pas stable : le rang départage.
      final ranked = [for (final (i, e) in items.indexed) (i, e)]..sort(
          (a, b) {
            final byOrder = order(a.$2).compareTo(order(b.$2));
            return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
          },
        );
      return [for (final r in ranked) r.$2];
    }

    return BibleSlots(
      homeSections: all((s) => s.homeSections, (e) => e.order),
      homeShortcuts: all((s) => s.homeShortcuts, (e) => e.order),
      moreEntries: all((s) => s.moreEntries, (e) => e.order),
      verseActions: all((s) => s.verseActions, (e) => e.order),
      favoriteFilters: all((s) => s.favoriteFilters, (e) => e.order),
      chapterDecorators: [for (final p in parts) ...p.chapterDecorators],
    );
  }
}

/// **Tous les emplacements du module**, fusionnés. Surchargeable dans un test.
final bibleSlotsProvider = Provider<BibleSlots>(
  (ref) => BibleSlots.merge([
    marksSlots,
    searchSlots,
    personalizeSlots,
    plansSlots,
    quizSlots,
    homeSlots,
  ]),
);

/// **Demander un onglet du module** (`home|bible|favorites|notes|more`) depuis
/// un onglet — la carte « Favoris » de l'accueil ouvre l'onglet Favori. La
/// coquille écoute et bascule.
final bibleTabRequestProvider =
    NotifierProvider<BibleTabRequest, String?>(BibleTabRequest.new);

class BibleTabRequest extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String tab) {
    state = null;
    state = tab;
  }
}
