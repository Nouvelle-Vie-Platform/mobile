/// **Le contrôleur global de lecture — le seul point d'entrée du transport**
/// (#114).
///
/// Charger, lire, mettre en pause, sauter de ±30 s, arrêter, rejouer, reprendre
/// après une panne : tout geste qui **commande** le lecteur passe par ici, d'où
/// qu'il vienne — la fiche d'un enseignement (`ContentPlayerView`), les cartes
/// de l'accueil (`playHomeContent`), l'antenne (`RadioListening`), et demain le
/// mini-lecteur (#116). Observer le lecteur reste libre :
/// `contentPlaybackProvider`, par `select`, comme avant.
///
/// La règle était écrite sur un widget — « `ContentPlayerView` est le seul
/// endroit qui pilote le lecteur » — et un widget ne peut pas la tenir :
/// `playHomeContent` y dérogeait déjà, et un mini-lecteur présent sur tous les
/// écrans y aurait dérogé à son tour. Elle vit donc ici, sur un provider qui
/// survit à tous les écrans.
///
/// Ce que ce contrôleur **ne** fait **pas encore** : suivre la position de
/// reprise et compter l'écoute. Les deux restent attachés à la fiche jusqu'à
/// #115, qui les fera passer ici.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/players/content_player.dart';
import 'player_providers.dart';

/// **Le contrôleur, et la requête courante qu'il publie.**
///
/// Jamais `autoDispose`, pour la raison de `contentPlayerProvider` : la lecture
/// survit à l'écran qui l'a lancée, donc ce qui la pilote aussi.
///
/// Sa valeur est la [ContentRequest] du contenu chargé — identifiant, titre,
/// auteur, image, direct ou non —, `null` quand rien n'est chargé ou après un
/// arrêt. C'est ce que lira le mini-lecteur : `ContentPlayback` ne porte ni
/// titre, ni auteur, ni image, et on ne les retrouve pas depuis l'identifiant —
/// la radio n'est pas un enseignement du magasin.
final playbackControllerProvider =
    NotifierProvider<PlaybackController, ContentRequest?>(
  PlaybackController.new,
);

class PlaybackController extends Notifier<ContentRequest?> {
  /// **La requête est retenue par le contrôleur, pas demandée au lecteur.**
  ///
  /// Les trois lecteurs la retiennent déjà, mais en privé, pour leurs
  /// réouvertures. La publier aurait élargi le contrat et touché les trois
  /// implémentations — dont deux qu'aucun test ne monte — pour une information
  /// que le contrôleur possède déjà, puisque tout chargement passe par lui.
  ///
  /// ⚠️ **Le lecteur reste juge de ce qu'il tient.** Dès que son `contentId`
  /// cesse d'être celui de la requête — un arrêt, ou un chargement qui n'est pas
  /// passé par ici —, la requête retombe à `null`. Une requête périmée afficherait
  /// le titre d'un prêche qui ne joue plus ; une requête absente n'affiche rien,
  /// ce qui est la panne la moins grave des deux.
  @override
  ContentRequest? build() {
    ref.listen<String?>(
      contentPlaybackProvider.select((playback) => playback.contentId),
      (_, contentId) {
        final request = state;
        if (request != null && request.contentId != contentId) state = null;
      },
    );
    return null;
  }

  ContentPlayer get _player => ref.read(contentPlayerProvider);

  /// L'état du lecteur **à cet instant** — pour l'appelant qui doit le relire
  /// après un `await`, quand son propre `ref` n'est peut-être plus monté.
  ///
  /// Lire n'est pas piloter : un widget qui s'y abonne passe par
  /// `contentPlaybackProvider`, et par `select`.
  ContentPlayback get playback => _player.value;

  /// **Charge un contenu, sans le jouer** — la requête est publiée avant que le
  /// lecteur ne parle, pour qu'aucune émission ne la trouve en retard.
  ///
  /// Tout ce que porte [request] descend au lecteur, en-têtes compris : c'est
  /// le chemin du cookie de l'antenne (#108), et le perdre ici rendrait la radio
  /// muette sans qu'aucun écran ne le montre.
  Future<void> load(ContentRequest request) {
    state = request;
    return _player.load(
      contentId: request.contentId,
      url: request.url,
      title: request.title,
      author: request.author,
      artUrl: request.artUrl,
      localFilePath: request.filePath,
      isLive: request.isLive,
      headers: request.headers,
    );
  }

  /// Démarre ou reprend la lecture.
  void play() => _player.play();

  /// Suspend la lecture en figeant la position.
  void pause() => _player.pause();

  /// Déplace la tête de lecture ; le lecteur la borne au média.
  void seek(Duration position) => _player.seek(position);

  /// Recule de [kContentSkipInterval] — le pas de la notification et de
  /// l'écran verrouillé, et aucun autre.
  ///
  /// Sans effet sur un direct, comme sur l'écran verrouillé : la fenêtre de
  /// l'antenne ne porte que quarante secondes de rattrapage.
  void skipBackward() => _skip(-kContentSkipInterval);

  /// Avance de [kContentSkipInterval]. Sans effet sur un direct.
  void skipForward() => _skip(kContentSkipInterval);

  void _skip(Duration delta) {
    if (state?.isLive ?? false) return;
    final player = _player;
    player.seek(player.value.position + delta);
  }

  /// **Relâche le média** : le son s'arrête, la notification disparaît, et la
  /// requête courante retombe à `null`.
  void stop() {
    state = null;
    _player.stop();
  }

  /// **Rejoue depuis le début** — le geste de la fin de lecture.
  void replay() {
    final player = _player;
    player.seek(Duration.zero);
    player.play();
  }

  /// **Repart d'une panne à la position atteinte**, jamais du début : c'est la
  /// promesse du bouton « Reprendre » (#42).
  Future<void> resume() => _player.resume();
}
