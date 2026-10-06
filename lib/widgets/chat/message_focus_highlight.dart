import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';

/// **Le message trouvé, mis en évidence** (#146, tranche M8) — un fond teinté
/// qui s'efface de lui-même, comme WhatsApp quand on ouvre un résultat de
/// recherche.
///
/// Une minuterie et un `AnimatedContainer`, pas d'`AnimationController` : rien
/// à libérer dans `dispose()` sinon la minuterie elle-même.
class MessageFocusHighlight extends StatefulWidget {
  const MessageFocusHighlight({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 2),
  });

  final Widget child;

  /// Combien de temps le fond reste avant de s'effacer.
  final Duration duration;

  static const Key tintKey = Key('message_focus_highlight');

  @override
  State<MessageFocusHighlight> createState() => _MessageFocusHighlightState();
}

class _MessageFocusHighlightState extends State<MessageFocusHighlight> {
  bool _lit = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _lit = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: _lit ? MessageFocusHighlight.tintKey : null,
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: _lit
            ? context.palette.primary.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: widget.child,
    );
  }
}

/// **Amène à l'écran l'élément porteur de [target]** dans une liste inversée et
/// paresseuse : tant qu'il n'est pas construit, on remonte d'un écran ; puis on
/// le place au milieu de la vue. Le patron de l'ouverture sur le premier
/// non-lu (#140), écrit une fois pour la recherche.
void revealKeyedItem({
  required GlobalKey target,
  required ScrollController scroll,
  required bool Function() mounted,
  int attempt = 0,
}) {
  if (!mounted()) return;
  final context = target.currentContext;
  if (context != null) {
    Scrollable.ensureVisible(context, alignment: 0.5);
    return;
  }
  if (!scroll.hasClients || attempt > 40) return;
  final position = scroll.position;
  if (position.pixels >= position.maxScrollExtent) return;
  scroll.jumpTo(
    math.min(
      position.pixels + position.viewportDimension,
      position.maxScrollExtent,
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => revealKeyedItem(
      target: target,
      scroll: scroll,
      mounted: mounted,
      attempt: attempt + 1,
    ),
  );
}
