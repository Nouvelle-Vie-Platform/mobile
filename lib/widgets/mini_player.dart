/// **Le mini-lecteur** (#116) — ce qui joue, et de quoi le piloter, hors de la
/// fiche.
///
/// Il paraît dès que le contrôleur global tient une requête
/// (`playbackControllerProvider != null`), d'où qu'elle vienne : la fiche, une
/// carte de l'accueil, l'antenne. Il ne sait rien de l'écran qui a lancé la
/// lecture, et rien non plus de l'écran qui le porte : c'est ce qui permettra de
/// le remonter au niveau de l'application (#117) sans le réécrire.
///
/// Trois règles qui se ratent en silence :
///
/// 1. **Il commande par le contrôleur, jamais par le lecteur** — la règle de
///    #114. Sauf l'antenne, dont la ✕ et la reprise passent par
///    `RadioListening` : arrêter sans lui laisserait ses tentatives de reprise
///    rouvrir le son dans le dos de l'auditeur, et reprendre sans lui rouvrirait
///    la source avec un cookie périmé (#108).
/// 2. **La position émet plusieurs fois par seconde** : seuls [_MiniProgress] et
///    [_MainButton] s'abonnent au lecteur, par `select`, sur une valeur
///    dérivée. La ligne d'état ([_StatusLine]) s'abonne aussi par `select`, mais
///    à la panne seule — jamais à la position. La carte, l'image et le titre ne
///    se reconstruisent qu'au changement de requête.
/// 3. **Aucune ligne d'orateur sans orateur.** Jamais « Auteur inconnu » : ce
///    serait lire comme une erreur de saisie ce qui est un enseignement sans
///    orateur nommé.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/radio_config.dart';
import '../data/players/content_player.dart';
import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../state/playback_controller.dart';
import '../state/player_providers.dart';
import '../state/radio_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Le mini-lecteur flottant : une carte arrondie, ou rien.
///
/// [margin] est l'espace autour de la carte. Celui du bas dépend de qui le
/// porte — au-dessus de la barre d'onglets il doit laisser passer le bouton
/// central, qui déborde de la barre —, d'où le paramètre plutôt qu'une
/// constante.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({
    super.key,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
  });

  final EdgeInsets margin;

  static const Key cardKey = Key('mini_player');
  static const Key openKey = Key('mini_player_open');
  static const Key artworkKey = Key('mini_player_artwork');
  static const Key titleKey = Key('mini_player_title');
  static const Key authorKey = Key('mini_player_author');
  static const Key statusKey = Key('mini_player_status');
  static const Key liveBadgeKey = Key('mini_player_live');
  static const Key progressKey = Key('mini_player_progress');
  static const Key skipBackwardKey = Key('mini_player_skip_backward');
  static const Key mainButtonKey = Key('mini_player_main');
  static const Key skipForwardKey = Key('mini_player_skip_forward');
  static const Key closeKey = Key('mini_player_close');

  /// Le diamètre du gros bouton rond.
  static const double mainButtonSize = 44;

  /// Le côté de la vignette.
  static const double artworkSize = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(playbackControllerProvider);
    if (request == null) return const SizedBox.shrink();

    final palette = context.palette;
    // **L'antenne se reconnaît à deux signes**, et l'un suffit : le drapeau du
    // direct, ou l'identifiant de la radio. Le second couvre un direct qui
    // arriverait un jour sans le premier — un `/radio` qui s'ouvrirait sur un
    // enseignement serait pire qu'une barre en trop.
    final isRadio = request.contentId == RadioConfig.contentId;
    final isLive = request.isLive || isRadio;

    return Padding(
      padding: margin,
      child: DecoratedBox(
        key: cardKey,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: palette.border),
          boxShadow: AppShadows.elevation2,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                // À droite, la place de la ✕ : sans elle, le bouton « +30 s »
                // passerait sous la croix et l'un des deux gestes tomberait sur
                // l'autre.
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _OpenArea(request: request, isLive: isLive),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _Controls(request: request, isLive: isLive),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: _CloseButton(request: request),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **Ouvre l'écran complet** de ce qui joue — la fiche, ou l'antenne.
///
/// `GoRouter.maybeOf` d'abord, le routeur de l'application ensuite : posé au
/// niveau de l'application (#117), le mini-lecteur vivra **au-dessus** du
/// `Navigator`, là où aucun `GoRouter` ne se lit dans le contexte.
///
/// Pousser la fiche ne recharge rien : `ContentPlayerView` ne charge pas un
/// contenu que le lecteur tient déjà. C'est ce qui garde la place de l'auditeur.
void _openFull(BuildContext context, WidgetRef ref, ContentRequest request) {
  final router =
      GoRouter.maybeOf(context) ?? ref.read<GoRouter>(routerProvider);
  if (request.contentId == RadioConfig.contentId) {
    router.pushNamed(AppRoute.radio);
    return;
  }
  router.pushNamed(
    AppRoute.teachingDetail,
    pathParameters: {'id': request.contentId},
  );
}

/// La vignette et le texte : la zone qui ouvre l'écran complet.
class _OpenArea extends ConsumerWidget {
  const _OpenArea({required this.request, required this.isLive});

  final ContentRequest request;
  final bool isLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final author = request.author?.trim();
    final hasAuthor = author != null && author.isNotEmpty;

    return Semantics(
      button: true,
      label: context.l10n.miniPlayerOpen(request.title),
      excludeSemantics: true,
      child: InkWell(
        key: MiniPlayer.openKey,
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _openFull(context, ref, request),
        child: Row(
          children: [
            _Artwork(url: request.artUrl, isLive: isLive),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    key: MiniPlayer.titleKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  _StatusLine(
                    contentId: request.contentId,
                    isLive: isLive,
                    author: hasAuthor ? author : null,
                  ),
                  if (!isLive) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _MiniProgress(contentId: request.contentId),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La vignette carrée, et son repli coloré.
///
/// `errorBuilder` n'est pas une précaution : hors ligne l'image ne vient pas,
/// et sous `flutter test` tout accès réseau rend 400.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.url, required this.isLive});

  final String? url;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fallback = ColoredBox(
      color: palette.primary,
      child: Center(
        child: Icon(
          isLive ? Icons.radio_rounded : Icons.headphones_rounded,
          color: palette.surface,
          size: 26,
        ),
      ),
    );
    final source = url;

    return ClipRRect(
      key: MiniPlayer.artworkKey,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox.square(
        dimension: MiniPlayer.artworkSize,
        child: source == null || source.isEmpty
            ? fallback
            : Image.network(
                source,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// Ce que la ligne sous le titre a à dire.
enum _Status {
  /// Rien de particulier : l'orateur, ou le badge du direct.
  normal,

  /// Panne **après** le premier son : « Lecture interrompue » (#42).
  interrupted,

  /// Panne **avant** tout son : il faut du réseau, il n'y a rien à reprendre.
  needsNetwork;

  static _Status of(ContentPlayback playback, String contentId) {
    if (playback.contentId != contentId || !playback.hasError) return normal;
    return playback.hasStarted ? interrupted : needsNetwork;
  }
}

/// La ligne sous le titre : l'orateur, le badge du direct, ou la panne.
///
/// Abonnée par `select` à la **panne seule** — jamais à la position.
class _StatusLine extends ConsumerWidget {
  const _StatusLine({
    required this.contentId,
    required this.isLive,
    required this.author,
  });

  final String contentId;
  final bool isLive;
  final String? author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      contentPlaybackProvider.select((p) => _Status.of(p, contentId)),
    );
    final palette = context.palette;
    final l10n = context.l10n;

    final failure = switch (status) {
      _Status.normal => null,
      // Les phrases de la fiche, et pas d'autres : le fidèle doit reconnaître
      // la même panne, où qu'il la voie.
      _Status.interrupted => l10n.playerErrorTitle,
      _Status.needsNetwork => l10n.absenceOfflineMediaTitle,
    };
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          failure,
          key: MiniPlayer.statusKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(color: AppColors.danger),
        ),
      );
    }
    if (isLive) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xs),
        child: _LiveBadge(),
      );
    }
    final name = author;
    if (name == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        name,
        key: MiniPlayer.authorKey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(color: palette.textSecondary),
      ),
    );
  }
}

