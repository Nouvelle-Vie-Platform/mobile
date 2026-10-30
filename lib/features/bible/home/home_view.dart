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
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/status/status_background.dart';
import '../data/bible_providers.dart';
import '../data/canon.dart';
import '../marks/bible_marks_store.dart';
import '../personalize/personalize_routes.dart';
import '../personalize/reader_appearance.dart';
import '../plans/plan_logic.dart';
import '../plans/plans_providers.dart';
import '../quiz/quiz_providers.dart';
import '../quiz/quiz_screens.dart';
import '../reader/bible_reader_screen.dart';
import '../shell/bible_favorites_screen.dart';
import '../shell/bible_slots.dart';
import 'data/home_data.dart';

/// Le partage du verset du jour : le studio de partage de M4, dans la
/// version active. Surchargé en test.
final bibleVerseSharerProvider =
    Provider<void Function(WidgetRef ref, BibleLink link)>(
  (_) => (ref, link) =>
      openBibleStudio(ref, link, ref.read(activeBibleVersionProvider)),
);

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
    required this.bookTile,
    required this.bookTileInk,
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

  /// La case d'abréviation d'un livre (Gn, Ex…) et son encre.
  final Color bookTile;
  final Color bookTileInk;
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
    // Le bleu de l'appli, pas un bleu nuit propre au module (#265).
    button: AppColors.primary,
    navBorder: Color(0xFFDBDAD8),
    navIdle: Color(0xFF475770),
    navActive: Color(0xFF143256),
    bookTile: Color(0xFFDEE4F0),
    bookTileInk: AppColors.primary,
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
    bookTile: Color(0xFF232838),
    bookTileInk: Color(0xFFA9C0E4),
    heroImage: 'assets/images/bible_home_hero_night.webp',
    heroWash: Color(0x00000000),
  );

  static BibleHomeColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

abstract final class BibleHomeKeys {
  static const header = Key('bible_home_header');
  static const dailyTitle = Key('bible_home_daily_title');
  static const back = Key('bible_home_back');
  static const verseText = Key('bible_home_verse_text');
  static const daily = Key('bible_home_daily');
  static const dailyRead = Key('bible_home_daily_read');
  static const invitation = Key('bible_home_invitation');
  static const dailyOverline = Key('bible_home_daily_overline');
  static const search = Key('bible_home_search');
  static Key shortcut(String id) => Key('bible_home_shortcut_$id');
  static const continueReading = Key('bible_home_continue');
  static const sunday = Key('bible_home_sunday');
  static Key sundayRef(int i) => Key('bible_home_sunday_ref_$i');
  static const sundayTeaching = Key('bible_home_sunday_teaching');
  static const sundayGathering = Key('bible_home_sunday_gathering');
  static const quiz = Key('bible_home_quiz');
}

// Cotes de la maquette : un téléphone de 402 pt de large dont la barre
// d'état finit à 62 pt (iPhone 17). Elles sont rapportées à chaque appareil
// par [_Geo] : en hauteur depuis le bas de SA barre d'état, en largeur dans
// une colonne qui s'élargit jusqu'à [bibleHomeMaxColumn], et mises à
// l'échelle de cette colonne (bornée, pour qu'un petit iPhone ne déborde pas
// et qu'un iPad ne grossisse pas démesurément).
const double _mockWidth = 402;
const double _mockInset = 62;
const double _heroBottom = 459;
const double _searchTop = 324;
const double _searchHeight = 48;
const double _cardsTop = 397;
const double _cardsHeight = 106;
const double _cardsGap = 11.7;
const double _sideMargin = 18;
const double _dailyTitleGap = 43.8;

/// La colonne du contenu sur tablette ; l'image d'en-tête, elle, couvre toute
/// la largeur.
const double bibleHomeMaxColumn = 640;

/// La géométrie de l'accueil pour l'appareil courant.
final class _Geo {
  _Geo._(this.width, this.inset, this.colLeft, this.colWidth, this.k);

