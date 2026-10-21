/// **La reprise de lecture, côté providers** (issue #43).
///
/// Trois entrées, et une seule parle au réseau — comme l'onglet Annonces, où
/// `announcementComposerProvider` est le seul provider d'écriture.
///
/// Ce fichier ne connaît **aucun lecteur**. Le branchement des cinq
/// déclencheurs sur le lecteur appartient au contrôleur global
/// (`PlaybackController`, #115), qui suit ce qui est chargé quel que soit
/// l'écran : ici, on fournit de quoi ouvrir un enregistreur, et
/// l'enregistreur se pilote depuis un test sans qu'aucun son ne soit joué.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/http_playback_progress_reporter.dart';
import '../data/repositories/playback_progress_recorder.dart';
import '../data/repositories/playback_progress_reporter.dart';
import 'sync_providers.dart';

/// **Le rapporteur** — le seul provider de ce fichier qui parle au réseau.
///
/// Sans backend, un rapporteur **inerte** : la position à chaud continue d'être
/// écrite localement, donc la reprise marche en mode maquette, et rien ne part
/// sur un fil qui n'existe pas. Le drapeau se lit **ici et non dans l'écran**,
/// comme partout ailleurs dans `lib/state/`.
final playbackProgressReporterProvider = Provider<PlaybackProgressReporter>(
  (ref) => AppEnv.useBackend
      ? HttpPlaybackProgressReporter()
      : const _InertPlaybackProgressReporter(),
);

/// **Ouvre un enregistreur** pour un contenu — enseignement ou rassemblement.
///
/// Une fonction plutôt qu'un `family` : un enregistreur porte l'état d'**une
/// session d'écoute** (position, temps joué depuis le dernier rapport,
/// complétion), pas une donnée partagée. Le garder en cache le ferait survivre
/// au contenu qu'il suit et repartir avec un compteur périmé — exactement
/// le genre d'état résiduel que la convention du dépôt écarte (« Riverpod =
/// état **partagé** »).
///
/// L'appelant — le contrôleur global, et lui seul — garde l'objet rendu tant
/// que le contenu est chargé, lui pousse la position, et l'informe des quatre
/// événements.
///
/// [partialSource] dit que la source jouée est un `.aac` **incomplet** (#228) :
/// l'enregistreur n'en marquera alors jamais « écouté », la fin manquant. Le
/// contrôleur le tranche au chargement, parce que lui seul sait quelle source
/// est réellement ouverte.
final playbackProgressRecorderProvider = Provider<
    Future<PlaybackProgressRecorder> Function(
      String contentId, {
      bool partialSource,
    })>(
  (ref) =>
      (contentId, {partialSource = false}) => PlaybackProgressRecorder.open(
            dao: ref.read(playbackDaoProvider),
            reporter: ref.read(playbackProgressReporterProvider),
            contentId: contentId,
            partialSource: partialSource,
          ),
);

/// Rapporteur de mode maquette : il accepte tout et n'envoie rien.
///
/// Rend `true` — « c'est parti » — délibérément : sans backend il n'y a rien à
/// retenter, et rendre `false` ferait retenter l'enregistreur à chaque
/// déclencheur pour l'éternité.
class _InertPlaybackProgressReporter implements PlaybackProgressReporter {
  const _InertPlaybackProgressReporter();

  @override
  Future<bool> report(PlaybackProgressReport report) async => true;
}
