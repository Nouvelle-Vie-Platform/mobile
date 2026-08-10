import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/mediatheque_providers.dart';
import '../widgets/content_player_view.dart';

/// Écran de détail d'un **enseignement**, façon lecteur plein écran.
///
/// Il reçoit un **identifiant**, jamais l'objet, et relit la donnée dans la
/// source de vérité ([teachingByIdProvider]) à chaque build. Ce n'est pas un
/// détail d'implémentation : un enseignement passé par `extra` serait une copie
/// figée au moment du clic, et une rétractation reçue pendant les vingt minutes
/// d'écoute laisserait l'écran afficher — lecteur compris — un contenu que le
/// serveur a retiré. Le fidèle le retrouverait disparu de la liste au retour,
/// sans comprendre ce qu'il vient d'écouter.
///
/// Tout le dessin est dans [ContentPlayerView], partagé avec l'écran de détail
/// d'un rassemblement : le lecteur, les quatre situations (chargement, panne,
/// contenu retiré, contenu trouvé) et l'arrêt de la lecture sur rétractation
/// n'ont aucune raison de différer d'une famille à l'autre. Ce qui reste ici est
/// **ce qui désigne la famille** : le provider, donc la collection lue, et les
/// mots qu'on emploie à l'écran.
class TeachingDetailScreen extends ConsumerWidget {
  const TeachingDetailScreen({super.key, required this.teachingId});

  /// UUIDv7 de l'enseignement, porté par la route (`/teaching/:id`).
  final String teachingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teachingByIdProvider(teachingId);

    return ContentPlayerView(
      content: provider,
      chromeTitle: context.l10n.teachingAppBarTitle,
      retractedTitle: context.l10n.teachingRetractedTitle,
      retractedMessage: context.l10n.teachingRetractedMessage,
      onRetry: () => ref.invalidate(provider),
    );
  }
}
