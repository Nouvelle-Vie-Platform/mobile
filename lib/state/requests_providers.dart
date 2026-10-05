/// **Mes requêtes** (#148) — l'onglet « Requêtes » de la page Échanges.
///
/// Même découpage que la rubrique Échanges : une **lecture** adossée au magasin,
/// clée sur l'acteur, et **un seul** provider qui parle au réseau — l'envoi.
///
/// L'acteur entre par un **paramètre de famille**, jamais par `ref.watch` sur
/// `authProvider` : voir l'en-tête d'`echanges_providers.dart`, qui dit quelle
/// panne cette forme évite au retour du parcours de connexion. Les écrans lisent
/// `echangesActorProvider` et le passent en clé.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/http_request_submitter.dart';
import '../data/repositories/my_requests_repository.dart';
import '../models/my_request_view.dart';
import 'sync_providers.dart';

/// Aucun réessai automatique : un échec de lecture du magasin est une base
/// illisible, pas une intermittence (même politique que la médiathèque).
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// La lecture de mes requêtes **pour un acteur donné** : le magasin avec backend
/// et une session, le double vide sinon — le serveur ne sert jamais cette
/// collection privée à un porteur sans compte.
final myRequestsRepositoryProvider =
    Provider.family<MyRequestsRepository, String?>((ref, actor) {
  if (!AppEnv.useBackend || actor == null) {
    return InMemoryMyRequestsRepository();
  }
  return StoreMyRequestsRepository(
    ref.watch(interactionDaoProvider),
    userId: actor,
  );
});

/// **Mes requêtes**, les plus récentes d'abord.
final myRequestsProvider = StreamProvider.family<List<MyRequestView>, String?>(
  (ref, actor) => ref.watch(myRequestsRepositoryProvider(actor)).mine(),
  retry: _noAutomaticRetry,
);

/// **Le seul provider de cet onglet qui parle au réseau** : `POST /interactions`.
/// Il n'écrit rien dans le magasin — l'écran déclenche ensuite un cycle, qui
/// ramène la ligne.
final requestSubmitterProvider = Provider<RequestSubmitter>(
  (ref) => AppEnv.useBackend
      ? HttpRequestSubmitter()
      : const UnavailableRequestSubmitter(),
);
