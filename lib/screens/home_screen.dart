import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/calendar_repository.dart';
import '../l10n/l10n_extension.dart';
import '../models/mediatheque_view.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/auth_providers.dart';
import '../state/calendar_providers.dart';
import '../state/gathering_providers.dart';
import '../state/mediatheque_providers.dart';
import '../state/menu_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/error_message.dart';
import '../utils/event_time.dart';
import '../utils/i18n_text.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_list_skeleton.dart';
import '../widgets/content_absence.dart';
import '../widgets/home/home_content_cards.dart';
import '../widgets/home/home_content_section.dart';
import '../widgets/home/home_gathering_section.dart';
import '../widgets/home/home_menu_section.dart';
import '../widgets/home/home_section_layout.dart';
import '../widgets/home/home_teaching_section.dart';
import '../widgets/home/radio_cta_pill.dart';
import '../widgets/profile_completion_banner.dart';
import '../widgets/profile_setup_sheet.dart';
import '../widgets/section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onMenuTap});

  final VoidCallback? onMenuTap;

  static const Key menuButtonKey = Key('home_menu_button');

  /// L'icône Bible de l'en-tête. Ciblée par clé et non par pictogramme : un test
  /// qui la vise doit résister à un changement d'icône.
  ///
  /// Elle a pris la place de l'ancienne icône de profil, partie **retrouver la
  /// barre du bas**. L'en-tête de l'accueil ne porte donc plus aucun geste
  /// réservé.
  static const Key bibleButtonKey = Key('home_bible_button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final bannerDismissed = ref.watch(profileBannerDismissedProvider);
    final showBanner =
        user != null && !user.profileComplete && !bannerDismissed;
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl + AppSpacing.xl;
    final headerHeight = MediaQuery.paddingOf(context).top + _headerBodyHeight;

    if (ref.watch(profileSetupPendingProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(profileSetupPendingProvider.notifier).clear();
        showProfileSetupSheet(context);
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ListView(
          padding: EdgeInsets.only(
            top: headerHeight + AppSpacing.md,
            bottom: bottomInset,
          ),
          children: [
            if (showBanner) ...[
              Padding(
                padding: AppSpacing.screenPadding,
                child: const ProfileCompletionBanner(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Padding(
              padding: AppSpacing.screenPadding,
              child: SectionHeader(
                title: context.l10n.sectionUpcoming,
                icon: Icons.calendar_month_outlined,
                actionLabel: context.l10n.actionSeeAll,
                onAction: () => context.pushNamed(AppRoute.agenda),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _UpcomingSection(),
            const _MediathequeHome(),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _WavyHeader(
            name: user?.firstName,
            height: headerHeight,
            onMenuTap: onMenuTap,
          ),
        ),
      ],
    );
  }
}

const double _headerBodyHeight = 294;

class _WavyHeader extends StatelessWidget {
  const _WavyHeader({
    required this.name,
    required this.height,
    required this.onMenuTap,
  });
  final String? name;
  final double height;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipPath(
        clipper: _HeaderWaveClipper(),
        child: DecoratedBox(
          decoration:
              const BoxDecoration(gradient: AppColors.gradientHomeHeader),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Image.asset(
                    'assets/images/home_header_church.webp',
                    fit: BoxFit.fitHeight,
                    alignment: Alignment.bottomRight,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xCC022163),
                        Color(0x73022163),
                        Color(0x8C012A72),
                      ],
                      stops: [0.30, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00ECF1FB),
                        Color(0x2EECF1FB),
                        Color(0x8CECF1FB),
                      ],
                      stops: [0.62, 0.86, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg, // Réduit pour libérer de la hauteur
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          key: HomeScreen.menuButtonKey,
                          onPressed: onMenuTap,
                          tooltip: context.l10n.drawerOpen,
                          alignment: Alignment.centerLeft,
                          icon: const Icon(Icons.menu,
                              color: Colors.white, size: 28),
                        ),
                        const _BibleIconButton(),
                      ],
                    ),
                    const SizedBox(
                        height: AppSpacing.sm), // Espacement réduit (ex-xxl)
                    Text(
                      name == null
                          ? context.l10n.homeGreetingNoName
                          : context.l10n.homeGreeting(name!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.l10n.homeBlessing,
                      style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.88)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const RadioCtaPill(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icône **Bible** dans l'en-tête de l'accueil, là où se tenait l'icône de
/// profil.
///
/// Elle ouvre `/bible` en **poussant** la route : la Bible n'est plus un onglet,
/// elle ne vit donc plus en permanence sous les autres écrans (voir
/// [BibleScreen]).
///
/// **Aucune garde, et c'est volontaire** : `/bible` appartient à la surface
/// invitée, décidée par le client. Le seul geste réservé de l'accueil est parti
/// avec l'icône de profil — c'est désormais la barre du bas qui demande un
/// compte, au moment du geste.
class _BibleIconButton extends StatelessWidget {
  const _BibleIconButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: HomeScreen.bibleButtonKey,
      icon: const Icon(Icons.menu_book_outlined, color: Colors.white, size: 28),
      // Localisé, contrairement au « Profil » en dur qu'il remplace : la clé
      // `navBible` existait déjà, et c'est la même Bible qu'on nomme.
      tooltip: context.l10n.navBible,
      onPressed: () => context.pushNamed(AppRoute.bible),
    );
  }
}

class _UpcomingSection extends ConsumerStatefulWidget {
  const _UpcomingSection();

  @override
  ConsumerState<_UpcomingSection> createState() => _UpcomingSectionState();
}

class _UpcomingSectionState extends ConsumerState<_UpcomingSection>
    with WidgetsBindingObserver {
  bool _staleRefreshRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _reload();
  }

  void _reload() {
    _staleRefreshRequested = false;
    ref.invalidate(upcomingEventsProvider);
  }

  bool _isUpcoming(ChurchEvent event, DateTime now) =>
      !event.startsAt.toUtc().isBefore(now);

  @override
  Widget build(BuildContext context) {
    return ref.watch(upcomingEventsProvider).when(
          loading: _buildSkeleton,
          error: (error, _) => _buildError(error),
          data: _buildWindow,
        );
  }

  Widget _buildSkeleton() => const AppListSkeleton(
        itemCount: 1,
        padding: AppSpacing.screenPadding,
      );

  /// **La phrase vient d'`errorStateMessage`, et plus d'un ternaire local.**
  ///
  /// Celui qui vivait ici ne nommait que `server` et rabattait **tout le reste**
  /// sur le message réseau — 401 compris. Le serveur refusant le jeton d'invité
  /// sur `GET /events`, cette section annonçait « vérifiez votre connexion
  /// internet » à des téléphones parfaitement connectés. Voir
  /// `utils/error_message.dart` pour la règle et pour les deux autres écrans qui
  /// la partagent désormais.
  Widget _buildError(Object error) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: AppErrorState(
        message: errorStateMessage(error, context.l10n),
        onRetry: _reload,
      ),
    );
  }

  Widget _buildWindow(EventWindow window) {
    final now = DateTime.now().toUtc();
    final upcoming = window.items
        .where((event) => _isUpcoming(event, now))
        .toList(growable: false);

    if (upcoming.isNotEmpty) return _ServicesList(events: upcoming);

    if (window.items.isNotEmpty && !_staleRefreshRequested) {
      _staleRefreshRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(upcomingEventsProvider);
      });
      return _buildSkeleton();
    }

    return _buildEmpty(window.horizon);
  }

  Widget _buildEmpty(DateTime? horizon) {
    final l10n = context.l10n;
    return Padding(
      padding: AppSpacing.screenPadding,
      child: AppEmptyState(
        icon: Icons.event_busy_outlined,
        title: l10n.homeUpcomingEmptyTitle,
        message: horizon == null
            ? l10n.homeUpcomingEmptyMessage
            : l10n.homeUpcomingHorizonMessage(
                formatHorizonDate(horizon, l10n.localeName),
              ),
      ),
    );
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.events});
  final List<ChurchEvent> events;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPadding,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => _UpcomingCard(
          event: events[i],
          current: i == 0,
          onTap: () => context.pushNamed(
            AppRoute.eventDetail,
            extra: events[i],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.event,
    this.current = false,
    this.onTap,
  });

  final ChurchEvent event;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final locale = context.l10n.localeName;
    final startTime = formatEventTime(event, locale, startOnly: true);
    // **Le lieu est optionnel.** `null`, vide, ou réduit à des espaces : il n'y
    // a alors rien à montrer, et la ligne de localisation — épingle comprise —
    // disparaît (voir plus bas). Une épingle devant une chaîne vide ferait
    // croire à un lieu manquant.
    final place = event.place?.trim();

    final boxColor = current ? palette.primary : palette.surfaceAlt;
    final fg = current ? Colors.white : palette.textPrimary;
    final fgMuted =
        current ? Colors.white.withValues(alpha: 0.8) : palette.textSecondary;

    return SizedBox(
      width: 270,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 78,
              color: boxColor,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formatEventMonth(event, locale),
                      style: AppTypography.caption.copyWith(color: fgMuted)),
                  Text(formatEventDay(event, locale),
                      style: AppTypography.h2.copyWith(color: fg)),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 12, color: fgMuted),
                      const SizedBox(width: 3),
                      Text(startTime,
                          style: AppTypography.caption.copyWith(
                              color: fg, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(formatEventWeekday(event, locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(pick(event.title, locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong
                            .copyWith(color: palette.textPrimary)),
                    // **Pas de lieu, pas d'icône** : le champ est optionnel, et
                    // une épingle sans texte ne dit rien.
                    if (place != null && place.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 13, color: palette.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(place,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption
                                    .copyWith(color: palette.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Les sections de l'accueil** — et la **coexistence bornée** des deux
/// mécanismes qui les décident (#82, cadrage § 14).
///
/// Deux sources peuvent peupler cet accueil, et **une seule parle à la fois** :
///
/// 1. **les entrées de menu** marquées « visible accueil », réglées sous
///    *Présentation › Menus* ;
/// 2. **les rubriques** (`teaching_types.visible_on_home` / `layout`), le
///    mécanisme d'avant.
///
/// La bascule se lit dans la **donnée**, à un seul endroit — ici : dès que le
/// menu de l'accueil porte au moins une entrée, **il fait foi et les rubriques se
/// taisent**. Tant qu'il est vide, les rubriques font foi.
///
/// **Pourquoi pas les deux ensemble** : la même rubrique serait rendue deux fois,
/// sous deux titres réglés à deux endroits — exactement la divergence que la
/// décision 12 du cadrage interdit. **Pourquoi pas un drapeau** : l'état livré
/// est le vide (`menu_seed.ts` pose `home_visible: false` sur les sept entrées
/// reprises, et `mobile_home` n'est pas une surface gardée), donc un appareil qui
/// monte de version avant que le portail n'ait rien réglé doit garder son
/// accueil ; et une bascule qui vit dans la donnée s'annule en décochant.
///
/// **Quand cela finit** : le jour où le serveur retire `visible_on_home` et
/// `layout` de `teaching_types` (la moitié serveur de cette tranche). Dès lors
/// `homeSectionsProvider` ne rend plus rien, le repli est mort, et les quatre
/// lignes qui le portent se retirent avec lui.
///
/// **Ce qui ne bascule pas** : « Dernières publications ». Ce n'est pas une
/// rubrique mais un **tri**, il n'a jamais dépendu de `visible_on_home`, et aucune
/// entrée de menu ne le décrit. Il reste, et c'est aussi le seul endroit qui
/// continue d'écarter les cultes entiers — voir `latestTeachingsProvider`.
class _MediathequeHome extends ConsumerWidget {
  const _MediathequeHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestTeachingsProvider);
    final menu = ref.watch(homeMenuProvider);
    final sections = ref.watch(homeSectionsProvider);
    final gatheringSections = ref.watch(gatheringSectionsProvider);

    if (latest.hasError ||
        menu.hasError ||
        sections.hasError ||
        gatheringSections.hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl) +
            AppSpacing.screenPadding,
        child: AppErrorState(
          message: context.l10n.stateErrorMessage,
          onRetry: () {
            ref.invalidate(latestTeachingsProvider);
            ref.invalidate(homeMenuProvider);
            ref.invalidate(homeSectionsProvider);
            ref.invalidate(gatheringSectionsProvider);
          },
        ),
      );
    }

    if (!latest.hasValue ||
        !menu.hasValue ||
        !sections.hasValue ||
        !gatheringSections.hasValue) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xl),
        child: AppListSkeleton(
          itemCount: 2,
          padding: AppSpacing.screenPadding,
        ),
      );
    }

    final teachings = latest.requireValue;
    final entries = menu.requireValue;
    final rubrics = sections.requireValue;
    final gatherings = gatheringSections.requireValue;

    // **La borne de la coexistence**, et c'est la seule ligne qui la porte.
    final menuDecides = entries.isNotEmpty;

    if (teachings.isEmpty &&
        !menuDecides &&
        rubrics.isEmpty &&
        gatherings.isEmpty) {
      return const _NotSyncedYet();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (teachings.isNotEmpty) _LatestTeachingsShelf(teachings: teachings),
        if (menuDecides)
          for (final entry in entries) HomeMenuSection(entry: entry)
        else ...[
          for (final section in rubrics) HomeTeachingSection(section: section),
          if (gatherings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: AppSpacing.screenPadding,
              child: SectionHeader(
                title: context.l10n.sectionGatherings,
                icon: Icons.celebration_outlined,
              ),
            ),
            for (final section in gatherings)
              HomeGatheringSection(section: section),
          ],
        ],
      ],
    );
  }
}

class _NotSyncedYet extends StatelessWidget {
  const _NotSyncedYet();

  @override
  Widget build(BuildContext context) {
    final height = math.max(MediaQuery.sizeOf(context).height * 0.5, 300.0);
    return SizedBox(
      height: height,
      child: const ContentAbsenceView(
        absence: ContentAbsence.notSynced,
        showBack: false,
      ),
    );
  }
}

class _LatestTeachingsShelf extends ConsumerWidget {
  const _LatestTeachingsShelf({required this.teachings});

  final List<TeachingView> teachings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: AppSpacing.screenPadding,
          child: SectionHeader(
            title: context.words.sectionLatestTeachings,
            icon: Icons.menu_book_outlined,
            actionLabel: l10n.actionSeeAll,
            onAction: () => context.pushNamed(AppRoute.media),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: kCarouselCoverSize.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.screenPadding,
            itemCount: teachings.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) => HomeCarouselCard(
              content: teachings[i],
              onTap: () => context.pushNamed(
                AppRoute.teachingDetail,
                pathParameters: {'id': teachings[i].id},
              ),
              onPlay: () => playHomeContent(context, ref, teachings[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 40)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height + 20,
        size.width,
        size.height - 60,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
