import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_palette.dart';

/// **Glisser une bulle vers la droite pour y répondre** (M2, #141 ; décision 11
/// du plan) — le geste de WhatsApp.
///
/// La bulle suit le doigt **vers la droite seulement**, freinée au-delà du
/// seuil ; une icône de réponse apparaît derrière elle, de plus en plus nette.
/// Passer le seuil donne **un** retour haptique ; relâcher au-delà répond,
/// relâcher en deçà annule. Dans les deux cas la bulle revient en place.
///
/// ## Le geste ne se déclenche que sur une bulle
///
/// Ce widget enveloppe **une bulle** du fil, et rien d'autre : son détecteur ne
/// couvre que la bulle. Le fil est une liste **verticale** — un glissement
/// horizontal ne lui dispute rien —, et le balayage horizontal des onglets de
/// la page Échanges (Messages / Requêtes) n'existe pas dans un fil. Un
/// glissement vers la gauche n'est pas consommé : il ne fait rien.
///
/// Pas d'`AnimationController` : le retour en place est une
/// `AnimatedContainer` qui ne s'anime que hors du glissement — rien à libérer,
/// rien à toucher dans `dispose()`.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  final Widget child;

  /// Appelé quand le geste aboutit (relâché au-delà du seuil).
  final VoidCallback onReply;

  /// Faux : la bulle ne glisse pas (message supprimé, écho, lecture seule).
  final bool enabled;

  /// Le seuil, en pixels logiques, au-delà duquel relâcher répond.
  static const double threshold = 64;

  /// Le déplacement maximal de la bulle.
  static const double maxOffset = 96;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _dx = 0;
  bool _dragging = false;
  bool _armed = false;

  void _onUpdate(DragUpdateDetails details) {
    final next =
        (_dx + details.delta.dx).clamp(0.0, SwipeToReply.maxOffset).toDouble();
    final armed = next >= SwipeToReply.threshold;
    if (armed && !_armed) HapticFeedback.lightImpact();
    setState(() {
      _dragging = true;
      _dx = next;
      _armed = armed;
    });
  }

  void _onEnd(DragEndDetails _) {
    final reply = _armed;
    setState(() {
      _dragging = false;
      _dx = 0;
      _armed = false;
    });
    if (reply) widget.onReply();
  }

  void _onCancel() {
    setState(() {
      _dragging = false;
      _dx = 0;
      _armed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final progress = (_dx / SwipeToReply.threshold).clamp(0.0, 1.0).toDouble();
    final palette = context.palette;

    return GestureDetector(
      key: const Key('swipe_to_reply'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _onCancel,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // L'icône derrière la bulle : elle apparaît avec le glissement.
          Positioned(
            left: 4,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: CircleAvatar(
                  key: const Key('swipe_to_reply_icon'),
                  radius: 16,
                  backgroundColor: palette.surface,
                  child: Icon(
                    Icons.reply,
                    size: 18,
                    color: _armed ? palette.primary : palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration:
                _dragging ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
