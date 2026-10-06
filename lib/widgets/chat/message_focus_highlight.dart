import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';

/// Combien de temps le message trouvé reste en évidence avant de s'effacer.
const Duration kMessageFocusDuration = Duration(seconds: 2);

/// **Le message trouvé, mis en évidence** (#146, tranche M8) — un fond teinté
/// qui s'efface, comme WhatsApp quand on ouvre un résultat de recherche.
///
/// Sans état : c'est l'écran qui dit quand le fond s'éteint ([lit]), une seule
/// fois. Une minuterie portée par ce widget se réarmerait chaque fois que la
/// liste paresseuse recrée la bulle — en revenant sur elle après l'avoir fait
/// défiler hors de l'écran, le fond se rallumerait. L'`AnimatedContainer` fait
/// le fondu quand [lit] passe à `false` ; aucun `AnimationController` à libérer.
class MessageFocusHighlight extends StatelessWidget {
  const MessageFocusHighlight({
    super.key,
    required this.child,
    required this.lit,
  });

  final Widget child;

  /// `true` tant que le fond doit rester allumé.
  final bool lit;

  static const Key tintKey = Key('message_focus_highlight');

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: lit ? MessageFocusHighlight.tintKey : null,
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: lit
            ? context.palette.primary.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
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
