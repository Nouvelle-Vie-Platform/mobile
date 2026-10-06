import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../router/app_router.dart';
import '../../theme/app_spacing.dart';
import '../app_button.dart';

/// **« Nouvelle discussion »**, en tête de l'onglet Messages (#145).
///
/// Un bouton de la liste et non un FAB : le bouton central de la coquille
/// reste ce qu'il est (D9 du cadrage d'Échanges). Il ouvre le sélecteur des
/// personnes de mes groupes — et, pour un responsable, « Nouveau groupe ».
///
/// L'onglet Messages n'est monté que pour un membre (la coquille met le
/// formulaire de connexion à sa place) ; l'onglet ne le pose de toute façon
/// que si l'acteur est connu.
class NewConversationEntry extends StatelessWidget {
  const NewConversationEntry({super.key});

  static const buttonKey = ValueKey('echanges-new-conversation');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: AppButton(
        key: buttonKey,
        label: context.l10n.m6NewConversation,
        icon: Icons.add_comment_outlined,
        variant: AppButtonVariant.outline,
        onPressed: () => context.pushNamed(AppRoute.newConversation),
      ),
    );
  }
}
