/// **L'accueil du module Bible** (M7, #205, décision 3) — maquette
/// `ressources/Note_bible/bible/Gemini_Generated_Image_s7np0zs7np0zs7np.jpeg`
/// (« Splash & Accueil »), **mesurée** au pixel (harnais Chrome sans tête,
/// `nv-worktrees/_chantier-bible/mesure/`) : les cotes ci-dessous sont en
/// points d'un écran de 402 de large, origine en haut de l'écran.
///
/// Premier écran = la maquette : image d'en-tête sous la barre d'état, flèche,
/// titre serif, accroche fixe, recherche et quatre cartes à cheval sur le bas
/// de l'image, « Lecture du jour » (le verset du jour), « Continuer la
/// lecture ». En défilant : plan en cours (M5), passage du dimanche, quiz de
/// la semaine.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/announcement_view.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/status/status_background.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';
import '../marks/bible_marks_store.dart';
import '../personalize/personalize_routes.dart';
import '../plans/plan_logic.dart';
import '../plans/plans_providers.dart';
import '../quiz/quiz_providers.dart';
import '../quiz/quiz_screens.dart';
import '../reader/bible_reader_screen.dart';
import '../shell/bible_slots.dart';
import 'data/home_data.dart';

/// Le partage du verset du jour : le studio de partage de M4, dans la
/// version active. Surchargé en test.
final bibleVerseSharerProvider =
    Provider<void Function(WidgetRef ref, BibleLink link)>(
  (_) => (ref, link) =>
      openBibleStudio(ref, link, ref.read(activeBibleVersionProvider)),
);

/// Largeur au-delà de laquelle (iPad) l'accueil reste une colonne de
/// téléphone centrée : la maquette est un écran de téléphone.
const double bibleHomeMaxWidth = 460;

/// Les couleurs de l'accueil : relevées sur la maquette (clair), dérivées
/// du bas de l'image de nuit (sombre, `bible_home_hero_night.webp`).
final class BibleHomeColors {
  const BibleHomeColors._({
    required this.ink,
    required this.inkSoft,
    required this.heroShade,
    required this.pageTop,
    required this.pageBottom,
    required this.card,
    required this.search,
    required this.searchInk,
    required this.daily,
    required this.chevron,
    required this.button,
    required this.navBorder,
    required this.navIdle,
    required this.navActive,
    required this.heroImage,
    required this.heroWash,
  });

  final Color ink;
  final Color inkSoft;
  final Color heroShade;
  final Color pageTop;
  final Color pageBottom;
  final Color card;
  final Color search;
  final Color searchInk;
  final Color daily;
  final Color chevron;
  final Color button;
  final Color navBorder;
  final Color navIdle;
  final Color navActive;
  final String heroImage;

  /// Le lavis violet de la maquette de jour ; l'image de nuit est déjà froide.
  final Color heroWash;

  static const dailyIcon = Color(0xFFE9BB6D);

  static const light = BibleHomeColors._(
    ink: Color(0xFF14213D),
    inkSoft: Color(0xFF5A5A5C),
    heroShade: Color(0xFF252A40),
    pageTop: Color(0xFFFAEEE0),
    pageBottom: Color(0xFFFAF5EF),
    card: Color(0xFFFBF3EB),
    search: Color(0xFFEAE9E5),
    searchInk: Color(0xFF5A5A5C),
    daily: Color(0xFFEEEFEA),
    chevron: Color(0xFFA6A6A6),
    button: Color(0xFF143256),
    navBorder: Color(0xFFDBDAD8),
    navIdle: Color(0xFF8A8A8E),
    navActive: Color(0xFF143256),
    heroImage: 'assets/images/bible_home_hero.webp',
    heroWash: Color(0x1A6545AA),
  );

  static const dark = BibleHomeColors._(
    ink: Color(0xFFEDE6DA),
    inkSoft: Color(0xFFA9ABB8),
    heroShade: Color(0xFF141826),
    pageTop: Color(0xFF141826),
    pageBottom: Color(0xFF0F1220),
    card: Color(0xFF232838),
    search: Color(0xFF2A2F42),
    searchInk: Color(0xFFA9ABB8),
    daily: Color(0xFF1C2131),
    chevron: Color(0xFF6F7385),
    button: Color(0xFF2B4F86),
    navBorder: Color(0xFF262A38),
    navIdle: Color(0xFF7D8090),
    navActive: Color(0xFFEDE6DA),
    heroImage: 'assets/images/bible_home_hero_night.webp',
    heroWash: Color(0x00000000),
  );

