/// **L'accueil du module Bible** (M7, #205, décision 3) — maquette « Splash &
/// Accueil » : l'en-tête « La Parole au quotidien » et le verset du jour, puis
/// la recherche, les raccourcis des autres tranches, « Continuer la lecture »,
/// le passage du dimanche et le quiz de la semaine. Au-delà de 700 px (iPad),
/// le corps passe sur deux colonnes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../state/sync_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/status/status_background.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';
import '../reader/bible_reader_screen.dart';
import '../shell/bible_slots.dart';
import 'data/featured_quiz.dart';
import 'data/home_data.dart';

/// Le partage du texte d'un verset (feuille du système). Surchargé en test.
final bibleVerseSharerProvider = Provider<Future<void> Function(String text)>(
  (ref) => (text) => SharePlus.instance.share(ShareParams(text: text)),
);

/// Largeur à partir de laquelle le corps passe sur deux colonnes.
const double bibleHomeTwoColumnsFrom = 700;

abstract final class BibleHomeKeys {
  static const header = Key('bible_home_header');
  static const verseText = Key('bible_home_verse_text');
  static const favorite = Key('bible_home_favorite');
  static const share = Key('bible_home_share');
  static const read = Key('bible_home_read');
  static const search = Key('bible_home_search');
  static Key shortcut(String id) => Key('bible_home_shortcut_$id');
  static const continueReading = Key('bible_home_continue');
  static const sunday = Key('bible_home_sunday');
  static Key sundayRef(int i) => Key('bible_home_sunday_ref_$i');
  static const sundayTeaching = Key('bible_home_sunday_teaching');
  static const sundayGathering = Key('bible_home_sunday_gathering');
  static const quiz = Key('bible_home_quiz');
  static const twoColumns = Key('bible_home_two_columns');
}

// ─────────────────────────────────────────────────────────────────────────────
// En-tête : image du jour et verset du jour
// ─────────────────────────────────────────────────────────────────────────────

class BibleHomeHeader extends ConsumerStatefulWidget {
  const BibleHomeHeader({super.key});

  @override
  ConsumerState<BibleHomeHeader> createState() => _BibleHomeHeaderState();
}

class _BibleHomeHeaderState extends ConsumerState<BibleHomeHeader> {
  String? _openedFor;

  void _count(String day, VerseOfDayEventKind kind) =>
      unawaited(ref.read(verseOfDayEventsProvider).record(day, kind));

