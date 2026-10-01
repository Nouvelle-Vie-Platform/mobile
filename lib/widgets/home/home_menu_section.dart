import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/menu_labels.dart';
import '../../models/content_view.dart';
import '../../models/menu_entry_view.dart';
import '../../router/app_router.dart';
import '../../state/menu_providers.dart';
import 'home_content_section.dart';

/// **Une entrée de menu, rendue en section d'accueil** (#82).
///
/// Ce widget ne dessine rien : il **câble** une entrée à [HomeContentSection] —
/// quel flux lire (celui de la famille que la destination nomme) et vers quelle
/// route ouvrir. Le dessin est le même que pour une rubrique, et il n'a aucune
/// raison de différer : ce qui change est **qui décide** de la section.
///
/// ## Ce qu'une entrée n'a pas, et qu'une rubrique avait
///
/// **Une couleur.** Le modèle de menu n'en porte pas, et c'est cohérent : une
/// rubrique est une taxonomie qui habille son contenu, une entrée est une
/// intention de navigation. La pastille du titre prend donc le bleu de marque
/// ([kBrandFallbackColor]), dernier maillon de la cascade — et non la couleur de
/// la rubrique visée, qui ferait croire que l'entrée *est* la rubrique alors
/// qu'elle peut en viser une, aucune, ou toute une famille.
///
/// ## Ce qui ne paraît pas ici, et pourquoi
///
/// Un **lien externe** marqué visible à l'accueil ne rend aucune section : les
/// trois gabarits (`hero`, `carousel`, `list`) sont des formes de **liste de
/// contenus**, et il n'y a pas de gabarit pour une adresse. L'entrée reste
/// résolue — elle paraît dans la barre d'onglets de la médiathèque, où un geste
/// a du sens — mais l'accueil n'a rien à en faire. C'est la même frontière que
/// « pas de contenu, pas de section », appliquée à un type qui n'est pas une
/// liste.
class HomeMenuSection extends ConsumerWidget {
  const HomeMenuSection({super.key, required this.entry});

  /// L'entrée telle que le magasin la rend : déjà filtrée sur sa surface, déjà
  /// rangée, déjà repliée, et **connue non vide**.
  final MenuEntryView entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = entry.destination;
    if (destination is! MenuCatalogue) return const SizedBox.shrink();
    final label = menuEntryLabel(context, entry);
    if (label == null) return const SizedBox.shrink();

    // **Deux providers, deux collections, deux routes** : `destinationFamily`
    // dit quelle collection lire, elle ne range pas une ligne (ADR-0026
    // décision 1). C'est ce qui rend impossible qu'un rassemblement s'ouvre dans
    // l'écran d'un enseignement.
    final teaching = destination.family == MenuContentFamily.teaching;
    final items = teaching
        ? ref.watch(menuTeachingsProvider(destination))
        : ref.watch(menuGatheringsProvider(destination));
    final route = teaching ? AppRoute.teachingDetail : AppRoute.gatheringDetail;

    return HomeContentSection(
      title: label,
      accent: const Color(kBrandFallbackColor),
      layout: entry.layout,
      items: items,
      onOpen: (content) => context.pushNamed(
        route,
        pathParameters: {'id': content.id},
      ),
      onRetry: () => ref.invalidate(
        teaching
            ? menuTeachingsProvider(destination)
            : menuGatheringsProvider(destination),
      ),
      // **« Voir tout » n'existe que pour la famille enseignement**, et seulement
      // quand l'entrée nomme une rubrique : c'est le seul cas où la médiathèque
      // sait reproduire la liste. Un lien vers une liste qu'elle ne saurait pas
      // filtrer serait le bug même que cette tranche répare.
      onSeeAll: teaching && destination.rubricSlug != null
          ? () => context.pushNamed(
                AppRoute.media,
                queryParameters: {'rubrique': destination.rubricSlug!},
              )
          : null,
    );
  }
}
