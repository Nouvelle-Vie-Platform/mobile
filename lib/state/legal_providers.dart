import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/http_legal_acceptance_recorder.dart';
import '../data/repositories/legal_acceptance_recorder.dart';
import '../data/repositories/legal_repository.dart';
import '../data/repositories/store_legal_repository.dart';
import '../models/legal_document_view.dart';
import 'auth_providers.dart';
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

/// L'**écriture** du consentement — `POST /legal/accept`, le seul endroit de ce
/// domaine qui parle au réseau.
///
/// Sans backend, l'enregistreur refuse tout et le dit : il n'y a rien à quoi
/// bouchonner, l'accord exige le réseau (ADR-0036, décision 2).
final legalAcceptanceRecorderProvider = Provider<LegalAcceptanceRecorder>(
  (ref) => AppEnv.useBackend
      ? HttpLegalAcceptanceRecorder()
      : const UnavailableLegalAcceptanceRecorder(),
);

/// **Les planchers d'acceptation exigés**, par genre, lus de la ligne courante
/// du magasin — `{ 'cgu': 3 }` quand seule la CGU en exige un.
///
/// Lecture **synchrone**, et c'est tout l'objet de ce provider : la garde de
/// route ne peut ni attendre un `Future` ni attendre un `AsyncValue` en cours
/// de chargement (ADR-0036, décision 1). On lit donc `AsyncValue.value` — la
/// dernière valeur connue du flux, ou rien, sans jamais lever.
///
/// **Une absence de document ne bloque pas.** Magasin vide, première synchro
/// pas encore passée, flux encore en chargement, serveur qui ne sert pas encore
/// de documents : pas de plancher, donc pas d'entrée dans cette carte, donc pas
/// de barrière. Une garde qui bloquerait sur une absence transformerait le
/// premier lancement en écran mort.
///
/// **`about` n'y entre jamais** : la boucle parcourt
/// [LegalDocumentKind.acceptable], pas les trois genres.
final mandatoryLegalVersionsProvider = Provider<Map<String, int>>((ref) {
  return {
    for (final kind in LegalDocumentKind.acceptable)
      if (ref.watch(legalDocumentProvider(kind)).value?.lastMandatoryVersion
          case final floor?)
        kind: floor,
  };
});

/// **Les genres que l'utilisateur courant doit encore accepter** — vide = pas
/// de barrière.
///
/// C'est la valeur que lit la garde de route, et la liste que peint l'écran :
/// une case par entrée. Si seule la politique a changé, il y a une entrée, donc
/// une case et un document.
final pendingLegalAcceptancesProvider = Provider<List<String>>((ref) {
  // **Les planchers d'abord, et sans condition** — y compris quand personne
  // n'est connecté. L'ordre de ces deux lignes est le seul endroit de ce
  // fichier où l'on peut se tromper en silence : un `return` anticipé sur
  // l'utilisateur nul laisserait ce provider sans dépendance vers le magasin
  // pendant tout le démarrage (la session s'ouvre après), et rien ne le
  // rebrancherait — la barrière n'apparaîtrait qu'à la navigation suivante.
  final mandatory = ref.watch(mandatoryLegalVersionsProvider);
  final user = ref.watch(authProvider).user;
  // Personne de connecté : la question ne se pose pas. Elle se posera à la
  // seconde où une session s'ouvrira, avec le résumé que le serveur y aura mis.
  if (user == null) return const [];
  return pendingLegalAcceptances(
    mandatory: mandatory,
    accepted: user.acceptedLegal,
  );
});

/// La comparaison, écrite une fois : `accepted[kind] < mandatory[kind]`.
///
/// **Une absence d'acceptation bloque** dès qu'un plancher existe.
/// `acceptedLegal` ne porte pas de `0` — un genre jamais accepté est *absent*
/// de la carte —, et le `?? 0` ci-dessous est la lecture de cette absence :
/// « jamais accepté », jamais « version zéro ». Les deux se ressembleraient à
/// la lecture ; une seule existe.
///
/// L'ordre de sortie est celui des planchers, donc celui de
/// [LegalDocumentKind.acceptable] : la CGU avant la politique, à l'écran comme
/// dans le corps envoyé au serveur.
List<String> pendingLegalAcceptances({
  required Map<String, int> mandatory,
  required Map<String, int> accepted,
}) {
  return [
    for (final entry in mandatory.entries)
      if ((accepted[entry.key] ?? 0) < entry.value) entry.key,
  ];
}
