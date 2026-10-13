/// **Mon espace** (M4, mobile#202, décision 14) : série de jours, badges,
/// chapitres lus, favoris, notes, quiz joués — ce que l'appareil sait, le
/// miroir du compte en plus pour un membre (jamais pour un invité).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../state/sync_providers.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/brand_app_bar.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';

/// **Un badge** (M5 les décerne : plans, défis, séries).
final class BibleBadge {
  const BibleBadge({
    required this.id,
    required this.icon,
    required this.label,
    this.earned = true,
  });

  final String id;
  final IconData icon;
  final String Function(BuildContext context) label;
  final bool earned;
}

/// **Les badges**, remplis par M5. Vide jusque-là ; à l'assemblage, ce
/// provider rend la liste de M5.
final bibleBadgesProvider = Provider<List<BibleBadge>>((ref) => const []);

/// Les chiffres de Mon espace.
final class BibleMySpaceStats {
  const BibleMySpaceStats({
    this.streakDays = 0,
    this.chaptersRead = 0,
    this.favorites = 0,
    this.notes = 0,
    this.quizzes = 0,
  });

  final int streakDays;
  final int chaptersRead;
  final int favorites;
  final int notes;
  final int quizzes;
}

/// Lus une fois à l'ouverture de l'écran.
final bibleMySpaceStatsProvider =
    FutureProvider.autoDispose<BibleMySpaceStats>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final member = ref.watch(bibleIsMemberProvider);
  return readBibleMySpaceStats(db, member: member);
});

Future<BibleMySpaceStats> readBibleMySpaceStats(
  AppDatabase db, {
  required bool member,
}) async {
  // La série : la ligne locale d'abord, sinon (membre) le miroir.
  final local =
      await (db.select(db.localBibleReadingState)..limit(1)).getSingleOrNull();
  final synced = member && local == null
      ? await (db.select(db.bibleReadingStates)..limit(1)).getSingleOrNull()
      : null;
  final snapshot = await db.bibleDao.watchReadingState(member: member).first;
  final chapters = snapshot?.readChapters.values
          .fold<int>(0, (sum, set) => sum + set.length) ??
      0;

  // Favoris : miroir (membre) ∪ brouillons, moins les retraits en attente.
  final localMarks = await (db.select(db.localBibleMarks)
        ..where((t) => t.kind.equals('favorite')))
      .get();
  final favorites = <String>{
    if (member)
      for (final m in await (db.select(db.bibleMarks)
            ..where((t) => t.kind.equals('favorite')))
          .get())
        m.id,
    for (final m in localMarks)
      if (m.deletedAt == null) m.id,
  }..removeAll([
      for (final m in localMarks)
        if (m.deletedAt != null) m.id,
    ]);

  final quizzes = <String>{
    if (member)
      for (final q in await db.select(db.bibleQuizResults).get()) q.id,
    for (final q in await db.select(db.localBibleQuizResults).get()) q.id,
  };

  final notes = member ? (await db.notesDao.watchNotes().first).length : 0;

  return BibleMySpaceStats(
    streakDays: local?.streakDays ?? synced?.streakDays ?? 0,
    chaptersRead: chapters,
    favorites: favorites.length,
    notes: notes,
    quizzes: quizzes.length,
  );
}

class BibleMySpaceScreen extends ConsumerWidget {
  const BibleMySpaceScreen({super.key});

  static Key statKey(String id) => Key('bible_my_space_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final stats =
        ref.watch(bibleMySpaceStatsProvider).value ?? const BibleMySpaceStats();
    final badges = ref.watch(bibleBadgesProvider);
    final total = bibleChapters.length;
    return Scaffold(
      appBar: BrandAppBar(title: l.bibleM4MySpaceTitle),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          AppCard(
            child: Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 40,
                  color: context.palette.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l.bibleM4Streak(stats.streakDays),
                    key: statKey('streak'),
                    style: AppTypography.h4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.bibleM4Badges, style: AppTypography.h5),
          const SizedBox(height: AppSpacing.sm),
          if (badges.isEmpty)
            Text(l.bibleM4NoBadges)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final b in badges)
                  Chip(
                    avatar: Icon(b.icon, size: 18),
                    label: Text(b.label(context)),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          _Stat(
            id: 'chapters',
            icon: Icons.menu_book_outlined,
            label: l.bibleM4ChaptersRead(stats.chaptersRead, total),
            progress: stats.chaptersRead / total,
          ),
          _Stat(
            id: 'favorites',
            icon: Icons.favorite_border,
            label: l.bibleM4Favorites(stats.favorites),
          ),
          _Stat(
            id: 'notes',
            icon: Icons.sticky_note_2_outlined,
            label: l.bibleM4Notes(stats.notes),
          ),
          _Stat(
            id: 'quizzes',
            icon: Icons.quiz_outlined,
            label: l.bibleM4Quizzes(stats.quizzes),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.id,
    required this.icon,
    required this.label,
    this.progress,
  });

  final String id;
  final IconData icon;
  final String label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, key: BibleMySpaceScreen.statKey(id)),
      subtitle: progress == null
          ? null
          : LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
    );
  }
}