  factory _Geo.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // La coquille retire le haut du `MediaQuery` (l'accueil passe sous la
    // barre d'état) : la vraie hauteur de la barre se lit sur la vue.
    final view = View.maybeOf(context);
    final viewTop =
        view == null ? 0.0 : view.viewPadding.top / view.devicePixelRatio;
    final inset = viewTop < 20 ? 20.0 : viewTop;
    final col = width < bibleHomeMaxColumn ? width : bibleHomeMaxColumn;
    final k = (col / _mockWidth).clamp(0.9, 1.15).toDouble();
    return _Geo._(width, inset, (width - col) / 2, col, k);
  }

  final double width;
  final double inset;
  final double colLeft;
  final double colWidth;

  /// L'échelle de la maquette sur cet appareil.
  final double k;

  /// Une ordonnée de la maquette, rapportée sous la barre d'état.
  double y(double mock) => inset + (mock - _mockInset) * k;

  /// Une marge horizontale de la maquette, dans la colonne.
  double x(double mock) => colLeft + mock * k;

  double s(double mock) => mock * k;
}

/// Le style courant de l'accueil de la Bible.
///
/// [family] n'est à donner que pour un texte **venu d'une Bible** — le verset
/// du jour, sa référence : il y passe alors la police de l'écriture de la
/// version ouverte (`bibleTextFontFamilyProvider`). Les libellés de
/// l'application, eux, gardent la police de l'application.
TextStyle _atkinson(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  String? family,
}) =>
    AppTypography.body.copyWith(
      fontFamily: family,
      fontSize: _Geo.of(context).s(size),
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

  /// La hauteur du premier écran sur cet appareil : la coquille ne le fixe
  /// que s'il laisse de quoi défiler dessous.
  static double heightOf(BuildContext context) =>
      _Geo.of(context).y(_cardsTop + _cardsHeight);

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
    final g = _Geo.of(context);
    // Fixe dans la coquille (#265) : l'image, la recherche et les raccourcis
    // ; « Lecture du jour » et la suite défilent dessous.
    return SizedBox(
      key: BibleHomeKeys.header,
      height: g.y(_cardsTop + _cardsHeight),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: g.y(_heroBottom),
            child: _Hero(backdrop: vod?.backdrop, day: vod?.day, geo: g),
          ),
          Positioned(
            left: g.x(3),
            top: g.y(46),
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
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: g.s(22),
                color: Colors.white,
              ),
            ),
          ),
          // **Le verset du jour tient la place du titre** (30/10/2026) : c'est
          // lui qu'on vient lire, et il méritait la grande image plutôt qu'une
          // boîte en bas de page. Les deux emplacements n'ont pas bougé d'un
          // point — seul leur contenu a changé de place, et chacun garde le
          // style de l'endroit où il arrive.
          // Le surtitre se pose **au-dessus** de la référence sans la pousser :
          // sa propre place, pour que les deux emplacements de la maquette
          // restent aux cotes relevées. Absent quand il n'y a pas de verset —
          // il annoncerait alors le grand titre, ce qu'il ne fait pas.
          if (vod != null)
            Positioned(
              left: g.x(22),
              right: g.x(24),
              top: g.y(78),
              child: Text(
                context.l10n.bibleHomeDailyTitle.toUpperCase(),
                key: BibleHomeKeys.dailyOverline,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: g.s(12),
                  fontWeight: FontWeight.w700,
                  letterSpacing: g.s(1.6),
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
          Positioned(
            left: g.x(21.7),
            right: g.x(24),
            top: g.y(98.3),
            child: _HeroReference(vod: vod, geo: g),
          ),
          Positioned(
            left: g.x(22),
            right: g.x(48),
            top: g.y(192.8),
            // La largeur de la maquette (332 pt), à l'échelle : la phrase
            // se coupe au même endroit sur téléphone et sur tablette.
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: g.s(332)),
                child: _HeroVerse(vod: vod),
              ),
            ),
          ),
          Positioned(
            left: g.x(_sideMargin),
            right: g.x(_sideMargin),
            top: g.y(_searchTop),
            height: g.s(_searchHeight),
            child: const _SearchBar(),
          ),
          Positioned(
            left: g.x(14.6),
            right: g.x(16.1),
            top: g.y(_cardsTop),
            height: g.s(_cardsHeight),
            child: const _Shortcuts(),
          ),
        ],
      ),
    );
  }
}

