import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/players/status_player.dart';
import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../state/player_providers.dart';
import '../state/repository_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/status/status_background.dart';
import '../widgets/status/status_content.dart';
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
  const AnnouncementsScreen({super.key, this.isActive = true});

  /// Vrai lorsque cet onglet est celui affiché par la coquille.
  ///
  /// Indispensable : `HomeShell` monte les quatre onglets dans un
  /// `IndexedStack`, donc cet écran vit en permanence. Sans cette garde, les
  /// statuts défileraient en tâche de fond et le son démarrerait au lancement.
  final bool isActive;

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

  List<Announcement> get _statuses => ref.read(announcementsProvider);

  /// La lecture n'a lieu que si l'onglet est visible, l'application au premier
  /// plan, et qu'aucun geste de lecture ne la suspend.
  bool get _shouldPlay =>
      widget.isActive && _foreground && !_held && !_scrolling;

  /// Chaîne de résolution de la durée (§4) : durée du média annoncée par le
  /// back → durée d'affichage du statut → défaut par type. La durée réelle du
  /// lecteur primera d'elle-même en phase 2.
  Duration _durationFor(Announcement status) {
    final announced = status.audio?.durationMs ??
        status.video?.durationMs ??
        status.durationMs;
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
    _syncPlayback();
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
    final statuses = ref.watch(announcementsProvider);
    if (statuses.isEmpty) return const _EmptyState();

    // La coquille garde `extendBody: true` : le contenu passe derrière la barre
    // givrée, il faut donc réserver sa hauteur.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight;
    final width = MediaQuery.sizeOf(context).width;

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
              bottomInset: bottomInset,
              onBodyScroll: _setScrolling,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Une page du pager : le fond du statut et son contenu.
class _StatusPage extends StatelessWidget {
  const _StatusPage({
    required this.status,
    required this.isCurrent,
    required this.player,
    required this.bottomInset,
    required this.onBodyScroll,
  });

  final Announcement status;
  final bool isCurrent;
  final StatusPlayer player;
  final double bottomInset;
  final ValueChanged<bool> onBodyScroll;

  @override
  Widget build(BuildContext context) {
    // Une vidéo affiche son poster en phase 1 : c'est ce qui valide dès
    // maintenant la mise en page (bandes, voile) sans dépendance native.
    final imageUrl = status.video?.poster ?? status.backgroundImage;
    final foreground = StatusBackground.foregroundFor(
      status.id,
      backgroundColor: status.backgroundColor,
      imageUrl: imageUrl,
    );

    return StatusBackground(
      id: status.id,
      backgroundColor: status.backgroundColor,
      imageUrl: imageUrl,
      child: StatusContent(
        announcement: status,
        foreground: foreground,
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