/// Le badge « EN DIRECT » de l'antenne.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: MiniPlayer.liveBadgeKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            context.l10n.miniPlayerLiveBadge,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1.4,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// **La barre de progression** — l'un des deux abonnés à la position.
///
/// Trois cas : la part écoulée ; **pleine** en fin de lecture ; **indéterminée**
/// quand la durée est inconnue (HLS sur iOS, `progress == null`). Une barre
/// figée au début ferait croire à une lecture bloquée.
class _MiniProgress extends ConsumerWidget {
  const _MiniProgress({required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      contentPlaybackProvider.select((p) {
        if (p.contentId != contentId) return 0.0;
        if (p.isCompleted) return 1.0;
        return p.progress;
      }),
    );
    final palette = context.palette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        key: MiniPlayer.progressKey,
        value: progress,
        minHeight: 3,
        color: palette.primary,
        backgroundColor: palette.border,
      ),
    );
  }
}

/// Les commandes : −30 s, le gros bouton, +30 s — ou le gros bouton seul, sur
/// un direct.
class _Controls extends ConsumerWidget {
  const _Controls({required this.request, required this.isLive});

  final ContentRequest request;
  final bool isLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final l10n = context.l10n;
    final controller = ref.read(playbackControllerProvider.notifier);

    if (isLive) return _MainButton(request: request, isLive: true);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SkipButton(
          key: MiniPlayer.skipBackwardKey,
          icon: Icons.replay_30_rounded,
          label: l10n.miniPlayerSkipBackward,
          color: palette.textPrimary,
          onPressed: controller.skipBackward,
        ),
        _MainButton(request: request, isLive: false),
        _SkipButton(
          key: MiniPlayer.skipForwardKey,
          icon: Icons.forward_30_rounded,
          label: l10n.miniPlayerSkipForward,
          color: palette.textPrimary,
          onPressed: controller.skipForward,
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: color,
        iconSize: 24,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      ),
    );
  }
}