/// **La référence du verset du jour, dans l'emplacement du grand titre.**
///
/// Elle garde la serif de la maquette — sauf quand la version ouverte s'écrit
/// avec des lettres que Playfair Display ne porte pas : « 1 Mɔse » y
/// deviendrait un carré vide, et un titre illisible vaut moins qu'un titre
/// dans une autre police.
///
/// Sans verset du jour, l'ancien titre reprend sa place : l'en-tête ne reste
/// jamais vide.
class _HeroReference extends ConsumerWidget {
  const _HeroReference({required this.vod, required this.geo});

  final VerseOfDay? vod;
  final _Geo geo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vod = this.vod;
    final serif = TextStyle(
      fontFamily: 'Playfair Display',
      fontWeight: FontWeight.w500,
      fontSize: geo.s(32),
      height: 1.14,
      color: Colors.white,
    );
    if (vod == null) {
      return Text(context.l10n.bibleHomeHeroTitle, style: serif);
    }
    final langue = ref.watch(bibleBookLanguageProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            vod.link.labelIn(langue),
            key: BibleHomeKeys.daily,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: needsScriptFont(langue)
                ? serif.copyWith(fontFamily: kScriptFontFamily)
                : serif,
          ),
        ),
        SizedBox(width: geo.s(12)),
        _ReadBadge(link: vod.link, geo: geo),
      ],
    );
  }
}

/// Le badge « Lire », à côté de la référence : le geste qu'on venait faire.
class _ReadBadge extends ConsumerWidget {
  const _ReadBadge({required this.link, required this.geo});

  final BibleLink link;
  final _Geo geo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.all(Radius.circular(geo.s(20)));
    // **Blanc plein, encre sombre** : l'image du jour vient du portail et peut
    // être claire — un lever de soleil l'a prouvé sur l'émulateur, où un badge
    // translucide devenait illisible. C'est aussi la pastille de « New Life
    // Radio » sur l'accueil de l'église : un bouton posé sur une photo s'y
    // dessine déjà ainsi.
    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        key: BibleHomeKeys.dailyRead,
        borderRadius: radius,
        onTap: () => BibleReaderScreen.push(ref.read(routerProvider), link),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: geo.s(14),
            vertical: geo.s(6),
          ),
          child: Text(
            context.l10n.biblePlansRead,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: geo.s(14),
              fontWeight: FontWeight.w700,
              // `button` et non `ink` : en thème sombre l'encre de page est
              // claire, et elle disparaîtrait sur la pastille blanche.
              color: BibleHomeColors.of(context).button,
            ),
          ),
        ),
      ),
    );
  }
}

/// **Le verset lui-même, dans l'emplacement de la phrase d'accroche.**
class _HeroVerse extends ConsumerWidget {
  const _HeroVerse({required this.vod});