  static BibleHomeColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

abstract final class BibleHomeKeys {
  static const header = Key('bible_home_header');
  static const back = Key('bible_home_back');
  static const verseText = Key('bible_home_verse_text');
  static const daily = Key('bible_home_daily');
  static const search = Key('bible_home_search');
  static Key shortcut(String id) => Key('bible_home_shortcut_$id');
  static const continueReading = Key('bible_home_continue');
  static const sunday = Key('bible_home_sunday');
  static Key sundayRef(int i) => Key('bible_home_sunday_ref_$i');
  static const sundayTeaching = Key('bible_home_sunday_teaching');
  static const sundayGathering = Key('bible_home_sunday_gathering');
  static const quiz = Key('bible_home_quiz');
}

// Cotes de la maquette (points, origine en haut de l'écran).
const double _heroHeight = 459;
const double _searchTop = 324;
const double _searchHeight = 48;
const double _cardsTop = 397;
const double _cardsHeight = 106;
const double _cardsGap = 11.7;
const double _sideMargin = 18;
const double _textLeft = 24;

TextStyle _atkinson(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
}) =>
    AppTypography.body.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: BibleHomeColors.of(context).ink,
      height: 1.2,
      letterSpacing: 0,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Premier écran
// ─────────────────────────────────────────────────────────────────────────────

class BibleHomeView extends ConsumerStatefulWidget {
  const BibleHomeView({super.key, this.onBack});

  /// La flèche posée sur l'image : sortir du module (fournie par la coquille).
  final VoidCallback? onBack;

  @override
  ConsumerState<BibleHomeView> createState() => _BibleHomeViewState();
}

class _BibleHomeViewState extends ConsumerState<BibleHomeView> {
  String? _openedFor;

