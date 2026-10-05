import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/players/status_player.dart';
import '../l10n/l10n_extension.dart';
import '../models/announcement_view.dart';
import '../router/app_router.dart';
import '../state/announcement_providers.dart';
import '../state/playback_controller.dart';
import '../state/player_providers.dart';
import '../state/session_gate.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_error_state.dart';
import '../widgets/mini_player_host.dart';
import '../widgets/status/status_background.dart';
import '../widgets/status/status_content.dart';
import '../widgets/status/status_list_sheet.dart';
import '../widgets/status/status_segmented_progress.dart';
import '../widgets/status/status_video_layer.dart';
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

  /// Le contrôleur global de lecture — celui de la radio et des
  /// enseignements. La visionneuse ne le pilote que pour **une** chose : taire
  /// ce qui joue pendant un statut à son, et le faire reprendre en sortant
  /// (#130). Retenu à l'ouverture, parce que la sortie passe aussi par
  /// [dispose], où `ref` ne se lit plus.
  late final PlaybackController _listening;

  int _index = 0;

  /// Doigt maintenu sur l'écran.
  bool _held = false;

  /// Corps du statut en cours de défilement (on ne change pas de statut pendant
  /// qu'on lit).
  bool _scrolling = false;

  /// Application au premier plan.
  bool _foreground = true;

  /// Quelque chose est ouvert **par-dessus** la visionneuse : la feuille de
  /// liste, ou le composeur. Dans les deux cas la lecture se suspend — on ne
  /// laisse pas les statuts défiler derrière un formulaire, et le son ne doit
  /// pas continuer sous un écran poussé.
  bool _overlayOpen = false;

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
    _listening = ref.read(playbackControllerProvider.notifier);
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
    // Quitter la visionneuse, c'est aussi la démonter : ce qu'un statut à son a
    // tu reprend.
    unawaited(_listening.resumeAfterStatus());
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
      widget.isActive && _foreground && !_held && !_scrolling && !_overlayOpen;

  /// La durée de repli d'un statut (§4) : celle que le transcodeur a mesurée,
  /// sinon le défaut par type. **La durée réelle du lecteur prime** dès qu'il
  /// la lit dans le média — c'est lui qui la substitue, par la même règle
  /// ([effectiveStatusDuration]).
  ///
  /// La **durée d'affichage** du statut (`durationMs`) a disparu du modèle avec
  /// la refonte : le serveur n'en sert aucune, et un champ que le back ne sert
  /// pas fabrique un écran qui marche en maquette et se vide en production.
  Duration _durationFor(AnnouncementView status) => effectiveStatusDuration(
        announcedMs: status.audio?.durationMs ?? status.video?.durationMs,
        hasMedia: status.audio != null || status.video != null,
      );

  void _loadCurrent() {
    final statuses = _statuses;
    if (statuses.isEmpty) return;
    final status = statuses[_index.clamp(0, statuses.length - 1)];
    _player.load(
      statusId: status.id,
      mediaUrl: status.video?.url ?? status.audio?.url,
      mediaKind: status.video != null
          ? StatusMediaKind.video
          : (status.audio != null ? StatusMediaKind.audio : null),
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
    _overlayOpen = true;
    _syncPlayback();
    final chosen = await showStatusListSheet(
      context,
      statuses: statuses,
      currentIndex: _index,
    );
    if (!mounted) return;
    _overlayOpen = false;
    if (chosen != null && chosen != _index) {
      // Saut direct plutôt qu'animation : d'un bout à l'autre de l'historique,
      // faire défiler toutes les pages intermédiaires n'a aucun sens.
      _pageController.jumpToPage(chosen);
    } else {
      _syncPlayback();
    }
  }

  /// Largeur à réserver à droite de l'en-tête : 48 points par bouton.
  ///
  /// Le son et la liste sont toujours là ; la composition et la modification
  /// s'ajoutent pour la poignée de membres d'un compte officiel. Une réserve
  /// figée laissait le nom du compte passer sous leurs icônes.
  double _actionsWidth({required bool compose, required bool edit}) =>
      48 * (2 + (compose ? 1 : 0) + (edit ? 1 : 0));

  /// **Publier et corriger exigent un compte**, et cet onglet n'en exige pas.
  ///
  /// L'affordance existe déjà pour les seuls membres d'un compte officiel
  /// (`canCompose`), mais cette réponse vient du **magasin local**, que la
  /// déconnexion ne vide pas : les lignes d'`official_account_memberships`
  /// laissées par la session précédente survivent, et l'invité qui suit voit donc
  /// les deux boutons. Sans `requireSession()`, l'appui sur l'un d'eux serait
  /// avalé par la garde du routeur (`/announcement/compose` est réservé) et
  /// renverrait sur l'accueil — la visionneuse disparaîtrait sans un mot. C'est
  /// le cul-de-sac le plus facile à manquer de tout l'onglet, parce qu'il ne se
  /// produit **pas** sur une installation neuve.
  ///
  /// Corollaire assumé : si la personne qui se connecte n'est pas celle qui
  /// s'était déconnectée, elle arrive dans le composeur sans droit dessus et le
  /// serveur répond 403. C'est le chemin déjà documenté (« confort d'affichage,
  /// jamais une autorisation »), traité par l'écran du composeur.
  void _requireCompose() {
    final router = ref.read(routerProvider);
    ref.requireSession(action: () => _openComposer(router));
  }

  void _requireEdit(String id) {
    final router = ref.read(routerProvider);
    // L'**identifiant** est capturé, pas le statut affiché : un identifiant est
    // une valeur, et l'écran de modification résout la ligne dans le magasin à
    // chaque build. C'est ce qui rend ce geste rejouable — capturer le statut
    // courant l'aurait figé au moment du clic, et la reprise aurait corrigé une
    // annonce que la synchronisation peut avoir retirée entre-temps.
    ref.requireSession(action: () => _openEditor(router, id));
  }

  /// **Le composeur suspend la visionneuse** : on ne rédige pas une annonce
  /// pendant que les statuts défilent derrière le formulaire.
  ///
  /// La `GoRouter` est passée en paramètre — lue au moment de l'appui, jamais au
  /// moment du rejeu. Le parcours de connexion reconstruit la pile, et
  /// `context.pushNamed` s'appuierait alors sur un `BuildContext` dont rien ne
  /// garantit la survie.
  Future<void> _openComposer(GoRouter router) => _pauseDuring(
        () => router.pushNamed<void>(AppRoute.announcementCompose),
      );

  Future<void> _openEditor(GoRouter router, String id) => _pauseDuring(
        () => router.pushNamed<void>(
          AppRoute.announcementEdit,
          pathParameters: {'id': id},
        ),
      );

  Future<void> _pauseDuring(Future<void> Function() push) async {
    _suspendViewer(true);
    await push();
    _suspendViewer(false);
  }

  /// Suspendre la visionneuse **si elle est encore là**.
  ///
  /// Les deux `mounted` ne sont pas décoratifs : après une connexion à la
  /// demande, ce geste est rejoué sur un arbre qui a été reconstruit entre-temps.
  /// Toucher `_overlayOpen` sur un `State` mort est sans effet ; appeler
  /// `_syncPlayback` sans garde toucherait un lecteur dont l'écran n'existe plus.
  void _suspendViewer(bool suspended) {
    if (!mounted) return;
    _overlayOpen = suspended;
    _syncPlayback();
  }

  /// **Le statut courant a-t-il du son ?** — un audio, ou une vidéo, qui
  /// porte le sien. Un texte ou une image n'en a pas, et n'interrompt rien.
  bool get _currentHasSound {
    final statuses = _statuses;
    if (statuses.isEmpty) return false;
    final status = statuses[_index.clamp(0, statuses.length - 1)];
    return status.audio != null || status.video != null;
  }

  /// **La cohabitation avec le lecteur principal** (#130, décision du
  /// 05/10/2026) :
  ///
  /// - un statut **à son** qui démarre met en pause la radio ou l'enseignement
  ///   qui jouait — *avant* de lancer son propre son, pour qu'aucune image ne
  ///   les fasse entendre ensemble ;
  /// - un statut **muet** (texte, image) n'interrompt rien ;
  /// - en **quittant la visionneuse** (autre onglet, ou démontage), ce qui a
  ///   été tu reprend tout seul : la radio au direct, l'enseignement à sa
  ///   position. Passer d'un statut à son à un statut muet ne fait rien
  ///   reprendre — on est toujours dans la visionneuse.
  ///
  /// Un doigt maintenu, la feuille de liste ou l'application en arrière-plan
  /// suspendent le statut sans faire reprendre le lecteur principal : ce n'est
  /// pas quitter la visionneuse.
  void _syncPlayback() {
    if (!mounted) return;
    if (_shouldPlay) {
      if (_currentHasSound) _listening.interruptForStatus();
      _player.play();
    } else {
      _player.pause();
      if (!widget.isActive) unawaited(_listening.resumeAfterStatus());
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

    // **Le premier statut se charge quand le mur arrive**, pas seulement à la
    // première image : le magasin répond de façon asynchrone, presque toujours
    // après elle, et `_loadCurrent` y trouvait une liste vide. Rien n'était
    // alors chargé ni signalé (`onVideoChanged`) avant le premier glissement —
    // ni lecture, ni bouton central estompé, ni mini-lecteur masqué (#117).
    ref.listen<AsyncValue<List<AnnouncementView>>>(announcementsProvider,
        (previous, next) {
      final had = previous?.value?.isNotEmpty ?? false;
      final has = next.value?.isNotEmpty ?? false;
      if (!had && has) _loadCurrent();
    });

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

    // **L'affordance d'écriture, et rien quand elle n'a pas lieu d'être.**
    //
    // Pour l'écrasante majorité des fidèles, `canCompose` est faux et cet onglet
    // reste une visionneuse : pas de bouton grisé, pas de menu caché, aucune
    // trace. Un chargement ou une lecture de magasin en échec valent « pas
    // d'affordance » — offrir un bouton dont on ne sait pas encore s'il a un
    // sens vaut moins que de l'ajouter une demi-seconde plus tard.
    //
    // Et c'est un **confort d'affichage, jamais une autorisation** : le serveur
    // revérifie à chaque écriture, un membre retiré du bureau arrive jusqu'au
    // composeur et y reçoit un 403, traité là-bas.
    final canCompose = ref.watch(canComposeAnnouncementProvider).value ?? false;
    // Les comptes ne se lisent que si l'affordance existe : inutile de faire
    // tourner deux requêtes de plus sur les téléphones qui ne publieront jamais.
    final myAccounts =
        canCompose ? ref.watch(composerOptionsProvider).value?.accounts : null;
    // Un compte officiel est un espace éditorial **collectif** : ce qui décide
    // n'est pas « ai-je écrit ce statut » mais « est-il signé de l'un de mes
    // comptes ». Un comité doit pouvoir se corriger.
    final canEditCurrent = current.accountId != null &&
        (myAccounts?.any((account) => account.id == current.accountId) ??
            false);

    // **Le mini-lecteur s'efface sur toute la visionneuse** (#117), qu'un
    // statut soit une image, un texte ou une vidéo : elle occupe l'écran, et la
    // carte cacherait le bas du statut. La lecture continue ; la carte revient
    // quand on quitte l'onglet, ou quand le mur se vide (cet arbre est alors
    // remplacé par l'état vide, et la demande tombe avec lui).
    return MiniPlayerShield(
      hidden: widget.isActive,
      child: GestureDetector(
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
                actionsWidth: _actionsWidth(
                  compose: canCompose,
                  edit: canEditCurrent,
                ),
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
                onCompose: canCompose ? _requireCompose : null,
                onEdit: canEditCurrent ? () => _requireEdit(current.id) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clés des deux commandes d'écriture de la visionneuse.
///
/// Ciblées par clé et non par icône : c'est **l'absence** que les tests doivent
/// pouvoir prouver pour l'immense majorité des fidèles, et une absence se
/// vérifie mal sur un pictogramme qui pourrait changer.
@visibleForTesting
const Key composeActionKey = Key('status-compose');
@visibleForTesting
const Key editActionKey = Key('status-edit');

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
    this.onCompose,
    this.onEdit,
  });

  final Color foreground;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onOpenList;

  /// Ouvre le composeur. **`null` = le bouton n'existe pas**, et c'est le cas de
  /// presque tout le monde. Pas de bouton désactivé : une commande grisée dit
  /// « ce n'est pas pour vous maintenant », alors qu'ici ce n'est pas pour eux
  /// du tout.
  final VoidCallback? onCompose;

  /// Ouvre la modification du statut affiché — `null` quand il n'est signé
  /// d'aucun de mes comptes.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          IconButton(
            key: editActionKey,
            onPressed: onEdit,
            color: foreground,
            tooltip: context.l10n.statusEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (onCompose != null)
          IconButton(
            key: composeActionKey,
            onPressed: onCompose,
            color: foreground,
            tooltip: context.l10n.composeAnnouncement,
            icon: const Icon(Icons.add_rounded),
          ),
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
    required this.actionsWidth,
    required this.onBodyScroll,
  });

  final AnnouncementView status;
  final bool isCurrent;
  final StatusPlayer player;
  final double topInset;
  final double bottomInset;
  final double actionsWidth;
  final ValueChanged<bool> onBodyScroll;

  @override
  Widget build(BuildContext context) {
    // Une vidéo montre son affiche jusqu'à sa première image, puis elle-même
    // (`StatusVideoLayer`) : verticale, elle occupe le fond ; horizontale, elle
    // est gardée entière sur le dégradé du statut. L'affiche décide encore de
    // l'encre — texte clair, rendu lisible par le voile.
    final video = status.video;
    final imageUrl = video?.poster ?? status.backgroundImageUrl;
    final foreground = StatusBackground.foregroundFor(
      status.id,
      backdrop: status.backdrop,
      imageUrl: imageUrl,
    );

    return StatusBackground(
      id: status.id,
      backdrop: status.backdrop,
      imageUrl: imageUrl,
      media: video == null
          ? null
          : StatusVideoLayer(
              statusId: status.id,
              player: player,
              isCurrent: isCurrent,
              posterUrl: imageUrl,
            ),
      child: StatusContent(
        announcement: status,
        foreground: foreground,
        topInset: topInset,
        bottomInset: bottomInset,
        actionsWidth: actionsWidth,
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
