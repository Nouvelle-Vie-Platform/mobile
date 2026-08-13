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
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/event_time.dart';
import '../utils/i18n_text.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_list_skeleton.dart';
import '../widgets/content_absence.dart';
import '../widgets/home/home_content_cards.dart';
import '../widgets/home/home_gathering_section.dart';
import '../widgets/home/home_section_layout.dart';
import '../widgets/home/home_teaching_section.dart';
import '../widgets/profile_completion_banner.dart';
import '../widgets/profile_setup_sheet.dart';
import '../widgets/section_header.dart';

/// Onglet « Accueil » : en-tête ondulé, cultes à venir, les derniers
/// enseignements, puis **les rubriques que le serveur y a placées**.
///
/// **Les trois rubriques en dur ont disparu** (#30). Elles filtraient sur un
/// enum à trois valeurs (`dimanche`, `etude`, `priere`) alors que la rubrique
/// est, côté serveur, une table éditable depuis le portail : la première
/// rubrique créée par un administrateur n'avait aucune valeur d'enum où aller,
/// et rien de ce qui est figé à l'écriture ne peut suivre un référentiel
/// administrable.
///
/// Ce qui les remplace **renverse la décision** (#32) : l'accueil ne choisit
/// plus ses sections, il rend celles du référentiel. `position` en donne
/// l'ordre, `layout` la mise en page, `visibleOnHome` la présence, `label` le
/// titre et `color` la teinte. Un administrateur crée une rubrique, la place,
/// choisit sa forme — et l'application suit, **sans livraison**.
///
/// Deux règles ne se contournent pas ici :
///
/// - **`visibleOnHome` se filtre à l'affichage, jamais au stockage.** Le
///   référentiel est répliqué **entier**, masquées comprises, et c'est ce
///   drapeau qui apprend au client qu'une rubrique a quitté l'accueil. Filtré à
///   l'écriture, il ferait disparaître l'information au lieu de la propager, et
///   la rubrique resterait à l'accueil pour toujours. Le filtre vit donc dans
///   `MediathequeDao.homeSections()`, à la lecture.
/// - **Pas d'enseignement, pas de section.** Le magasin l'applique déjà et
///   l'écran n'ajoute aucune section de son cru.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onMenuTap});

  /// Ouverture du **menu latéral**, remontée à la coquille : le tiroir se
  /// construit dans `HomeShell.build()` (c'est ce qui garde l'onglet courant en
  /// `State` local), l'accueil n'en connaît que le déclencheur.
  ///
  /// Nul lorsque l'écran est monté seul — dans les tests, par exemple. L'icône
  /// reste alors visible mais inerte : elle l'était depuis l'origine, et un
  /// `IconButton` sans `onPressed` se grise de lui-même.
  final VoidCallback? onMenuTap;

  /// Clé de l'icône du menu, pour l'ouvrir depuis les tests.
  static const Key menuButtonKey = Key('home_menu_button');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Affiche la bannière « compléter le profil » seulement si pertinente
    // (utilisateur présent, profil incomplet, bannière non fermée).
    final user = ref.watch(authProvider).user;
    final bannerDismissed = ref.watch(profileBannerDismissedProvider);
    final showBanner =
        user != null && !user.profileComplete && !bannerDismissed;
    // Dégagement pour la barre de nav givrée (sous laquelle le contenu défile) :
    // hauteur de la barre + encoche, pour que la dernière carte puisse être
    // remontée entièrement au-dessus d'elle.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl + AppSpacing.xl;
    // Hauteur de l'en-tête : il est posé PAR-DESSUS la liste (Stack) pour que
    // le contenu glisse dessous au défilement au lieu d'être coupé avant lui.
    final headerHeight = MediaQuery.paddingOf(context).top + _headerBodyHeight;

    // Nouvel utilisateur : la feuille de mise en route du profil s'ouvre
    // par-dessus l'accueil, une seule fois (le drapeau est consommé ici).
    if (ref.watch(profileSetupPendingProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(profileSetupPendingProvider.notifier).clear();
        showProfileSetupSheet(context);
      });
    }

    return Stack(
      // `expand` : sans cela le Stack se dimensionnerait sur l'en-tête et la
      // liste serait réduite à sa hauteur.
      fit: StackFit.expand,
      children: [
        // Contenu défilant : démarre sous l'en-tête et passe derrière lui.
        ListView(
          padding: EdgeInsets.only(
            top: headerHeight + AppSpacing.md,
            bottom: bottomInset,
          ),
          children: [
            // Bannière douce d'invitation à compléter le profil (masquée si
            // profil complet, absent ou fermée).
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
        // En-tête opaque posé par-dessus : le contenu disparaît derrière lui.
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

/// Hauteur du corps de l'en-tête (sous l'encoche). Fixe, car l'en-tête est
/// superposé à la liste : le décalage haut du contenu doit être connu.
const double _headerBodyHeight = 274;

/// En-tête « plein écran » au dégradé bleu→teal, découpé en vague à sa base.
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
              // Église + rayons, calés à droite. L'image est déjà fondue à
              // gauche (alpha) : elle se marie au dégradé sans raccord visible.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Image.asset(
                    'assets/images/home_header_church.webp',
                    // Hauteur de l'en-tête, ratio conservé : l'église occupe la
                    // moitié droite comme sur la maquette (pas de zoom).
                    fit: BoxFit.fitHeight,
                    alignment: Alignment.bottomRight,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              // Voile bleu : tamise la photo (trop lumineuse brute) et adoucit
              // son bord droit pour éviter la coupe nette.
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
              // Fondu vaporeux à la base : l'église se dissout dans le fond
              // du contenu au lieu d'être tranchée par la vague.
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
                  top: MediaQuery.paddingOf(context).top + AppSpacing.md,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  // Dégagement pour la vague découpée à la base.
                  bottom: AppSpacing.xxxl + AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // L'icône était **décorative depuis l'origine** : un
                        // `Icon` nu, sans `onTap`. Elle est désormais l'unique
                        // ouverture du menu latéral — le glissement horizontal
                        // y est coupé.
                        IconButton(
                          key: HomeScreen.menuButtonKey,
                          onPressed: onMenuTap,
                          tooltip: context.l10n.drawerOpen,
                          // La hauteur de l'en-tête est **fixe** (le contenu
                          // qui défile dessous s'en décale) : la cible tactile
                          // par défaut d'un `IconButton`, 48 px, la ferait
                          // déborder de 10 px. Elle s'élargit donc
                          // horizontalement, où il y a de la place, et reste
                          // calée à gauche pour que l'icône ne bouge pas d'un
                          // pixel par rapport à la maquette.
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 44, height: 28),
                          alignment: Alignment.centerLeft,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.menu,
                              color: Colors.white, size: 28),
                        ),
                        const _NotificationBell(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      name == null
                          ? context.l10n.homeGreetingNoName
                          : context.l10n.homeGreeting(name!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Barre jaune sous la salutation (accent de la maquette).
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.l10n.homeBlessing,
                      style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.88)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _LiveCtaPill(),
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

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none, color: Colors.white, size: 28),
        Positioned(
          top: -1,
          right: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pastille jaune « Regarder le direct » → écran live.
class _LiveCtaPill extends StatelessWidget {
  const _LiveCtaPill();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.live),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors, size: 18, color: AppColors.neutralDark),
            const SizedBox(width: AppSpacing.sm),
            Text(
              context.l10n.homeWatchLive,
              style: AppTypography.bodyStrong
                  .copyWith(color: AppColors.neutralDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section « À venir » de l'accueil, branchée sur [upcomingEventsProvider].
///
/// L'accueil est le **premier** écran de l'app : ses trois états asynchrones y
/// sont visibles avant tout le reste. Un échec de chargement doit donc se voir
/// comme une panne (`AppErrorState`, teinté, avec « Réessayer ») et jamais se
/// confondre avec un calendrier réellement vide (`AppEmptyState`, neutre et
/// sans action) — une section silencieusement vide ferait croire au lecteur
/// qu'aucun culte n'est prévu.
///
/// ## Le filtre « à venir » est côté serveur, l'app reste ouverte des heures
///
/// [upcomingEventsProvider] demande les occurrences à partir de
/// `DateTime.now()` **au moment de sa création**. Ce « maintenant » vieillit :
/// une app laissée ouverte, ou réveillée après une longue mise en veille,
/// afficherait des occurrences déjà commencées. Deux mécanismes, chacun avec
/// son rôle :
///
/// 1. **Rechargement au retour au premier plan** ([didChangeAppLifecycleState],
///    `resumed`) — c'est le mécanisme principal, et le seul qui puisse
///    *reconstituer* la liste : le serveur reste l'autorité sur ce qui est à
///    venir, lui seul peut annoncer la 4e occurrence qui remplace celle qui
///    vient de commencer. La mise en veille de l'écran suffit à le déclencher.
/// 2. **Borne côté client** ([_isUpcoming]) — filet de sécurité qui ne fait
///    jamais qu'*ôter* : il masque ce qui a démonstrablement commencé, sans
///    rien inventer. Il couvre l'intervalle entre la réponse et l'affichage,
///    une reconstruction sans rechargement (thème, bannière de profil…), et un
///    serveur qui rendrait une occurrence déjà entamée.
///
/// La borne seule ne suffirait pas : la section se viderait d'elle-même sans
/// jamais se remplir, et afficherait un « aucun rassemblement » **faux**. D'où
/// le garde-fou [_staleRefreshRequested] — si la borne vide entièrement une
/// fenêtre qui ne l'était pas, la donnée est périmée, pas absente : on
/// recharge une fois plutôt que de mentir. Une seule fois par session de
/// premier plan, pour qu'un serveur fautif ne fasse pas boucler l'accueil.
class _UpcomingSection extends ConsumerStatefulWidget {
  const _UpcomingSection();

  @override
  ConsumerState<_UpcomingSection> createState() => _UpcomingSectionState();
}

class _UpcomingSectionState extends ConsumerState<_UpcomingSection>
    with WidgetsBindingObserver {
  /// Un rechargement a déjà été déclenché par une donnée périmée depuis le
  /// dernier retour au premier plan. Empêche la boucle infinie que provoquerait
  /// un serveur rendant encore et toujours des occurrences passées.
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

  /// Recrée [upcomingEventsProvider] : la fenêtre repart de `maintenant`.
  void _reload() {
    _staleRefreshRequested = false;
    ref.invalidate(upcomingEventsProvider);
  }

  /// L'occurrence n'a pas encore commencé.
  ///
  /// Sélection sur `startsAt` seul, comme le repository : une occurrence
  /// commencée mais encore en cours n'est plus « à venir ».
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
        // Une seule carte fantôme : c'est la silhouette de la première
        // étiquette du carrousel, la seule entièrement visible.
        itemCount: 1,
        padding: AppSpacing.screenPadding,
      );

  Widget _buildError(Object error) {
    final l10n = context.l10n;
    // La cause est dite en langage humain, choisie sur le code du domaine —
    // jamais un `toString()` d'exception. `unauthorized` n'a pas de message
    // propre : `UnauthorizedInterceptor` a déjà purgé le token et renvoyé vers
    // `/auth`, l'accueil est démonté avant d'avoir pu s'expliquer.
    final message =
        error is CalendarException && error.code == CalendarErrorCode.server
            ? l10n.stateErrorServerMessage
            : l10n.stateErrorMessage;

    return Padding(
      padding: AppSpacing.screenPadding,
      child: AppErrorState(message: message, onRetry: _reload),
    );
  }

  Widget _buildWindow(EventWindow window) {
    final now = DateTime.now().toUtc();
    final upcoming = window.items
        .where((event) => _isUpcoming(event, now))
        .toList(growable: false);

    if (upcoming.isNotEmpty) return _ServicesList(events: upcoming);

    // Fenêtre non vide entièrement filtrée : la donnée a vieilli sous nos
    // yeux. Ce n'est pas un calendrier vide — on recharge et on montre le
    // squelette, l'annonce « aucun rassemblement » serait mensongère.
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
        // Avec un horizon, le vide est **borné** : le serveur n'affirme rien
        // au-delà de cette date, ce n'est pas « il n'y aura plus jamais rien ».
        message: horizon == null
            ? l10n.homeUpcomingEmptyMessage
            : l10n.homeUpcomingHorizonMessage(
                formatHorizonDate(horizon, l10n.localeName),
              ),
      ),
    );
  }
}

/// Carrousel horizontal des évènements à venir.
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
          // La carte tapée ouvre **son** évènement, pas l'agenda : le lecteur
          // a déjà choisi ce qu'il veut lire.
          onTap: () => context.pushNamed(
            AppRoute.eventDetail,
            extra: events[i],
          ),
        ),
      ),
    );
  }
}

