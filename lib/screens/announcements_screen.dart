import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/players/status_player.dart';
import '../l10n/l10n_extension.dart';
import '../models/announcement_view.dart';
import '../state/announcement_providers.dart';
import '../state/player_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_error_state.dart';
import '../widgets/status/status_background.dart';
import '../widgets/status/status_content.dart';
import '../widgets/status/status_list_sheet.dart';
import '../widgets/status/status_segmented_progress.dart';
import '../widgets/status/status_waveform.dart';

/// Onglet « Annonces » : visionneuse de statuts en plein écran.
///
/// L'onglet **est** la visionneuse (pas d'index en amont) : on entre sur le
/// statut le plus récent et on progresse vers les plus anciens.
///
/// Trois reconnaisseurs de gestes cohabitent, et l'ordre de composition est
/// critique : le [GestureDetector] enveloppe le [PageView] plutôt que de le
/// recouvrir. Posé par-dessus en `Stack`, il avalerait le glissement horizontal
/// du pager **et** le défilement vertical du texte long ; en parent, l'arène de
/// gestes attribue naturellement les taps au détecteur et les glissements au
/// pager ou au texte.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({
    super.key,
    this.isActive = true,
    this.onVideoChanged,
  });

  /// Vrai lorsque cet onglet est celui affiché par la coquille.
  ///
  /// Indispensable : `HomeShell` monte les quatre onglets dans un
  /// `IndexedStack`, donc cet écran vit en permanence. Sans cette garde, les
  /// statuts défileraient en tâche de fond et le son démarrerait au lancement.
  final bool isActive;

  /// Notifie la coquille que le statut courant est (ou n'est plus) une vidéo,
  /// afin qu'elle rende son FAB translucide au-dessus.
  ///
  /// Remontée par rappel plutôt que par un provider global : l'information ne
  /// concerne que la coquille, et l'onglet actif descend déjà par paramètre.
  final ValueChanged<bool>? onVideoChanged;

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late final StatusPlayer _player;

  int _index = 0;

  /// Doigt maintenu sur l'écran.
  bool _held = false;

  /// Corps du statut en cours de défilement (on ne change pas de statut pendant
  /// qu'on lit).
  bool _scrolling = false;

  /// Application au premier plan.
  bool _foreground = true;

  /// Feuille listant les statuts ouverte par-dessus la visionneuse.
  bool _sheetOpen = false;

  /// Géométrie de la barre de segments — une seule source de vérité, partagée
  /// entre la barre posée en surimpression et l'espace que le contenu doit lui
  /// réserver. Les deux partaient sinon de la même hauteur, et le trait de
  /// progression coupait le haut de l'avatar.
  static const double _progressTop = AppSpacing.sm;
  static const double _progressHeight = 3;
  static const double _contentTopInset =
      _progressTop + _progressHeight + AppSpacing.sm;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _player = ref.read(statusPlayerProvider);
    _player.addListener(_onPlayback);
    WidgetsBinding.instance.addObserver(this);
    // Le premier chargement attend la première image : `announcementsProvider`
    // n'est lisible qu'une fois l'écran monté.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCurrent();
    });
  }

  @override
  void didUpdateWidget(AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.removeListener(_onPlayback);
    // Le lecteur appartient au provider : on le suspend, on ne le libère pas.
    _player.pause();
    _pageController.dispose();
    super.dispose();
  }

  /// Les statuts **actuellement affichables**, ou la liste vide tant que le
  /// magasin n'a pas répondu.
  ///
  /// La source est désormais un `AsyncValue` : la lecture du magasin local n'est
  /// pas instantanée. Les rappels du lecteur, eux, peuvent survenir avant — d'où
  /// le repli sur le vide plutôt qu'un `requireValue` qui lèverait au premier
  /// tick reçu pendant le chargement.
  List<AnnouncementView> get _statuses =>
      ref.read(announcementsProvider).value ?? const [];

  /// La lecture n'a lieu que si l'onglet est visible, l'application au premier
  /// plan, et qu'aucun geste de lecture ne la suspend.
  bool get _shouldPlay =>
      widget.isActive && _foreground && !_held && !_scrolling && !_sheetOpen;

  /// Chaîne de résolution de la durée (§4) : durée du média annoncée par le
  /// back, sinon défaut par type. La durée réelle du lecteur primera d'elle-même
  /// en phase 2.
  ///
  /// La **durée d'affichage** du statut (`durationMs`) a disparu du modèle avec
  /// la refonte : le serveur n'en sert aucune, et un champ que le back ne sert
  /// pas fabrique un écran qui marche en maquette et se vide en production.
  Duration _durationFor(AnnouncementView status) {
    final announced = status.audio?.durationMs ?? status.video?.durationMs;
    if (announced != null) return Duration(milliseconds: announced);
    final hasMedia = status.audio != null || status.video != null;
    return hasMedia ? StatusDurations.media : StatusDurations.still;
  }

  void _loadCurrent() {
    final statuses = _statuses;
    if (statuses.isEmpty) return;
    final status = statuses[_index.clamp(0, statuses.length - 1)];
    _player.load(
      statusId: status.id,
      mediaUrl: status.audio?.url ?? status.video?.url,
      fallbackDuration: _durationFor(status),
    );
    widget.onVideoChanged?.call(status.video != null);
    _syncPlayback();
  }

  /// Ouvre la liste par-dessus la visionneuse : lecture suspendue le temps du
  /// choix, puis saut direct au statut retenu.
  Future<void> _openList() async {
    final statuses = _statuses;
    if (statuses.isEmpty) return;
    _sheetOpen = true;
    _syncPlayback();
    final chosen = await showStatusListSheet(
      context,
      statuses: statuses,
      currentIndex: _index,
    );
    if (!mounted) return;
    _sheetOpen = false;
    if (chosen != null && chosen != _index) {
      // Saut direct plutôt qu'animation : d'un bout à l'autre de l'historique,
      // faire défiler toutes les pages intermédiaires n'a aucun sens.
      _pageController.jumpToPage(chosen);
    } else {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (!mounted) return;
    if (_shouldPlay) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  /// Fin du statut courant : on enchaîne, ou on reste figé sur le dernier avec
  /// la barre pleine (pas de boucle, pas de bascule d'onglet).
  void _onPlayback() {
    if (!mounted || !_player.value.isCompleted) return;
    if (_index >= _statuses.length - 1) return;
    _goTo(_index + 1);
  }

  void _goTo(int index) {
    if (index < 0 || index >= _statuses.length || index == _index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _onTapUp(TapUpDetails details, double width) {
    // Tiers gauche : précédent. Reste de la largeur : suivant.
    if (details.localPosition.dx < width / 3) {
      _goTo(_index - 1);
    } else {
      _goTo(_index + 1);
    }
  }

  void _setHeld(bool held) {
    if (_held == held) return;
    _held = held;
    _syncPlayback();
  }

  void _setScrolling(bool scrolling) {
    if (_scrolling == scrolling) return;
    _scrolling = scrolling;
    _syncPlayback();
  }

  @override
  Widget build(BuildContext context) {
    // L'état « muet » vit dans un provider (partagé, mémorisé pour la session) ;
    // le lecteur en est seulement informé — il ne le rediffuse pas, pour ne pas
    // faire repeindre toute la visionneuse à chaque bascule.
    ref.listen<bool>(
        statusMutedProvider, (_, muted) => _player.setMuted(muted));

    // Le mur vient du magasin local : sa lecture est asynchrone, et les trois
    // états sont **distincts**. Un magasin vide au premier lancement est la
    // réponse normale — la synchronisation ne l'a pas encore rempli —, jamais
    // une panne : les confondre ferait lire « il n'y a aucune annonce » à un
    // fidèle dont la base est simplement illisible.
    return ref.watch(announcementsProvider).when(
          loading: () => const _LoadingState(),
          error: (_, __) => _ErrorState(
            onRetry: () => ref.invalidate(announcementsProvider),
          ),
          data: _buildViewer,
        );
  }

  Widget _buildViewer(List<AnnouncementView> statuses) {
    if (statuses.isEmpty) return const _EmptyState();

    // La coquille garde `extendBody: true` : le contenu passe derrière la barre
    // givrée, il faut donc réserver sa hauteur.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight;
    final width = MediaQuery.sizeOf(context).width;

    // Tout ce qui est posé en surimpression (barre de segments, actions) doit
    // adopter la couleur de texte résolue du statut affiché dessous, sinon il
    // hérite de celle du thème de l'application et disparaît sur le fond.
    final current = statuses[_index.clamp(0, statuses.length - 1)];
    final overlayColor = StatusBackground.foregroundFor(
      current.id,
      backdrop: current.backdrop,
      imageUrl: current.video?.poster ?? current.backgroundImageUrl,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _onTapUp(details, width),
      onLongPressStart: (_) => _setHeld(true),
      onLongPressEnd: (_) => _setHeld(false),
      onLongPressCancel: () => _setHeld(false),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: statuses.length,
            onPageChanged: (index) {
              setState(() => _index = index);
              _loadCurrent();
            },
            itemBuilder: (context, index) => _StatusPage(
              status: statuses[index],
              isCurrent: index == _index,
              player: _player,
              topInset: _contentTopInset,
              bottomInset: bottomInset,
              onBodyScroll: _setScrolling,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + _progressTop,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: ValueListenableBuilder<StatusPlayback>(
              valueListenable: _player,
              builder: (context, playback, _) {
                final onCurrent = playback.statusId == statuses[_index].id;
                return StatusSegmentedProgress(
                  count: statuses.length,
                  index: _index,
                  progress: onCurrent ? playback.progress : 0,
                  height: _progressHeight,
                  color: overlayColor,
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppSpacing.lg,
            right: AppSpacing.sm,
            child: _Actions(
              foreground: overlayColor,
              muted: ref.watch(statusMutedProvider),
              onToggleMute: () =>
                  ref.read(statusMutedProvider.notifier).toggle(),
              onOpenList: _openList,
            ),
          ),
        ],
      ),
    );
  }
}

/// Actions de la visionneuse : coupure du son et accès à la liste.
///
/// Elles sont posées **au-dessus** du détecteur de gestes de l'écran : un tap
/// sur un bouton est capté par le bouton (l'arène de gestes privilégie le
/// widget le plus profond) et ne fait donc pas avancer le statut.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.foreground,
    required this.muted,
    required this.onToggleMute,
    required this.onOpenList,
  });

  final Color foreground;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onToggleMute,
          color: foreground,
          tooltip: muted ? context.l10n.statusUnmute : context.l10n.statusMute,
          icon: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          ),
        ),
        IconButton(
          onPressed: onOpenList,
          color: foreground,
          tooltip: context.l10n.statusOpenList,
          icon: const Icon(Icons.format_list_bulleted_rounded),
        ),
      ],
    );
  }
}

