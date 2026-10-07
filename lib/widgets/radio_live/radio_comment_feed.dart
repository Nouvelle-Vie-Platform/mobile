/// **Le fil du direct**, en bas à gauche sur un voile (#135, décision 12).
///
/// Il n'existe que pendant un direct : hors direct, la page ne le monte pas.
///
/// ## Le défilement suit le bas, sauf si l'auditeur remonte
///
/// La liste est **inversée** (`reverse: true`) : la position zéro est le bas,
/// donc un message qui arrive pendant qu'on est en bas s'y pose sans qu'aucun
/// code ne défile. Quand l'auditeur est remonté lire, rien ne le tire vers le
/// bas : une pastille « Nouveaux messages » paraît, et c'est lui qui décide d'y
/// revenir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/radio/radio_live.dart';
import '../../l10n/l10n_extension.dart';
import '../../state/radio_live_providers.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';
import 'radio_live_sheets.dart';

/// Au-delà de ce décalage depuis le bas, l'auditeur est « remonté ».
const double _kStickToBottomSlack = 24;

class RadioCommentFeed extends ConsumerStatefulWidget {
  const RadioCommentFeed({super.key});

  static const Key listKey = Key('radio_comment_feed');
  static const Key newMessagesKey = Key('radio_comment_new_messages');

  /// La clé d'un message, pour les tests (appui long, masquage).
  static Key messageKey(String id) => Key('radio_comment_$id');

  @override
  ConsumerState<RadioCommentFeed> createState() => _RadioCommentFeedState();
}

class _RadioCommentFeedState extends ConsumerState<RadioCommentFeed> {
  final _scroll = ScrollController();
  bool _away = false;
  bool _unseen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final away = _scroll.hasClients && _scroll.offset > _kStickToBottomSlack;
    if (away == _away) return;
    setState(() {
      _away = away;
      if (!away) _unseen = false;
    });
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    setState(() => _unseen = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final comments = ref.watch(radioLiveProvider.select((s) => s.comments));
    final moderator =
        ref.watch(radioLiveProvider.select((s) => s.viewer.moderator));

    ref.listen<String?>(
      radioLiveProvider.select(
        (s) => s.comments.isEmpty ? null : s.comments.last.id,
      ),
      (previous, next) {
        if (next != null && next != previous && _away && !_unseen) {
          setState(() => _unseen = true);
        }
      },
    );

    return Semantics(
      container: true,
      label: l10n.radioCommentsLabel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // **Le voile** : un dégradé qui fond vers le haut, pour que le fil
          // reste lisible sur n'importe quel fond de saison sans le cacher.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.38),
                ],
              ),
            ),
            child: ListView.builder(
              key: RadioCommentFeed.listKey,
              controller: _scroll,
              reverse: true,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[comments.length - 1 - index];
                // Les gestes partent du contexte **du fil**, pas de la ligne :
                // un message masqué emporte sa ligne, et la confirmation doit
                // encore pouvoir s'afficher.
                return _CommentLine(
                  comment: comment,
                  onLongPress: () => showRadioMessageActions(
                    this.context,
                    comment,
                    moderator: moderator,
                  ),
                );
              },
            ),
          ),
          if (_unseen)
            Positioned(
              bottom: AppSpacing.sm,
              left: 0,
              right: 0,
              child: Center(
                child: ActionChip(
                  key: RadioCommentFeed.newMessagesKey,
                  avatar: const Icon(Icons.arrow_downward_rounded, size: 16),
                  label: Text(l10n.radioNewMessages),
                  onPressed: _toBottom,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentLine extends StatelessWidget {
  const _CommentLine({required this.comment, required this.onLongPress});

  final RadioComment comment;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final open = onLongPress;

    return Semantics(
      key: RadioCommentFeed.messageKey(comment.id),
      container: true,
      label: l10n.radioCommentSemantics(comment.authorName, comment.body),
      onLongPress: open,
      onLongPressHint: l10n.radioMessageOptionsHint,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: open,
          // **Un rond aux initiales, pas le pseudo en entier** : le fil reste
          // court et se lit d'un coup d'œil. Le nom complet reste dans le
          // libellé du lecteur d'écran, ci-dessus.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(name: comment.authorName, size: 26),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      comment.body,
                      style: AppTypography.body.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                    ),
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
