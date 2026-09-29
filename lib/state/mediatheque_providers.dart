import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/mediatheque_repository.dart';
import '../data/repositories/store_mediatheque_repository.dart';
import '../models/mediatheque_view.dart';
import 'locale_providers.dart';
import 'sync_providers.dart';

/// Nombre d'enseignements de la section « Derniers enseignements ».
///
/// L'accueil est une vitrine, pas la médiathèque : le plafond part sur la
/// requête plutôt que de tronquer côté client une liste entière qu'on aurait
/// lue pour rien.
const int kLatestTeachingsLimit = 12;

/// Politique de réessai des providers de médiathèque : **aucun réessai
/// automatique** — mêmes raisons que l'agenda (`calendar_providers.dart`).
///
/// Riverpod 3 réessaie tout seul un provider en échec, jusqu'à dix fois avec
/// une attente qui double. Sur une lecture de **magasin local**, un échec n'est
/// pas une intermittence de réseau qu'attendre pourrait résoudre : c'est une
/// base illisible. Insister ne ferait que retarder l'aveu.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Fournit l'implémentation courante de [MediathequeRepository].
///
/// Avec backend : le **magasin local**, que la synchronisation alimente. Le
/// réseau ne peint jamais un écran (ADR-0026) — c'est ce qui rend la
/// médiathèque lisible hors ligne dès la première image.
///
/// Sans backend (`AppEnv.useBackend` faux) : le double en mémoire adossé à
/// `SampleData`, qui applique **les mêmes règles de lecture**.
final mediathequeRepositoryProvider = Provider<MediathequeRepository>(
  (ref) => AppEnv.useBackend
      ? StoreMediathequeRepository(ref.watch(mediathequeDaoProvider))
      : InMemoryMediathequeRepository(),
);

/// Section « Derniers enseignements » — **les plus récents, toutes rubriques
/// confondues**, à l'exclusion des cultes entiers.
///
/// Les **cultes entiers** en sont écartés : ils durent des heures et
/// écraseraient une liste faite pour picorer. Ils restent atteignables par leur
/// rubrique et par la médiathèque. Le filtre vit ici et non dans le repository :
/// c'est un choix éditorial de l'accueil, pas une propriété de la donnée.
///
/// Le plafond est demandé **avant** le filtre, comme le fait le serveur : une
/// poignée de cultes entiers peut donc raccourcir la liste. C'est préféré à
/// deux allers-retours pour une vitrine.
final latestTeachingsProvider = StreamProvider<List<TeachingView>>(
  (ref) {
    final locale = ref.watch(contentLocaleProvider);
    return ref
        .watch(mediathequeRepositoryProvider)
        .latestTeachings(locale: locale, limit: kLatestTeachingsLimit)
        .map(
          (teachings) => List<TeachingView>.unmodifiable(
            teachings.where((teaching) => !teaching.isFullService),
          ),
        );
  },
  retry: _noAutomaticRetry,
);

/// Tous les enseignements, sans plafond — ce que la médiathèque affiche.
final allTeachingsProvider = StreamProvider<List<TeachingView>>(
  (ref) => ref
      .watch(mediathequeRepositoryProvider)
      .latestTeachings(locale: ref.watch(contentLocaleProvider)),
  retry: _noAutomaticRetry,
);

/// Les enseignements d'une rubrique donnée.
///
/// **Ce qui remplace les trois providers `_byRubric` en dur.** Ceux-là
/// filtraient sur une valeur d'enum ; celui-ci prend l'identifiant que le
/// serveur a attribué, et fonctionne donc pour la rubrique qu'un administrateur
/// créera demain. C'est le ticket #32 qui l'appellera, une fois par section
/// rendue par [homeSectionsProvider].
final teachingsOfTypeProvider = StreamProvider.family<List<TeachingView>, int>(
  (ref, teachingTypeId) => ref
      .watch(mediathequeRepositoryProvider)
      .teachingsOfType(teachingTypeId,
          locale: ref.watch(contentLocaleProvider)),
  retry: _noAutomaticRetry,
);

/// Résout un enseignement par son identifiant, ou `null` s'il n'existe plus.
///
/// C'est le point d'entrée des écrans de détail : ils reçoivent un identifiant
/// par la route et **relisent la donnée ici**, dans la source de vérité, tant
/// qu'ils sont ouverts. Le flux est ce qui permet à une rétractation reçue
/// pendant l'écoute de retirer le contenu de l'écran au lieu de laisser une
/// copie figée continuer à jouer.
///
/// `null` n'est pas une erreur technique : c'est l'absence « contenu retiré ».
final teachingByIdProvider = StreamProvider.family<TeachingView?, String>(
  (ref, id) => ref
      .watch(mediathequeRepositoryProvider)
      .teachingById(id, locale: ref.watch(contentLocaleProvider)),
  retry: _noAutomaticRetry,
);

/// **Les invités d'un contenu, dans l'ordre saisi** — #77.
///
/// Un provider **séparé** de [teachingByIdProvider], et c'est la décision de
/// cette tranche : `ContentView.authorName` est partagée avec les
/// rassemblements, le lecteur et les trois cartes d'accueil, et elle ne bouge
/// pas. La liste des invités emprunte donc son propre chemin, que **seul**
/// l'écran de détail écoute — un carrousel, une vignette ou une notification
/// d'écran verrouillé ne la demande jamais, donc ne peut pas l'afficher par
/// accident.
///
/// Rien ici ne sait ce qu'est un podcast : le pivot est générique à tous les
/// enseignements, et un message du dimanche auquel un invité a été crédité
/// affichera sa ligne comme un épisode.
///
/// Une liste **vide** est l'état normal de presque tout le catalogue. Ce n'est
/// pas une erreur, et elle se rend en **ne rendant rien**.
final teachingGuestsProvider = StreamProvider.family<List<String>, String>(
  (ref, teachingId) =>
      ref.watch(mediathequeRepositoryProvider).guestNames(teachingId),
  retry: _noAutomaticRetry,
);

/// Les rubriques de l'accueil, prêtes à composer — **ticket #32**.
///
/// Livré ici parce que c'est ce qui remplace les trois rubriques en dur : sans
/// lui, les retirer laisserait l'accueil sans aucun moyen de se reconstruire.
/// La composition proprement dite (`position`, `layout`, `visibleOnHome`) est
/// hors du périmètre de ce ticket ; ces trois valeurs voyagent déjà, intactes.
final homeSectionsProvider = StreamProvider<List<HomeSectionView>>(
  (ref) => ref
      .watch(mediathequeRepositoryProvider)
      .homeSections(locale: ref.watch(contentLocaleProvider)),
  retry: _noAutomaticRetry,
);
