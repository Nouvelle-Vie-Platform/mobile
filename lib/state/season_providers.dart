/// **Le fond des deux lecteurs** — la saison du jour, et son image sur le
/// disque.
///
/// La chaîne tient en trois maillons, et chacun peut rendre `null` sans que
/// rien ne casse : pas de saison aujourd'hui → pas d'adresse → pas de fichier
/// → le lecteur garde son aplat de couleur, exactement comme avant cette
/// fonctionnalité.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/backgrounds/season_background_store.dart';
import '../data/local/season_dao.dart';
import '../utils/media_url.dart';
import 'sync_providers.dart';

/// Le magasin de fonds sur disque.
///
/// Sans backend (`AppEnv.useBackend` faux) : le double inerte, comme partout
/// ailleurs dans ce dépôt. Voir `FileSeasonBackgroundStore.network` pour ce que
/// « réel » veut dire ici, et pourquoi le `Dio` y est nu.
final seasonBackgroundStoreProvider = Provider<SeasonBackgroundStore>(
  (ref) => AppEnv.useBackend
      ? FileSeasonBackgroundStore.network()
      : const InertSeasonBackgroundStore(),
);

/// **Le jour qu'il est**, injectable.
///
/// Séparé pour que la bascule de saison se teste sans attendre Noël. Le même
/// motif que `nowProvider` dans les réglages d'apparence.
final seasonDayProvider = Provider<String>(
  (ref) => seasonDay(DateTime.now()),
);

/// L'adresse du fond à poser aujourd'hui, **résolue** contre l'hôte de l'API.
///
/// ## Quatre étages, et l'ordre est la règle
///
/// 1. le **vertical de la saison** du jour ;
/// 2. son **paysage**, si elle n'a pas déposé de vertical ;
/// 3. le **vertical du décor** par défaut, hors saison ;
/// 4. son **paysage**.
///
/// Au-delà, `null` : l'appelant retombe sur l'image de son propre dépôt, puis
/// sur l'aplat de couleur du contenu. C'est la cascade du site public, à ceci
/// près que le premier étage y est le fond de l'enseignement — que le mobile ne
/// sert pas, parce que le direct n'aurait rien à y mettre.
///
/// **Le paysage en secours plutôt que l'étage suivant** : une image mal cadrée
/// reste plus informative qu'un aplat, et c'est déjà la règle de
/// `landscapeOrPortrait` sur les visuels de contenu.
final seasonBackgroundUrlProvider = FutureProvider<String?>((ref) async {
  final dao = ref.watch(seasonDaoProvider);

  final season =
      await dao.seasonOfDay(ref.watch(seasonDayProvider)).getSingleOrNull();
  if (season != null) {
    final url =
        resolveMediaUrl(season.backgroundVerticalUrl ?? season.backgroundUrl);
    if (url != null) return url;
  }

  // Hors saison — ou saison sans image, ce que le serveur n'autorise pas mais
  // que le magasin n'a pas à supposer.
  final decor = await dao.defaultDecor().getSingleOrNull();
  if (decor == null) return null;
  return resolveMediaUrl(decor.backgroundVerticalUrl ?? decor.backgroundUrl);
});

/// **Le fond, prêt à peindre** — un fichier local, jamais une adresse.
///
/// C'est ici que se tient l'exigence : la première ouverture descend l'image,
/// toutes les suivantes la lisent sur le disque. Le provider n'est pas
/// `autoDispose` : le lecteur se ferme et se rouvre souvent, et refaire la
/// lecture du magasin à chaque ouverture ne servirait à rien.
///
/// **Pas de réessai automatique** — même parti pris que l'agenda et la
/// médiathèque. [SeasonBackgroundStore.ensureLocal] ne lève jamais, si bien
/// qu'un échec se présente ici comme un `null` : il n'y a rien à retenter en
/// boucle, et la prochaine ouverture du lecteur refera la tentative.
final seasonBackgroundProvider = FutureProvider<ImageProvider?>((ref) async {
  final url = await ref.watch(seasonBackgroundUrlProvider.future);
  final file = await ref.watch(seasonBackgroundStoreProvider).ensureLocal(url);
  return file == null ? null : FileImage(file);
});

/// **Le fond déjà sur le disque au lancement**, posé par `main()`.
///
/// L'écran de démarrage ne peut pas attendre : il dure le temps de résoudre une
/// session, et un fond qui arriverait après lui n'aurait servi à personne. La
/// lecture est donc remontée dans `main()` — comme celle du coffre — et passée
/// ici en surcharge de provider.
///
/// `null` est l'état **normal du premier lancement** : rien n'a encore été
/// descendu. Le fond apparaît à l'ouverture suivante, et c'est exactement le
/// contrat demandé.
///
/// **Le défaut est `null`, jamais une exception.** Un provider de démarrage qui
/// lèverait hors surcharge ferait rougir tout test d'écran montant la coquille,
/// pour un décor — et c'est la coquille entière qu'il faudrait alors surcharger.
final startupBackgroundProvider = Provider<ImageProvider?>((ref) => null);

/// Lit le fond **déjà sur le disque**, pour `main()`.
///
/// Ni réseau ni base de données : le dossier de cache ne contient qu'un
/// fichier, et c'est ce qui permet de le retrouver sans connaître son adresse.
/// Un premier lancement rend `null`, ce qui est le contrat — le fond apparaît à
/// l'ouverture suivante.
Future<ImageProvider?> readStartupBackground() async {
  final file = await FileSeasonBackgroundStore.network().cachedFile();
  return file == null ? null : FileImage(file);
}