  final VerseOfDay? vod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vod = this.vod;
    final style = _atkinson(
      context,
      21,
      family: vod == null ? null : ref.watch(bibleTextFontFamilyProvider),
    ).copyWith(color: Colors.white, height: 1.39);
    if (vod == null) {
      return Text(context.l10n.bibleHomeHeroTagline, style: style);
    }
    return Text(
      ref.watch(bibleLinkTextProvider(vod.link)).value ?? '',
      key: BibleHomeKeys.verseText,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Le rapport hauteur / largeur des deux images d'en-tête (1206 × 2161).
const double _heroImageRatio = 2161 / 1206;

/// La hauteur du soleil (jour) et de la lune (nuit) dans l'image : 36 %.
const double _heroLightAt = 0.36;

class _Hero extends StatelessWidget {
  const _Hero({required this.backdrop, required this.day, required this.geo});

  final StatusBackdrop? backdrop;
  final String? day;
  final _Geo geo;

  /// Cadre l'image (« cover ») pour que le soleil ou la lune tombe à la
  /// hauteur de la maquette (122 pt), quelle que soit la forme de l'écran.
  Alignment _alignment(double width, double height) {
    final imageHeight = width * _heroImageRatio;
    if (imageHeight <= height) return Alignment.center;
    final above = _heroLightAt * imageHeight - geo.y(122);
    final a = 2 * above / (imageHeight - height) - 1;
    return Alignment(0, a.clamp(-1.0, 1.0));
  }

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
            LayoutBuilder(
              builder: (context, box) => Image.asset(
                BibleHomeColors.of(context).heroImage,
                fit: BoxFit.cover,
                alignment: _alignment(box.maxWidth, box.maxHeight),
              ),
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
            top: geo.y(140),
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
          padding: EdgeInsets.only(
            left: _Geo.of(context).s(15),
            right: _Geo.of(context).s(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: _Geo.of(context).s(24),
                color: BibleHomeColors.of(context).searchInk,
              ),
              SizedBox(width: _Geo.of(context).s(13)),
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
/// Plans, Défis, Quiz et l'écran Favoris.
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
        (BuildContext _, WidgetRef ref) => BibleFavoritesScreen.open(ref),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (id, icon, count, label, onTap)) in cards.indexed) ...[
          if (i > 0) SizedBox(width: _Geo.of(context).s(_cardsGap)),
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
              SizedBox(height: _Geo.of(context).s(16)),
              Icon(
                icon,
                size: _Geo.of(context).s(30),
                color: BibleHomeColors.of(context).ink,
              ),
              SizedBox(height: _Geo.of(context).s(12)),
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

/// **La première section sous l'en-tête fixe** (#265) — elle défile avec la
/// suite.
///
/// Depuis le 30/10/2026 elle porte « La Parole au quotidien » et sa phrase,
/// qui ont cédé la grande image au verset du jour. **Et elle n'a plus de
/// boîte** : une invitation n'est pas un contenu qu'on ouvre, l'encadrer la
/// faisait passer pour une carte à toucher.
class BibleDailySection extends ConsumerWidget {
  const BibleDailySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = _Geo.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            g.s(18.1),
            g.s(_dailyTitleGap),
            g.s(_sideMargin),
            0,
          ),
          child: Text(
            // Le saut de ligne de la maquette appartient au grand titre, pas
            // à un intitulé de section : il se lit sur une ligne ici.
            context.l10n.bibleHomeHeroTitle.replaceAll('\n', ' '),
            key: BibleHomeKeys.dailyTitle,
            style: _atkinson(context, 22, weight: FontWeight.w700),
          ),
        ),
        SizedBox(height: g.s(10)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: g.s(_sideMargin)),
          child: Text(
            context.l10n.bibleHomeHeroTagline,
            key: BibleHomeKeys.invitation,
            style: _atkinson(context, 16).copyWith(height: 1.4),
          ),
        ),
        SizedBox(height: g.s(38.2)),
      ],
    );
  }
}

/// « Continuer la lecture » : la dernière position, sinon le verset du jour.
class BibleContinueSection extends ConsumerWidget {
  const BibleContinueSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bibleReadingStateProvider).value;
    final vod = ref.watch(verseOfDayProvider).value;
    final book = bibleBook(state?.book ?? '');
    final chapter = state?.chapter;
    final BibleLink? target = book != null && chapter != null
        ? BibleLink(book.osis, chapter, from: state?.verse)
        : vod?.link;
    final g = _Geo.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: g.s(_sideMargin)),
      child: SizedBox(
        width: double.infinity,
        height: g.s(64),
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
                  label:
                      Text(link.labelIn(ref.watch(bibleBookLanguageProvider))),
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
      onTap: () => QuizEntry.play(ref, quiz),
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
      child: child,
    );
  }
}

/// Une section de l'accueil sous le premier écran (plan en cours, passage du
/// dimanche, quiz de la semaine), centrée dans la colonne du contenu.
class BibleHomeColumn extends StatelessWidget {
  const BibleHomeColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: bibleHomeMaxColumn),
          child: child,
        ),
      );
}