/// Une page du pager : le fond du statut et son contenu.
class _StatusPage extends StatelessWidget {
  const _StatusPage({
    required this.status,
    required this.isCurrent,
    required this.player,
    required this.topInset,
    required this.bottomInset,
    required this.onBodyScroll,
  });

  final AnnouncementView status;
  final bool isCurrent;
  final StatusPlayer player;
  final double topInset;
  final double bottomInset;
  final ValueChanged<bool> onBodyScroll;

  @override
  Widget build(BuildContext context) {
    // Une vidéo affiche son poster en phase 1 : c'est ce qui valide dès
    // maintenant la mise en page (bandes, voile) sans dépendance native.
    final imageUrl = status.video?.poster ?? status.backgroundImageUrl;
    final foreground = StatusBackground.foregroundFor(
      status.id,
      backdrop: status.backdrop,
      imageUrl: imageUrl,
    );

    return StatusBackground(
      id: status.id,
      backdrop: status.backdrop,
      imageUrl: imageUrl,
      child: StatusContent(
        announcement: status,
        foreground: foreground,
        topInset: topInset,
        bottomInset: bottomInset,
        onBodyScroll: onBodyScroll,
        waveform: status.audio == null ? null : _waveform(foreground),
      ),
    );
  }

  Widget _waveform(Color foreground) {
    final bars = status.audio!.waveform;
    // Seule la page courante suit la position de lecture : les pages voisines,
    // préconstruites par le pager, restent à zéro.
    if (!isCurrent) {
      return StatusWaveform(
        bars: bars,
        progress: 0,
        seed: status.id,
        playedColor: foreground,
      );
    }
    return ValueListenableBuilder<StatusPlayback>(
      valueListenable: player,
      builder: (context, playback, _) => StatusWaveform(
        bars: bars,
        progress: playback.statusId == status.id ? playback.progress : 0,
        seed: status.id,
        playedColor: foreground,
      ),
    );
  }
}

/// **Chargement** : la lecture du magasin local n'est pas instantanée.
///
/// Volontairement muet — un indicateur, pas un texte. La visionneuse occupe
/// l'écran entier : y écrire « chargement » sur un fond vide donnerait une page
/// bien plus inquiétante que le fond seul, pour les quelques dizaines de
/// millisecondes que dure une lecture SQLite.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            semanticsLabel: context.l10n.stateLoading,
          ),
        ),
      );
}

/// **Échec de lecture du magasin** — une panne, jamais un mur vide.
///
/// La distinction n'est pas cosmétique : un écran vide faute de base lisible ne
/// doit pas se lire « l'église n'a rien annoncé ». `AppErrorState` est teinté et
/// porte une action ; l'état vide, lui, est neutre et n'en propose aucune.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppErrorState(onRetry: onRetry),
        ),
      );
}

/// État vide : c'est l'écran qu'un nouveau membre verra le jour où le back
/// démarre à zéro — il doit donc être dessiné, pas subi.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 56,
              color: palette.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.announcementsEmptyTitle,
              style: AppTypography.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.announcementsEmptyBody,
              style: AppTypography.body.copyWith(
                color: palette.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