/// Étiquette « à venir » : bloc date/heure (bleu) + détails (jour, intitulé,
/// temple). Largeur fixe pour laisser dépasser les étiquettes suivantes.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.event,
    this.current = false,
    this.onTap,
  });

  final ChurchEvent event;

  /// Évènement courant (du jour) : bloc date mis en avant en bleu.
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final locale = context.l10n.localeName;
    // L'étiquette est étroite : seule l'heure de début y tient. Le suffixe de
    // fuseau, lui, doit rester s'il est là — c'est ce qui la désambiguïse.
    final startTime = formatEventTime(event, locale, startOnly: true);

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
            // Bloc date/heure.
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
            // Détails : jour, intitulé, temple.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Puce du jour (fond bleu très clair), façon maquette.
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 13, color: palette.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(event.place ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption
                                  .copyWith(color: palette.textSecondary)),
                        ),
                      ],
                    ),
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

/// **Tout ce que l'accueil tire du magasin local**, en un seul bloc : les
/// derniers enseignements, puis les rubriques du référentiel dans l'ordre du
/// serveur.
///
/// Les deux flux lisent **le même magasin**, et leurs états se décident donc
/// ensemble plutôt qu'une fois par section :
///
/// - **Erreur** — un magasin qui refuse de se lire est une panne, et une seule.
///   La répéter section par section transformerait un incident en mur d'alertes.
/// - **Chargement** — tant qu'aucun des deux n'a répondu, un squelette. Il n'y a
///   rien à dire de plus, et surtout pas « il n'y a rien ».
/// - **Magasin vide** — les deux ont répondu, et ils n'ont rien. Ce n'est **ni**
///   un chargement, **ni** une erreur, **ni** une liste vide : c'est « pas
///   encore synchronisé », l'état normal d'un premier lancement. C'est la
///   variante [ContentAbsence.notSynced] qui le dit, celle qui existe déjà —
///   pas un écran d'absence de plus, et pas un `AppEmptyState`, qui est une
///   carte posée dans une liste là où une absence occupe la place entière.
///
/// Une église qui n'aurait **rien publié du tout** se lirait ici comme un
/// magasin pas encore synchronisé, et c'est assumé : de l'appareil, les deux
/// situations sont indiscernables sans interroger l'état de synchronisation, et
/// la réponse — « revenez après la prochaine synchronisation » — est la bonne
/// dans les deux cas. Le contraire ne l'est pas : annoncer « il n'y a rien »
/// à quelqu'un qui n'a simplement pas encore reçu le catalogue lui ferait
/// croire l'église muette.
///
/// ## Les rassemblements, depuis #34
///
/// La seconde famille de la médiathèque a son propre référentiel
/// (`gathering_types`), qui porte lui aussi un `visibleOnHome` : ces rubriques
/// sont **faites pour l'accueil**, et c'est ce drapeau qui le dit. Elles se
/// rendent donc ici, **après** celles de la médiathèque et sous un titre à
/// elles — jamais entrelacées : deux référentiels ont deux suites de
/// `position`, et les mêler donnerait un ordre que personne n'a voulu.
///
/// Le troisième flux entre dans la **même** décision d'états que les deux
/// autres, pour la même raison : les trois lisent le même magasin, une panne y
/// est une panne unique, et un magasin vide y est « pas encore synchronisé » et
/// non trois listes vides.
class _MediathequeHome extends ConsumerWidget {
  const _MediathequeHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestTeachingsProvider);
    final sections = ref.watch(homeSectionsProvider);
    final gatheringSections = ref.watch(gatheringSectionsProvider);

    if (latest.hasError || sections.hasError || gatheringSections.hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl) +
            AppSpacing.screenPadding,
        child: AppErrorState(
          message: context.l10n.stateErrorMessage,
          onRetry: () {
            ref.invalidate(latestTeachingsProvider);
            ref.invalidate(homeSectionsProvider);
            ref.invalidate(gatheringSectionsProvider);
          },
        ),
      );
    }

    if (!latest.hasValue || !sections.hasValue || !gatheringSections.hasValue) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xl),
        child: AppListSkeleton(
          itemCount: 2,
          padding: AppSpacing.screenPadding,
        ),
      );
    }

    final teachings = latest.requireValue;
    final rubrics = sections.requireValue;
    final gatherings = gatheringSections.requireValue;
    if (teachings.isEmpty && rubrics.isEmpty && gatherings.isEmpty) {
      return const _NotSyncedYet();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // « Derniers enseignements » n'est pas une rubrique mais un **tri** :
        // il survit au référentiel et se range avant lui. Il peut être vide
        // alors que des rubriques existent — il écarte les cultes entiers.
        if (teachings.isNotEmpty) _LatestTeachingsShelf(teachings: teachings),
        // Les rubriques, dans l'ordre du serveur. Rien n'est trié, filtré ni
        // complété ici : `homeSections()` a déjà écarté les masquées et les
        // vides, et les a rangées par `position`.
        for (final section in rubrics) HomeTeachingSection(section: section),
        // Puis les rassemblements, sous leur propre titre. Le titre n'apparaît
        // que s'il y a quelque chose sous lui : un en-tête suivi du vide est
        // pire que rien.
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
    );
  }
}

