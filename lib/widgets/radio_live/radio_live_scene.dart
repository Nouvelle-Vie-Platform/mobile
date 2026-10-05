/// **La page radio plein écran, façon live** (#135, décision 12 du plan) :
///
/// ```
/// ┌────────────────────────┐
/// │ ←  ● EN DIRECT  👁 128 ⚑│  badge en direct seulement ; compteur absent si null ;
/// │ New Life Radio         │  ⚑ = file des signalements, modérateur seulement
/// │   (état de l'écoute)   │
/// │                     ❤️ │  réactions qui montent
/// │ Ama K.  Amen !      🙏 │  fil sur un voile, en direct seulement
/// │ Kossi  gloire à Dieu 🔥│  boutons de réaction, toujours
/// │ [ Écrire…         ] ➤  │  champ, en direct seulement
/// │      ■     ⏸            │  arrêt, lecture/pause
/// └────────────────────────┘
/// ```
///
/// Le fond de saison est posé par `ContentPlayerView` (sa cascade), et le
/// gros bouton vient de lui déjà câblé : cette scène **dispose**, elle ne pilote
/// pas l'écoute. Deux intensités (décision 2) : hors direct, compteur et
/// réactions ; en direct, badge et fil en plus.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/radio_config.dart';
import '../../data/radio/radio_live.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../state/player_providers.dart';
import '../../state/radio_live_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../content_player_view.dart';
import 'radio_comment_feed.dart';
import 'radio_live_sheets.dart';
import 'radio_reaction_particles.dart';

/// La largeur de la colonne des réactions, à droite.
const double _kReactionColumn = 56;

/// Le diamètre d'un bouton de réaction — au-dessus des 44 points d'une cible
/// tactile accessible.
const double _kReactionButton = 48;

class RadioLiveScene extends ConsumerWidget {
  const RadioLiveScene({
    super.key,
    required this.parts,
    required this.title,
    required this.status,
  });

  final ContentPlayerSceneParts parts;
  final String title;

  /// L'état de l'écoute (`RadioAirStatus`) : reprise, abandon et sa cause,
  /// « hors antenne ». Il garde la place centrale qu'il avait sur la fiche.
  final Widget status;

