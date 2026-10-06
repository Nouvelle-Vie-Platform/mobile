import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/external_link_launcher.dart';
import '../data/repositories/menu_repository.dart';
import '../data/repositories/store_menu_repository.dart';
import '../models/gathering_view.dart';
import '../models/menu_entry_view.dart';
import '../models/mediatheque_view.dart';
import 'gathering_providers.dart';
import 'locale_providers.dart';
import 'mediatheque_providers.dart';
import 'sync_providers.dart';
import 'theme_provider.dart';

/// **Les menus réglés au portail** (#82) — la barre d'onglets de la médiathèque
/// et les sections de l'accueil, servies par la même collection.
///
/// Aucun réessai automatique, comme la médiathèque et l'agenda : une lecture de
/// magasin qui échoue est une base illisible, et insister ne fait que retarder
/// l'aveu.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Fournit l'implémentation courante de [MenuRepository].
///
/// Avec backend : le **magasin local**, que la synchronisation alimente — c'est
/// ce qui donne sa barre d'onglets à un porteur sans compte, hors ligne, dès la
/// première image. Sans backend : le double en mémoire, qui rend un menu
/// **vide** (voir son en-tête — le vide est l'état qu'il faut exercer, pas un
/// trou à combler).
final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => AppEnv.useBackend
      ? StoreMenuRepository(ref.watch(menuDaoProvider))
      : const InMemoryMenuRepository(),
);

/// **La barre d'onglets de la médiathèque**, dans l'ordre réglé au portail.
///
/// Une liste **vide** n'est pas une erreur : c'est « aucun menu reçu » (avant le
/// premier cycle, ou sur un serveur en retard d'une version qui rend un `404`),
/// ou « le portail n'a rien allumé sur cette surface ». L'écran en tire son
/// onglet implicite — le catalogue entier —, et c'est écrit chez lui.
final mediaMenuProvider = StreamProvider<List<MenuEntryView>>(
  (ref) => ref.watch(menuRepositoryProvider).menu(
        MenuSurface.mediaLibrary,
        locale: ref.watch(contentLocaleProvider),
        now: ref.watch(nowProvider),
      ),
  retry: _noAutomaticRetry,
);

/// **Les sections de l'accueil pilotées par les menus.**
///
/// ⚠️ **Deux mécanismes coexistent, et la borne est ici** (cadrage § 14). Tant
/// que cette liste est **vide**, l'accueil reste piloté par les rubriques
/// (`teaching_types.visible_on_home` / `layout`, lus par `homeSectionsProvider`).
/// Dès qu'elle porte une entrée, **les menus font foi et les rubriques se
/// taisent** — et c'est `HomeScreen` qui applique la bascule, en un seul endroit.
///
/// Trois raisons à cette borne-là plutôt qu'à un drapeau :
///
/// 1. **l'état livré est le vide.** La graine du portail (`menu_seed.ts`) pose
///    `home_visible: false` sur les sept entrées reprises, et `mobile_home` n'est
///    pas une surface gardée — exiger une entrée pour une surface qu'aucun client
///    ne lisait aurait refusé le premier enregistrement de l'écran. Un appareil
///    qui monte de version avant que le portail n'ait rien réglé ne doit pas
///    perdre son accueil ;
/// 2. **mélanger les deux montrerait deux fois la même chose**, sous deux titres
///    réglés à deux endroits — exactement la divergence que la décision 12 du
///    cadrage interdit ;
/// 3. **la bascule se décide dans la donnée**, donc au portail, et elle
///    s'annule en décochant. Un drapeau compilé n'aurait ni l'un ni l'autre.
///
/// **Quand cela finit** : le jour où le serveur retire `visible_on_home` et
/// `layout` de `teaching_types` (la moitié serveur de cette tranche). Dès lors
/// `homeSections()` ne rend plus rien, le repli est mort, et il se retire — le
/// seul endroit qui réponde à « où et comment cela paraît » est le menu.
final homeMenuProvider = StreamProvider<List<MenuEntryView>>(
  (ref) => ref.watch(menuRepositoryProvider).menu(
        MenuSurface.home,
        locale: ref.watch(contentLocaleProvider),
        now: ref.watch(nowProvider),
      ),
  retry: _noAutomaticRetry,
);

/// **Les enseignements d'une destination de catalogue.**
///
/// Deux providers et non un paramétré par la famille — la règle du lot (ADR-0026
/// décision 1) : c'est ce qui rend impossible qu'un rassemblement se glisse dans
/// une liste d'enseignements. L'appelant choisit d'après
/// `MenuCatalogue.family` ; le provider, lui, ne lit qu'une collection.
///
/// **Deux destinations ne ramènent rien, et c'est voulu** : un slug de rubrique
/// que le magasin ne connaît pas, et un slug de **branche** — que ce client ne
/// sait pas résoudre, `BranchTransformer` n'en servant aucun. Rendre le catalogue
/// entier à la place serait le pire repli possible : un onglet « Prières » qui
/// montre tout le catalogue ment, et le visiteur ne peut pas le savoir. C'est la
/// doctrine du site public devant un `?rubrique=` inconnu, reprise telle quelle.
final menuTeachingsProvider =
    StreamProvider.family<List<TeachingView>, MenuCatalogue>(
  (ref, destination) {
    if (_matchesNothing(destination)) {
      return Stream.value(const <TeachingView>[]);
    }
    return ref.watch(mediathequeRepositoryProvider).teachingsMatching(
          locale: ref.watch(contentLocaleProvider),
          teachingTypeId: destination.rubricId,
          search: destination.search,
        );
  },
  retry: _noAutomaticRetry,
);

/// **Les rassemblements d'une destination de catalogue** — le pendant strict du
/// précédent, sur l'autre collection.
final menuGatheringsProvider =
    StreamProvider.family<List<GatheringView>, MenuCatalogue>(
  (ref, destination) {
    if (_matchesNothing(destination)) {
      return Stream.value(const <GatheringView>[]);
    }
    return ref.watch(gatheringRepositoryProvider).gatheringsMatching(
          locale: ref.watch(contentLocaleProvider),
          gatheringTypeId: destination.rubricId,
          search: destination.search,
        );
  },
  retry: _noAutomaticRetry,
);

/// Une borne demandée que le magasin ne sait pas honorer ⇒ **aucun contenu**.
bool _matchesNothing(MenuCatalogue destination) =>
    (destination.rubricSlug != null && destination.rubricId == null) ||
    destination.branchSlug != null;

/// **L'identifiant local d'une rubrique d'enseignement, depuis son slug.**
///
/// Le chemin du « Voir tout » réparé : une section d'accueil pousse la
/// médiathèque avec le **slug** de sa rubrique, et c'est ici qu'il redevient
/// l'identifiant que le magasin interroge. Un slug inconnu rend `null`, donc une
/// destination qui ne ramène rien — jamais le catalogue entier.
final teachingRubricIdProvider = StreamProvider.family<int?, String>(
  (ref, slug) => ref.watch(mediathequeRepositoryProvider).rubricIdOfSlug(slug),
  retry: _noAutomaticRetry,
);

/// **Le navigateur du système**, pour les destinations `externe`.
///
/// À surcharger par `RecordingExternalLinkLauncher` dans les tests. En service,
/// `url_launcher` (arrivé avec les médias de la messagerie, M4) ouvre le
/// navigateur du système.
final externalLinkLauncherProvider = Provider<ExternalLinkLauncher>(
  (ref) => const UrlLauncherExternalLinkLauncher(),
);
