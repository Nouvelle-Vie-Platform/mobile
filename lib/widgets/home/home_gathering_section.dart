import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/gathering_view.dart';
import '../../router/app_router.dart';
import '../../state/gathering_providers.dart';
import 'home_content_section.dart';

/// **Une rubrique de rassemblement, rendue à l'accueil.**
///
/// Le pendant exact de `HomeTeachingSection`, et aussi mince que lui : il
/// choisit le flux (`gatheringsOfTypeProvider`, donc la collection
/// `gatherings`) et la destination (`/gathering/:id`). Tout le dessin est dans
/// [HomeContentSection].
///
/// **Pas de « voir tout »** : il n'existe pas d'écran qui montre tous les
/// rassemblements. Un lien vers la médiathèque serait un mensonge — elle ne
/// contient aucun rassemblement, et n'en contiendra jamais —, et un lien mort
/// fait croire à une panne. L'action reviendra le jour où l'écran existera.
class HomeGatheringSection extends ConsumerWidget {
  const HomeGatheringSection({super.key, required this.section});

  /// La rubrique telle que le magasin la rend : déjà filtrée sur
  /// `visibleOnHome`, déjà rangée, déjà repliée.
  final GatheringSectionView section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = gatheringsOfTypeProvider(section.teachingTypeId);

    return HomeContentSection(
      section: section,
      items: ref.watch(provider),
      onOpen: (gathering) => context.pushNamed(
        AppRoute.gatheringDetail,
        pathParameters: {'id': gathering.id},
      ),
      onRetry: () => ref.invalidate(provider),
    );
  }
}
