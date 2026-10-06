import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../state/echanges_providers.dart';
import '../../state/receipts_providers.dart';
import '../../utils/presence_labels.dart';

/// **« Ama écrit… » sur la tuile d'une conversation** (#142, M3), ou `null`
/// si personne n'y écrit. Lu dans l'état éphémère (jamais dans le magasin) ;
/// le nom vient de `profiles`, par l'acteur passé en clé de famille.
String? conversationTypingLabel(
  WidgetRef ref,
  BuildContext context, {
  required String? actor,
  required ConversationView conversation,
}) {
  final typers =
      ref.watch(typingInProvider((actor: actor, id: conversation.groupId)));
  if (typers.isEmpty) return null;
  final firstName = conversation.isDirect || typers.length > 1
      ? null
      : ref
          .watch(memberProfileProvider((actor: actor, id: typers.single)))
          .value
          ?.displayName;
  return typingLabel(
    context.l10n,
    typers: typers,
    isDirect: conversation.isDirect,
    nameOf: (_) => firstName,
  );
}
