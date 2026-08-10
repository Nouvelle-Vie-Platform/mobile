import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/gathering_providers.dart';
import '../widgets/content_player_view.dart';

/// Écran de détail d'un **rassemblement**, façon lecteur plein écran.
///
/// Le jumeau de `TeachingDetailScreen`, et aussi mince que lui : la route porte
/// l'**identifiant** (`/gathering/:id`), l'écran relit la donnée dans la source
/// de vérité ([gatheringByIdProvider]) à chaque build, et tout le dessin est
/// dans [ContentPlayerView].
///
/// Deux écrans plutôt qu'un seul paramétré, et c'est le même arbitrage que
/// partout dans ce chantier : la clé de collection est le discriminant
/// (ADR-0026, décision 1). Un écran unique qui recevrait « un identifiant et une
/// famille » ferait du client l'arbitre de ce qu'il regarde ; ici, la route dit
/// la famille, le provider lit **une** collection, et rien ne peut se croiser.
///
/// Quand l'identifiant ne résout plus rien, l'écran **reste ouvert** et bascule
/// sur `ContentAbsence.retracted` — la variante existe déjà, il n'y en a pas de
/// cinquième à écrire.
class GatheringDetailScreen extends ConsumerWidget {
  const GatheringDetailScreen({super.key, required this.gatheringId});

  /// UUIDv7 du rassemblement, porté par la route (`/gathering/:id`).
  final String gatheringId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = gatheringByIdProvider(gatheringId);

    return ContentPlayerView(
      content: provider,
      // « Rassemblement », et **jamais** « Événement » : le calendrier
      // (collection `events`) est une autre chose — des occurrences datées,
      // avec séries, exceptions et fuseaux. Un rassemblement de médiathèque est
      // un contenu enregistré, catalogué et publié comme un enseignement. Les
      // deux peuvent parler du même concert : l'un l'annonce, l'autre en garde
      // la trace.
      chromeTitle: context.l10n.gatheringAppBarTitle,
      retractedTitle: context.l10n.gatheringRetractedTitle,
      retractedMessage: context.l10n.gatheringRetractedMessage,
      onRetry: () => ref.invalidate(provider),
    );
  }
}
