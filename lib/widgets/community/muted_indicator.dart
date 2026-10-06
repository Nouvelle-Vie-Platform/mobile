import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_palette.dart';

/// **Le haut-parleur barré** d'une discussion en sourdine (tranche M5), dans la
/// tuile de la liste — comme WhatsApp, à côté de l'heure.
///
/// Un widget à part plutôt qu'une branche de plus dans `ConversationTile` :
/// plusieurs tranches de la messagerie touchent la tuile, et chacune y pose son
/// emplacement sans réécrire celui des autres.
class MutedIndicator extends StatelessWidget {
  const MutedIndicator({super.key});

  static const Key iconKey = Key('conversation_muted_icon');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.conversationMuted,
      child: Icon(
        Icons.volume_off,
        key: iconKey,
        size: 16,
        color: context.palette.textSecondary,
      ),
    );
  }
}
