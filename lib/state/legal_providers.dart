import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/legal_repository.dart';
import '../data/repositories/store_legal_repository.dart';
import '../models/legal_document_view.dart';
import 'locale_providers.dart';
import 'sync_providers.dart';

/// Politique de réessai des providers de documents légaux : **aucun réessai
/// automatique**, mêmes raisons que la médiathèque et l'agenda.
///
/// Riverpod 3 réessaie tout seul un provider en échec, jusqu'à dix fois avec
/// une attente qui double. Sur une lecture de **magasin local**, un échec n'est
/// pas une intermittence de réseau qu'attendre pourrait résoudre : c'est une
/// base illisible. Insister ne ferait que retarder l'aveu.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Fournit l'implémentation courante de [LegalRepository].
///
/// Avec backend : le **magasin local**, que la synchronisation alimente. C'est
/// ce qui rend une CGU lisible hors ligne, et c'est tout le motif d'en avoir
/// fait une collection répliquée plutôt qu'un `GET /legal/:kind`.
///
/// Sans backend (`AppEnv.useBackend` faux) : le double en mémoire adossé à
/// `SampleData`, qui applique **les mêmes règles de lecture** — repli en bloc
/// compris.
final legalRepositoryProvider = Provider<LegalRepository>(
  (ref) => AppEnv.useBackend
      ? StoreLegalRepository(ref.watch(legalDaoProvider))
      : InMemoryLegalRepository(),
);

/// Le document d'un genre (`cgu`, `privacy`, `about`), **déjà replié dans une
/// seule langue**.
///
/// Un `StreamProvider`, donc un `AsyncValue` côté écran — et un flux, pas une
/// valeur figée : une révision publiée pendant la lecture arrive par le flux
/// delta et doit remplacer le texte de l'écran ouvert. Sur un document qu'on
/// demandera bientôt d'accepter (#56), une copie figée serait la preuve
/// horodatée d'un accord donné sur un texte périmé.
///
/// `null` n'est pas une erreur : c'est `ContentAbsence.notSynced`.
final legalDocumentProvider = StreamProvider.family<LegalDocumentView?, String>(
  (ref, kind) => ref.watch(legalRepositoryProvider).documentOfKind(
        kind,
        locale: ref.watch(contentLocaleProvider),
      ),
  retry: _noAutomaticRetry,
);
