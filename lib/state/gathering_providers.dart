import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/gathering_repository.dart';
import '../data/repositories/store_gathering_repository.dart';
import '../models/gathering_view.dart';
import 'locale_providers.dart';
import 'sync_providers.dart';

/// Politique de réessai des providers de rassemblement : **aucun réessai
/// automatique**, mêmes raisons que la médiathèque et que l'agenda.
///
/// Sur une lecture de **magasin local**, un échec n'est pas une intermittence
/// de réseau qu'attendre pourrait résoudre : c'est une base illisible. Insister
/// ne ferait que retarder l'aveu.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Fournit l'implémentation courante de [GatheringRepository].
///
/// Avec backend : le **magasin local**, que la synchronisation alimente. Sans
/// backend : le double en mémoire, qui applique **les mêmes règles de lecture**.
final gatheringRepositoryProvider = Provider<GatheringRepository>(
  (ref) => AppEnv.useBackend
      ? StoreGatheringRepository(ref.watch(gatheringDaoProvider))
      : InMemoryGatheringRepository(),
);

/// Tous les rassemblements, sans plafond.
final allGatheringsProvider = StreamProvider<List<GatheringView>>(
  (ref) => ref
      .watch(gatheringRepositoryProvider)
      .latestGatherings(locale: ref.watch(contentLocaleProvider)),
  retry: _noAutomaticRetry,
);

/// Les rassemblements d'une rubrique donnée.
///
/// L'argument est l'identifiant d'une ligne de **`gathering_types`** : la
/// famille de la rubrique et celle du contenu se répondent, comme côté serveur.
final gatheringsOfTypeProvider =
    StreamProvider.family<List<GatheringView>, int>(
  (ref, gatheringTypeId) =>
      ref.watch(gatheringRepositoryProvider).gatheringsOfType(
            gatheringTypeId,
            locale: ref.watch(contentLocaleProvider),
          ),
  retry: _noAutomaticRetry,
);

/// Résout un rassemblement par son identifiant, ou `null` s'il n'existe plus.
///
/// C'est le point d'entrée de l'écran de détail : il reçoit un identifiant par
/// la route et **relit la donnée ici**, dans la source de vérité, tant qu'il est
/// ouvert. Le flux est ce qui permet à une rétractation reçue pendant la
/// consultation de retirer le contenu de l'écran au lieu de laisser une copie
/// figée continuer à l'afficher.
///
/// `null` n'est pas une erreur technique : c'est l'absence « contenu retiré ».
final gatheringByIdProvider = StreamProvider.family<GatheringView?, String>(
  (ref, id) => ref
      .watch(gatheringRepositoryProvider)
      .gatheringById(id, locale: ref.watch(contentLocaleProvider)),
  retry: _noAutomaticRetry,
);

/// Les rubriques de rassemblement de l'accueil, prêtes à composer.
///
/// Le pendant de `homeSectionsProvider` : `position` en donne l'ordre, `layout`
/// la mise en page, `visibleOnHome` la présence, `label` le titre et `color` la
/// teinte. Un administrateur crée une rubrique de rassemblement, la place,
/// choisit sa forme — et l'accueil suit, sans livraison.
final gatheringSectionsProvider = StreamProvider<List<GatheringSectionView>>(
  (ref) => ref
      .watch(gatheringRepositoryProvider)
      .homeSections(locale: ref.watch(contentLocaleProvider)),
  retry: _noAutomaticRetry,
);
