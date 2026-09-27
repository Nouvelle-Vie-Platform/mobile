/// **La mesure d'audience, côté providers.**
///
/// Deux entrées, et une seule parle au réseau — la même discipline que l'onglet
/// Annonces et que la reprise de lecture.
///
/// Ce fichier est **délibérément séparé** de `playback_progress_providers.dart`,
/// alors que les deux servent le même écran. Les mélanger aurait donné un seul
/// fichier où une surcharge de test pour la reprise de lecture aurait pu, par
/// étourderie, faire taire la mesure — ou l'inverse. La séparation des deux
/// contrats est la chose que cette tranche doit garder vraie ; elle commence
/// ici.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/measurement/http_play_reporter.dart';
import '../data/measurement/play_reporter.dart';
import '../data/measurement/play_spool.dart';
import '../data/measurement/play_tracker.dart';
import 'theme_provider.dart' show settingsDaoProvider;

/// **Le rapporteur** — le seul provider de ce fichier qui parle au réseau.
///
/// Sans backend, un rapporteur **inerte** : rien ne part sur un fil qui n'existe
/// pas, et la file d'attente ne se remplit pas d'événements qui ne partiraient
/// jamais. Le drapeau se lit **ici et non dans l'écran**, comme partout ailleurs
/// dans `lib/state/`.
final playReporterProvider = Provider<PlayReporter>(
  (ref) => AppEnv.useBackend ? HttpPlayReporter() : const InertPlayReporter(),
);

/// **La file des écoutes qui n'ont pas pu partir**, rangée dans `app_settings`.
final playSpoolProvider = Provider<PlaySpool>(
  (ref) => SettingsPlaySpool(ref.watch(settingsDaoProvider)),
);

/// **Ouvre un traqueur** pour un contenu — enseignement ou rassemblement.
///
/// Une fonction plutôt qu'un `family`, pour la raison exacte de
/// `playbackProgressRecorderProvider` : un traqueur porte l'état d'**une session
/// d'écoute** (temps joué, écoute déjà émise), pas une donnée partagée. Le garder
/// en cache le ferait survivre à la fermeture de l'écran et repartir avec un
/// compteur périmé — donc ne plus jamais compter la seconde ouverture du même
/// prêche, ce qui est précisément le contraire de ce qu'on mesure.
final playTrackerProvider =
    Provider<PlayTracker Function(String contentId)>((ref) {
  return (contentId) => PlayTracker.open(
        reporter: ref.read(playReporterProvider),
        spool: ref.read(playSpoolProvider),
        contentId: contentId,
      );
});