/// L'accueil au premier lancement : le magasin n'a **rien encore reçu**.
///
/// Occupe la place plutôt que de se glisser entre deux sections : une absence
/// n'est pas une carte dans une liste. Et **sans bouton de retour** — on est à
/// la racine de la navigation, il n'y a rien à dépiler, la barre d'onglets est
/// déjà la porte de sortie.
class _NotSyncedYet extends StatelessWidget {
  const _NotSyncedYet();

  @override
  Widget build(BuildContext context) {
    // La moitié basse de l'écran, jamais moins que de quoi respirer : la liste
    // qui l'accueille n'a pas de contrainte de hauteur à lui donner.
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

/// Étagère « Derniers enseignements » — **un tri, pas une rubrique**.
///
/// Elle garde l'icône et le bleu de marque du thème là où les rubriques portent
/// la teinte que le serveur leur a donnée : c'est une section de l'application,
/// pas une ligne du référentiel.
class _LatestTeachingsShelf extends StatelessWidget {
  const _LatestTeachingsShelf({required this.teachings});

  final List<TeachingView> teachings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: AppSpacing.screenPadding,
          child: SectionHeader(
            title: l10n.sectionLatestTeachings,
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
            ),
          ),
        ),
      ],
    );
  }
}

/// Découpe la base de l'en-tête en vague (courbe de Bézier).
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