/// Ce que fait le gros bouton.
enum _MainAction {
  play,
  pause,

  /// Fin de lecture : rejouer depuis le début.
  replay,

  /// Panne après le premier son : reprendre à la position (#42).
  resume,

  /// Panne avant tout son : rouvrir la source, il n'y a pas de position.
  relaunch;

  static _MainAction of(ContentPlayback playback, String contentId) {
    if (playback.contentId != contentId) return play;
    if (playback.hasError) return playback.hasStarted ? resume : relaunch;
    if (playback.isCompleted) return replay;
    return playback.isPlaying ? pause : play;
  }
}

/// **Le gros bouton rond** — l'autre abonné à la position, par `select` sur
/// l'action qu'il porte.
class _MainButton extends ConsumerWidget {
  const _MainButton({required this.request, required this.isLive});

  final ContentRequest request;
  final bool isLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(
      contentPlaybackProvider.select(
        (p) => _MainAction.of(p, request.contentId),
      ),
    );
    final palette = context.palette;
    final l10n = context.l10n;

    final (icon, label) = switch (action) {
      _MainAction.play => (Icons.play_arrow_rounded, l10n.actionListen),
      _MainAction.pause => (Icons.pause_rounded, l10n.actionPause),
      _MainAction.replay => (Icons.replay_rounded, l10n.miniPlayerReplay),
      _MainAction.resume => (Icons.refresh_rounded, l10n.playerErrorRetry),
      _MainAction.relaunch => (Icons.refresh_rounded, l10n.miniPlayerRelaunch),
    };

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: palette.primary,
          shape: const CircleBorder(),
          child: InkWell(
            key: MiniPlayer.mainButtonKey,
            customBorder: const CircleBorder(),
            onTap: () => _press(ref, action),
            child: SizedBox.square(
              dimension: MiniPlayer.mainButtonSize,
              // `surface` et non un blanc en dur : en sombre, le bleu de
              // marque s'éclaircit, et c'est le fond sombre qui y contraste.
              child: Icon(icon, color: palette.surface, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  void _press(WidgetRef ref, _MainAction action) {
    final controller = ref.read(playbackControllerProvider.notifier);
    switch (action) {
      case _MainAction.play:
        controller.play();
      case _MainAction.pause:
        controller.pause();
      case _MainAction.replay:
        controller.replay();
      case _MainAction.resume:
      case _MainAction.relaunch:
        // **L'antenne se reprend chez elle** : une réouverture doit renégocier
        // la session de MediaMTX (#108), et le contrôleur rouvrirait avec le
        // cookie d'avant — 401, donc la panne.
        if (request.contentId == RadioConfig.contentId) {
          unawaited(
            ref.read(radioListeningProvider.notifier).start(
                  title: request.title,
                ),
          );
          return;
        }
        unawaited(controller.resume());
    }
  }
}

/// La ✕ : arrête le son, retire la notification, ferme le mini-lecteur.
class _CloseButton extends ConsumerWidget {
  const _CloseButton({required this.request});

  final ContentRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: context.l10n.miniPlayerClose,
      excludeSemantics: true,
      child: InkWell(
        key: MiniPlayer.closeKey,
        customBorder: const CircleBorder(),
        onTap: () => _close(ref),
        // Une cible de 32 px pour un cercle de 20 : la croix reste discrète,
        // le doigt n'a pas à viser.
        child: SizedBox.square(
          dimension: 32,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _close(WidgetRef ref) {
    // **L'antenne s'arrête chez elle** : arrêter le seul lecteur laisserait ses
    // tentatives de reprise programmées, qui rouvriraient le son après coup.
    // `RadioListening.stop` les annule, puis arrête par le contrôleur.
    if (request.contentId == RadioConfig.contentId) {
      ref.read(radioListeningProvider.notifier).stop();
      return;
    }
    ref.read(playbackControllerProvider.notifier).stop();
  }
}