  static const Key liveBadgeKey = Key('radio_live_badge');
  static const Key listenersKey = Key('radio_live_listeners');
  static const Key reportedQueueKey = Key('radio_live_reported_queue');
  static const Key composerKey = Key('radio_live_composer');
  static const Key sendKey = Key('radio_live_send');
  static const Key silencedKey = Key('radio_live_silenced');
  static Key reactionKey(RadioReaction reaction) =>
      Key('radio_reaction_${reaction.wire}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLive = ref.watch(radioLiveProvider.select((s) => s.isLive));
    final offersComposer =
        ref.watch(radioLiveProvider.select((s) => s.offersComposer));
    final silenced = ref
        .watch(radioLiveProvider.select((s) => s.isLive && s.viewer.silenced));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TopRow(),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: _kReactionColumn,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: const Alignment(0, -0.4),
                      child: status,
                    ),
                  ),
                  if (isLive)
                    Positioned(
                      left: 0,
                      right: _kReactionColumn + AppSpacing.sm,
                      bottom: 0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: box.maxHeight * 0.55,
                        ),
                        child: const RadioCommentFeed(),
                      ),
                    ),
                  const Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: _kReactionColumn,
                    child: _ReactionColumn(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (offersComposer)
            const _Composer()
          else if (silenced)
            const _SilencedNotice(),
          const SizedBox(height: AppSpacing.md),
          _Transport(parts: parts),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// En haut : retour, badge du direct, compteur, et la file d'un modérateur.
class _TopRow extends ConsumerWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isLive = ref.watch(radioLiveProvider.select((s) => s.isLive));
    final listeners = ref.watch(radioLiveProvider.select((s) => s.listeners));
    final moderator =
        ref.watch(radioLiveProvider.select((s) => s.viewer.moderator));
    final reported =
        ref.watch(radioLiveProvider.select((s) => s.reported.length));

    return Row(
      children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        if (isLive) ...[
          const _LiveBadge(),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (listeners != null)
          Semantics(
            key: RadioLiveScene.listenersKey,
            container: true,
            label: l10n.radioListeners(listeners),
            child: ExcludeSemantics(
              child: _Chip(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$listeners',
                    style: AppTypography.bodyStrong.copyWith(
                      color: Colors.white,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        if (moderator)
          IconButton(
            key: RadioLiveScene.reportedQueueKey,
            tooltip: l10n.radioReportedQueue,
            onPressed: () => showRadioReportedQueue(context),
            icon: Badge(
              isLabelVisible: reported > 0,
              label: Text('$reported'),
              child: const Icon(Icons.flag_outlined, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: RadioLiveScene.liveBadgeKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 8),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            context.l10n.radioLiveBadge,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// À droite : les réactions qui montent, au-dessus de leurs cinq boutons.
///
/// Deux replis, pour qu'aucune hauteur ne fasse déborder la page : clavier
/// ouvert, les boutons s'effacent (on écrit, on ne réagit pas — et les
/// réactions des autres continuent de monter) ; sur un écran trop court pour
/// les cinq boutons et leur couloir, les boutons défilent et le couloir part.
class _ReactionColumn extends ConsumerWidget {
  const _ReactionColumn();

  /// La hauteur des cinq boutons et de leurs écarts.
  static const double _buttonsHeight = 5 * (_kReactionButton + AppSpacing.sm);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final buttons = [
      for (final reaction in RadioReaction.values)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: _ReactionButton(
            reaction: reaction,
            label: _label(reaction, l10n),
            onPressed: () =>
                ref.read(radioLiveProvider.notifier).react(reaction),
          ),
        ),
    ];
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(
      builder: (context, box) {
        if (typing) return const RadioReactionParticles();
        if (box.maxHeight < _buttonsHeight + _kReactionButton) {
          return SingleChildScrollView(
            reverse: true,
            child: Column(children: buttons),
          );
        }
        return Column(
          children: [
            const Expanded(child: RadioReactionParticles()),
            ...buttons,
          ],
        );
      },
    );
  }

  static String _label(RadioReaction reaction, AppLocalizations l10n) =>
      switch (reaction) {
        RadioReaction.heart => l10n.radioReactionHeart,
        RadioReaction.pray => l10n.radioReactionPray,
        RadioReaction.praise => l10n.radioReactionPraise,
        RadioReaction.fire => l10n.radioReactionFire,
        RadioReaction.amen => l10n.radioReactionAmenLabel,
      };
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.reaction,
    required this.label,
    required this.onPressed,
  });

  final RadioReaction reaction;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final emoji = reaction.emoji;
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        key: RadioLiveScene.reactionKey(reaction),
        color: Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: _kReactionButton,
            child: Center(
              child: emoji != null
                  ? Text(emoji, style: const TextStyle(fontSize: 22))
                  : Text(
                      context.l10n.radioReactionAmen,
                      maxLines: 1,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// **Le champ du direct** — et le pseudo d'un invité, demandé au premier
/// message puis oublié : l'envoi repart de lui-même une fois le pseudo choisi.
class _Composer extends ConsumerStatefulWidget {
  const _Composer();

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _field = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _field.text;
    if (_sending || text.trim().isEmpty) return;
    final l10n = context.l10n;
    setState(() => _sending = true);
    final live = ref.read(radioLiveProvider.notifier);
    RadioSendOutcome? outcome = await live.send(text);
    if (outcome == RadioSendOutcome.pseudonymRequired) {
      // **Le pseudo, puis le renvoi automatique** : l'invité n'a pas à
      // retaper ni à rappuyer. Une feuille fermée sans pseudo garde le texte,
      // sans rien dire — c'est un renoncement, pas une panne.
      if (!mounted) return;
      final saved = await showRadioPseudonymSheet(context);
      outcome = saved ? await live.send(text) : null;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (outcome == null) return;
    if (outcome == RadioSendOutcome.sent) {
      _field.clear();
      return;
    }
    showRadioLiveMessage(
        context,
        switch (outcome) {
          RadioSendOutcome.silenced => l10n.radioSilencedNotice,
          RadioSendOutcome.closed => l10n.radioCommentClosed,
          RadioSendOutcome.throttled => l10n.radioCommentThrottled,
          RadioSendOutcome.invalid => l10n.radioCommentInvalid,
          _ => l10n.radioCommentFailed,
        });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: RadioLiveScene.composerKey,
            controller: _field,
            maxLength: kRadioCommentMaxLength,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            style: AppTypography.body.copyWith(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: l10n.radioCommentHint,
              hintStyle: AppTypography.body.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          key: RadioLiveScene.sendKey,
          tooltip: l10n.actionSend,
          onPressed: _sending ? null : _submit,
          icon: const Icon(Icons.send_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

class _SilencedNotice extends StatelessWidget {
  const _SilencedNotice();

  @override
  Widget build(BuildContext context) {
    return Text(
      key: RadioLiveScene.silencedKey,
      context.l10n.radioSilencedNotice,
      style: AppTypography.caption.copyWith(
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

/// En bas : l'arrêt et le gros bouton, chacun **nommé** pour le lecteur
/// d'écran — le bouton de la fiche n'a pas de libellé à lui.
class _Transport extends ConsumerWidget {
  const _Transport({required this.parts});

  final ContentPlayerSceneParts parts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playing = ref.watch(
      contentPlaybackProvider.select(
        (p) =>
            p.contentId == RadioConfig.contentId && p.isPlaying && !p.hasError,
      ),
    );
    final stop = parts.stopButton;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (stop != null) ...[
          Semantics(
            container: true,
            label: l10n.radioStopListening,
            child: stop,
          ),
          const SizedBox(width: AppSpacing.xl),
        ],
        Semantics(
          container: true,
          button: true,
          label: playing ? l10n.actionPause : l10n.actionListen,
          child: parts.playButton,
        ),
        if (stop != null) const SizedBox(width: 44 + AppSpacing.xl),
      ],
    );
  }
}
