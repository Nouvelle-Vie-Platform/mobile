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
/// Le vertical d'abord, le paysage en secours : une saison peut n'avoir déposé
/// que le paysage, et une image recadrée reste préférable à un aplat.
final seasonBackgroundUrlProvider = FutureProvider<String?>((ref) async {
  final dao = ref.watch(seasonDaoProvider);
  final row =
      await dao.seasonOfDay(ref.watch(seasonDayProvider)).getSingleOrNull();
  if (row == null) return null;
  return resolveMediaUrl(row.backgroundVerticalUrl ?? row.backgroundUrl);
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
