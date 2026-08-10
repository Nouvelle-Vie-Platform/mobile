import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/mediatheque_view.dart';
import '../../router/app_router.dart';
import '../../state/mediatheque_providers.dart';
import 'home_content_section.dart';

/// **Une rubrique d'enseignement, rendue à l'accueil.**
///
/// Ce widget ne dessine rien : il **câble** une famille à
/// [HomeContentSection] — quel flux lire (`teachingsOfTypeProvider`, donc la
/// collection `teachings`) et vers quelle route ouvrir (`/teaching/:id`). Le
/// dessin, lui, est le même pour les deux familles, et il n'a aucune raison de
/// différer.
///
/// Le partage s'arrête exactement là : le provider et la route désignent
/// toujours une famille, jamais « un contenu ». C'est ce qui rend impossible
/// qu'un rassemblement s'ouvre dans l'écran d'un enseignement.
class HomeTeachingSection extends ConsumerWidget {
  const HomeTeachingSection({super.key, required this.section});

  /// La rubrique telle que le magasin la rend : déjà filtrée sur
  /// `visibleOnHome`, déjà rangée, déjà repliée.
  final HomeSectionView section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teachingsOfTypeProvider(section.teachingTypeId);

    return HomeContentSection(
      section: section,
      items: ref.watch(provider),
      onOpen: (teaching) => context.pushNamed(
        AppRoute.teachingDetail,
        pathParameters: {'id': teaching.id},
      ),
      onRetry: () => ref.invalidate(provider),
      onSeeAll: () => context.pushNamed(AppRoute.media),
    );
  }
}