  @override
  Widget build(BuildContext context) {
    final vod = ref.watch(verseOfDayProvider).value;
    if (vod != null && _openedFor != vod.day) {
      _openedFor = vod.day;
      unawaited(
        ref
            .read(verseOfDayEventsProvider)
            .record(vod.day, VerseOfDayEventKind.opened),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: BibleHomeKeys.header,
          height: _cardsTop + _cardsHeight,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _heroHeight,
                child: _Hero(backdrop: vod?.backdrop, day: vod?.day),
              ),
              Positioned(
                left: 3,
                top: 46,
                child: IconButton(
                  key: BibleHomeKeys.back,
                  tooltip: context.l10n.bibleBackToHome,
                  onPressed: widget.onBack ??
                      () {
                        final router = ref.read(routerProvider);
                        if (router.canPop()) {
                          router.pop();
                        } else {
                          router.goNamed(AppRoute.home);
                        }
                      },
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 21.7,
                right: _textLeft,
                top: 98.3,
                child: Text(
                  context.l10n.bibleHomeHeroTitle,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontWeight: FontWeight.w500,
                    fontSize: 32,
                    height: 1.14,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 22,
                right: 48,
                top: 192.8,
                child: Text(
                  context.l10n.bibleHomeHeroTagline,
                  style: _atkinson(context, 21).copyWith(
                    color: Colors.white,
                    height: 1.39,
                  ),
                ),
              ),
              const Positioned(
                left: _sideMargin,
                right: _sideMargin,
                top: _searchTop,
                height: _searchHeight,
                child: _SearchBar(),
              ),
              const Positioned(
                left: 14.6,
                right: 16.1,
                top: _cardsTop,
                height: _cardsHeight,
                child: _Shortcuts(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18.1, 43.8, _sideMargin, 0),
          child: Text(
            context.l10n.bibleHomeDailyTitle,
            style: _atkinson(context, 22, weight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        if (vod != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
            child: _DailyCard(vod: vod),
          ),
        const SizedBox(height: 38.2),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _sideMargin),
          child: _ContinueButton(),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.backdrop, required this.day});

  final StatusBackdrop? backdrop;
  final String? day;

  @override
  Widget build(BuildContext context) {
    final backdrop = this.backdrop;
    final day = this.day;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // L'image du jour choisie au portail, sinon le lever de soleil de
          // la maquette (cadré comme elle : le soleil à droite du titre).
          if (backdrop != null && day != null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: StatusBackground.gradientFor(day, backdrop),
              ),
            )
          else
            Image.asset(
              BibleHomeColors.of(context).heroImage,
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.06),
            ),
          // Trois voiles relevés sur la maquette (profils de couleur) : un
          // lavis violet qui refroidit l'image, un voile bleu nuit à gauche
          // derrière le texte, et un fondu progressif vers #252A40 (plein au bas
          // de l'image) qui laisse voir collines et lac sous la recherche.
          DecoratedBox(
            decoration:
                BoxDecoration(color: BibleHomeColors.of(context).heroWash),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, 0.3, 0.55],
                colors: [
                  Color(0xC0263450),
                  Color(0x70263450),
                  Color(0x00263450),
                ],
              ),
            ),
          ),
          // Le bord droit s'assombrit aussi (vignette) : le centre garde la
          // lumière du lac jusque vers 300 pt.
          Positioned(
            top: 140,
            left: 0,
            right: 0,
            bottom: 0,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.3],
                colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
              ).createShader(rect),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.72, 1],
                    colors: [Color(0x00252A40), Color(0xB3252A40)],
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.34, 0.45, 0.6, 0.75, 0.88, 0.95, 1],
                colors: [
                  for (final a in const <double>[
                    0,
                    0,
                    0.3,
                    0.55,
                    0.7,
                    0.9,
                    1,
                    1
                  ])
                    BibleHomeColors.of(context).heroShade.withValues(alpha: a),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref
        .watch(bibleSlotsProvider)
        .homeShortcuts
        .where((s) => s.id == 'search')
        .firstOrNull;
    return Material(
      color: BibleHomeColors.of(context).search,
      shape: const StadiumBorder(),
      child: InkWell(
        key: BibleHomeKeys.search,
        customBorder: const StadiumBorder(),
        onTap: search == null ? null : () => search.onTap(context, ref),
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 16),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 24,
                color: BibleHomeColors.of(context).searchInk,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  context.l10n.bibleHomeSearchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _atkinson(context, 18).copyWith(
                    color: BibleHomeColors.of(context).searchInk,
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

/// Les quatre cartes de la maquette : un compteur et un libellé, qui ouvrent
/// Plans, Défis, Quiz et l'onglet Favori.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final slots = ref.watch(bibleSlotsProvider).homeShortcuts;
    BibleTap? tapOf(String id) =>
        slots.where((s) => s.id == id).firstOrNull?.onTap;

    final plans = BuiltinPlanCode.all.length +
        (ref.watch(biblePublishedPlansProvider).value?.length ?? 0);
    final challenges = ref.watch(bibleChallengesProvider).value?.length ?? 0;
    final quizzes = ref.watch(quizzesProvider).value?.length ?? 0;
    final favorites = (ref.watch(bibleMarksProvider).value ?? const [])
        .where((m) => m.kind == BibleMarkKind.favorite)
        .length;

    final cards = [
      (
        'plans',
        Icons.event_note_outlined,
        plans,
        l.bibleHomeCardPlans,
        tapOf('plans'),
      ),
      (
        'challenges',
        Icons.emoji_events_outlined,
        challenges,
        l.bibleHomeCardChallenges,
        tapOf('challenges'),
      ),
      (
        'quiz',
        Icons.quiz_outlined,
        quizzes,
        l.bibleHomeCardQuizzes,
        tapOf('quiz'),
      ),
      (
        'favorites',
        Icons.favorite_border,
        favorites,
        l.bibleHomeCardFavorites,
        (BuildContext _, WidgetRef ref) =>
            ref.read(bibleTabRequestProvider.notifier).open('favorites'),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (id, icon, count, label, onTap)) in cards.indexed) ...[
          if (i > 0) const SizedBox(width: _cardsGap),
          Expanded(
            child: _ShortcutCard(
              key: BibleHomeKeys.shortcut(id),
              icon: icon,
              count: '$count',
              label: label,
              onTap: onTap == null ? null : () => onTap(context, ref),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A3B2A14),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: BibleHomeColors.of(context).card,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Icon(icon, size: 30, color: BibleHomeColors.of(context).ink),
              const SizedBox(height: 12),
              Text(
                count,
                maxLines: 1,
                style: _atkinson(context, 18, weight: FontWeight.w700),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _atkinson(context, 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Lecture du jour » : le verset du jour (portail, sinon la liste
/// intégrée) ; le toucher ouvre le lecteur au verset.
class _DailyCard extends ConsumerWidget {
  const _DailyCard({required this.vod});

  final VerseOfDay vod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(bibleLinkTextProvider(vod.link)).value ?? '';
    const radius = BorderRadius.all(Radius.circular(12));
    return Material(
      color: BibleHomeColors.of(context).daily,
      borderRadius: radius,
      child: InkWell(
        key: BibleHomeKeys.daily,
        borderRadius: radius,
        onTap: () => BibleReaderScreen.push(ref.read(routerProvider), vod.link),
        child: SizedBox(
          height: 97,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16.2, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: BibleHomeColors.dailyIcon,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: const Icon(
                    Icons.bookmark_border,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -5.0),
                        child: Text(
                          vod.link.labelFr,
                          maxLines: 1,
                          style: _atkinson(context, 19),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -3.0),
                        child: Text(
                          text,
                          key: BibleHomeKeys.verseText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _atkinson(context, 16).copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: BibleHomeColors.of(context).chevron,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « Continuer la lecture » : la dernière position, sinon le verset du jour.
class _ContinueButton extends ConsumerWidget {
  const _ContinueButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleReadingStateProvider).value;
    final vod = ref.watch(verseOfDayProvider).value;
    final book = bibleBook(state?.book ?? '');
    final chapter = state?.chapter;
    final BibleLink? target = book != null && chapter != null
        ? BibleLink(book.osis, chapter, from: state?.verse)
        : vod?.link;
    return SizedBox(
      height: 64,
      child: FilledButton(
        key: BibleHomeKeys.continueReading,
        style: FilledButton.styleFrom(
          backgroundColor: BibleHomeColors.of(context).button,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: EdgeInsets.zero,
        ),
        onPressed: target == null
            ? null
            : () => BibleReaderScreen.push(ref.read(routerProvider), target),
        child: Text(
          context.l10n.bibleHomeContinueTitle,
          style: _atkinson(context, 22).copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous le bouton, en défilant : passage du dimanche, quiz de la semaine
// ─────────────────────────────────────────────────────────────────────────────

/// Une carte de la suite de l'accueil, au dessin de « Lecture du jour ».
class BibleHomeCard extends StatelessWidget {
  const BibleHomeCard({
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
    const radius = BorderRadius.all(Radius.circular(12));
    return Padding(
      padding: const EdgeInsets.fromLTRB(_sideMargin, 0, _sideMargin, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _atkinson(context, 22, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Material(
            color: BibleHomeColors.of(context).daily,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 44,
                      decoration: BoxDecoration(
                        color: BibleHomeColors.of(context).button,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Icon(icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 15),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BibleSundayPassageSection extends ConsumerWidget {
  const BibleSundayPassageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passage = ref.watch(sundayPassageProvider).value;
    if (passage == null) return const SizedBox.shrink();
    final l = context.l10n;
    final router = ref.read(routerProvider);
    final day = DateTime.tryParse(passage.day);
    final teaching = passage.teachingId;
    final gathering = passage.gatheringId;
    return BibleHomeCard(
      key: BibleHomeKeys.sunday,
      icon: Icons.church_outlined,
      title: l.bibleHomeSundayTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (passage.title case final title?)
            Text(title, style: _atkinson(context, 19)),
          if (day != null)
            Text(
              MaterialLocalizations.of(context).formatMediumDate(day),
              style: _atkinson(context, 14)
                  .copyWith(color: BibleHomeColors.of(context).searchInk),
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

class BibleFeaturedQuizSection extends ConsumerWidget {
  const BibleFeaturedQuizSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le quiz de la semaine de M6 (filtré par le profil d'âge) ; le toucher
    // ouvre directement le jeu.
    final quiz = ref.watch(featuredQuizProvider);
    if (quiz == null) return const SizedBox.shrink();
    return BibleHomeCard(
      key: BibleHomeKeys.quiz,
      icon: Icons.quiz_outlined,
      title: context.l10n.bibleHomeQuizTitle,
      onTap: () => QuizListScreen.play(ref, quiz),
      child: Row(
        children: [
          Expanded(child: Text(quiz.title, style: _atkinson(context, 19))),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: BibleHomeColors.of(context).chevron,
          ),
        ],
      ),
    );
  }
}

/// Le fond crème de l'accueil, relevé sur la maquette.
class BibleHomeBackground extends StatelessWidget {
  const BibleHomeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BibleHomeColors.of(context).pageTop,
            BibleHomeColors.of(context).pageBottom,
          ],
          stops: [0.5, 0.9],
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width > bibleHomeMaxWidth
                ? bibleHomeMaxWidth
                : double.infinity,
          ),
          child: child,
        ),
      ),
    );
  }
}
