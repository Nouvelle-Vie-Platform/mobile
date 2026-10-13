/// **Le quiz de la semaine** — l'interface que la carte de l'accueil (M7)
/// attend du quiz (M6, en parallèle).
///
/// Branchement : M6 remplace le corps de [featuredQuizProvider] (ou le
/// réexporte depuis `quiz/` en gardant le type), avec un [FeaturedQuiz.onOpen]
/// qui ouvre directement le jeu. D'ici là, l'implémentation par défaut lit le
/// miroir `bible_quizzes` (fenêtre `featuredFrom..featuredUntil`) et ouvre le
/// raccourci `quiz` de l'accueil s'il est enregistré.
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../state/sync_providers.dart';
import '../../../../state/theme_provider.dart';
import '../../shell/bible_slots.dart';
import 'home_data.dart';

final class FeaturedQuiz {
  const FeaturedQuiz({
    required this.id,
    required this.title,
    this.ageBand,
    this.onOpen,
  });

  final int id;
  final String title;

  /// `kids | teens | adults`.
  final String? ageBand;

  /// `null` : la carte s'affiche sans geste.
  final BibleTap? onOpen;
}

/// Le quiz mis en avant aujourd'hui, ou `null` (pas de carte).
final featuredQuizProvider = StreamProvider.autoDispose<FeaturedQuiz?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final day = bibleDay(ref.watch(nowProvider)());
  final open = ref
      .watch(bibleSlotsProvider)
      .homeShortcuts
      .where((s) => s.id == 'quiz')
      .firstOrNull
      ?.onTap;
  final query = db.select(db.bibleQuizzes)
    ..where(
      (t) =>
          t.publishedAt.isNotNull() &
          t.featuredFrom.isNotNull() &
          t.featuredFrom.isSmallerOrEqualValue(day) &
          (t.featuredUntil.isNull() |
              t.featuredUntil.isBiggerOrEqualValue(day)),
    )
    ..orderBy([(t) => OrderingTerm.desc(t.featuredFrom)])
    ..limit(1);
  return query.watchSingleOrNull().map(
        (q) => q == null
            ? null
            : FeaturedQuiz(
                id: q.id,
                title: q.title,
                ageBand: q.ageBand,
                onOpen: open,
              ),
      );
});