  @override
  Widget build(BuildContext context) {
    final vod = ref.watch(verseOfDayProvider).value;
    if (vod == null) return const SizedBox(height: 280);
    if (_openedFor != vod.day) {
      _openedFor = vod.day;
      _count(vod.day, VerseOfDayEventKind.opened);
    }
    final l = context.l10n;
    final text = ref.watch(bibleLinkTextProvider(vod.link)).value ?? '';
    final favorite =
        ref.watch(bibleIsFavoriteProvider(vod.link)).value ?? false;
    final backdrop = vod.backdrop;
    final ink = backdrop == null
        ? AppColors.textOnPrimary
        : StatusBackground.foregroundFor(vod.day, backdrop: backdrop);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.bibleHomeHeroTitle,
            style: AppTypography.h2.copyWith(color: ink),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            text.isEmpty ? '' : '« $text »',
            key: BibleHomeKeys.verseText,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyLarge.copyWith(color: ink),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            vod.link.labelFr,
            style: AppTypography.bodyStrong.copyWith(color: ink),
          ),
          if (vod.comment case final comment?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              comment,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: ink.withValues(alpha: 0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          IconTheme(
            data: IconThemeData(color: ink),
            child: Row(
              children: [
                IconButton(
                  key: BibleHomeKeys.favorite,
                  tooltip:
                      favorite ? l.bibleHomeFavorited : l.bibleHomeFavorite,
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                  onPressed: favorite
                      ? null
                      : () async {
                          await addBibleFavorite(
                            ref.read(appDatabaseProvider),
                            vod.link,
                          );
                          _count(vod.day, VerseOfDayEventKind.favorited);
                        },
                  disabledColor: ink,
                ),
                IconButton(
                  key: BibleHomeKeys.share,
                  tooltip: l.bibleHomeShare,
                  icon: const Icon(Icons.ios_share),
                  onPressed: text.isEmpty
                      ? null
                      : () {
                          _count(vod.day, VerseOfDayEventKind.shared);
                          ref.read(bibleVerseSharerProvider)(
                            '« $text »\n— ${vod.link.labelFr}',
                          );
                        },
                ),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      key: BibleHomeKeys.read,
                      style: TextButton.styleFrom(foregroundColor: ink),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(
                        l.bibleHomeReadChapter,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => BibleReaderScreen.push(
                        ref.read(routerProvider),
                        vod.link,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: l.bibleHomeVerseOfDay,
      child: ConstrainedBox(
        key: BibleHomeKeys.header,
        constraints: const BoxConstraints(minHeight: 280),
        child: Stack(
          children: [
            Positioned.fill(
              child: backdrop != null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient:
                            StatusBackground.gradientFor(vod.day, backdrop),
                      ),
                    )
                  : Image.asset(
                      'assets/images/home_header_church.webp',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppColors.gradientPrimary),
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: StatusBackground.scrimGradient(ink),
                ),
              ),
            ),
            content,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Corps : recherche, raccourcis, lecture, dimanche, quiz
// ─────────────────────────────────────────────────────────────────────────────

class BibleHomeBody extends ConsumerWidget {
  const BibleHomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortcuts = ref.watch(bibleSlotsProvider).homeShortcuts;
    final search = shortcuts.where((s) => s.id == 'search').firstOrNull;
    final first = <Widget>[
      if (search != null) _SearchBar(search),
      if (shortcuts.isNotEmpty) _Shortcuts(shortcuts),
      const _ContinueReading(),
    ];
    const second = <Widget>[_SundayPassageCard(), _FeaturedQuizCard()];

    Widget column(List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in children)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: c,
              ),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: AppSpacing.screenPadding,
        child: constraints.maxWidth >= bibleHomeTwoColumnsFrom
            ? Row(
                key: BibleHomeKeys.twoColumns,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: column(first)),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(child: column(second)),
                ],
              )
            : column([...first, ...second]),
      ),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar(this.search);

  final BibleHomeShortcut search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        key: BibleHomeKeys.search,
        customBorder: const StadiumBorder(),
        onTap: () => search.onTap(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.bibleHomeSearchHint,
                  style: AppTypography.body.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts(this.shortcuts);

  final List<BibleHomeShortcut> shortcuts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return GridView.extent(
      maxCrossAxisExtent: 96,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.95,
      children: [
        for (final s in shortcuts)
          Material(
            color: palette.surface,
            borderRadius: AppRadius.card,
            child: InkWell(
              key: BibleHomeKeys.shortcut(s.id),
              borderRadius: AppRadius.card,
              onTap: () => s.onTap(context, ref),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(s.icon, color: palette.primary),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      s.label(context),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Une carte sobre de l'accueil : titre, contenu.
class _HomeCard extends StatelessWidget {
  const _HomeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: AppRadius.card,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: palette.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueReading extends ConsumerWidget {
  const _ContinueReading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleReadingStateProvider).value;
    final book = bibleBook(state?.book ?? '');
    final chapter = state?.chapter;
    if (state == null || book == null || chapter == null) {
      return const SizedBox.shrink();
    }
    final total = book.chapterCount;
    final read = (state.readChapters[book.osis] ?? const <int>{}).length;
    final palette = context.palette;
    final l = context.l10n;
    return _HomeCard(
      key: BibleHomeKeys.continueReading,
      icon: Icons.bookmark_outline,
      title: l.bibleHomeContinueTitle,
      onTap: () => BibleReaderScreen.push(
        ref.read(routerProvider),
        BibleLink(book.osis, chapter, from: state.verse),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BibleLink(book.osis, chapter).labelFr,
            style: AppTypography.h4.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: total == 0 ? 0 : read / total,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: palette.border,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.bibleHomeBookProgress(read, total, book.name),
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SundayPassageCard extends ConsumerWidget {
  const _SundayPassageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passage = ref.watch(sundayPassageProvider).value;
    if (passage == null) return const SizedBox.shrink();
    final palette = context.palette;
    final l = context.l10n;
    final router = ref.read(routerProvider);
    final day = DateTime.tryParse(passage.day);
    final teaching = passage.teachingId;
    final gathering = passage.gatheringId;
    return _HomeCard(
      key: BibleHomeKeys.sunday,
      icon: Icons.church_outlined,
      title: l.bibleHomeSundayTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (passage.title case final title?)
            Text(
              title,
              style: AppTypography.h4.copyWith(color: palette.textPrimary),
            ),
          if (day != null)
            Text(
              MaterialLocalizations.of(context).formatMediumDate(day),
              style: AppTypography.caption.copyWith(
                color: palette.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (i, link) in passage.references.indexed)
                ActionChip(
                  key: BibleHomeKeys.sundayRef(i),
                  avatar: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(link.labelFr),
                  onPressed: () => BibleReaderScreen.push(router, link),
                ),
            ],
          ),
          if (teaching != null)
            TextButton.icon(
              key: BibleHomeKeys.sundayTeaching,
              icon: const Icon(Icons.play_circle_outline),
              label: Text(l.bibleHomeSundayTeaching),
              onPressed: () => router.pushNamed(
                AppRoute.teachingDetail,
                pathParameters: {'id': teaching},
              ),
            )
          else if (gathering != null)
            TextButton.icon(
              key: BibleHomeKeys.sundayGathering,
              icon: const Icon(Icons.event_outlined),
              label: Text(l.bibleHomeSundayGathering),
              onPressed: () => router.pushNamed(
                AppRoute.gatheringDetail,
                pathParameters: {'id': gathering},
              ),
            ),
        ],
      ),
    );
  }
}

class _FeaturedQuizCard extends ConsumerWidget {
  const _FeaturedQuizCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.watch(featuredQuizProvider).value;
    if (quiz == null) return const SizedBox.shrink();
    final palette = context.palette;
    final open = quiz.onOpen;
    return _HomeCard(
      key: BibleHomeKeys.quiz,
      icon: Icons.quiz_outlined,
      title: context.l10n.bibleHomeQuizTitle,
      onTap: open == null ? null : () => open(context, ref),
      child: Row(
        children: [
          Expanded(
            child: Text(
              quiz.title,
              style: AppTypography.h4.copyWith(color: palette.textPrimary),
            ),
          ),
          if (open != null) Icon(Icons.chevron_right, color: palette.primary),
        ],
      ),
    );
  }
}
