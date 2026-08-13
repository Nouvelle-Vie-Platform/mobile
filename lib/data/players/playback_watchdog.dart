/// **Le chien de garde d'une lecture qui se tait sans rien dire** — la panne
/// la plus coûteuse du lecteur, et la seule qui ne se signale nulle part.
///
/// Sur iOS, un décrochage réseau au milieu d'un prêche ne remonte **aucune
/// erreur** vers Dart, et il n'y a **pas de reconnexion native** (contrairement
/// à ExoPlayer sur Android). Le lecteur reste indéfiniment en mise en tampon,
/// position figée, sans que rien ne se plaigne : l'écoute meurt en silence, le
/// fidèle attend, puis referme l'application. Aucun test, aucun journal, aucun
/// rapport de plantage n'en portera jamais la trace.
///
/// La règle est donc applicative : **si la lecture est demandée, que le tampon
/// attend, et que la position n'a pas bougé pendant [kPlaybackStallTimeout],
/// on rouvre la source à la position courante.**
///
/// **Il vit dans le lecteur, jamais dans le `State` d'un widget.** Une
/// minuterie posée dans un écran survivrait à l'écrasement du provider et
/// ferait échouer les tests sur « pending timer » — c'est la raison écrite
/// dans le doc-comment de `StatusPlayer`, et elle vaut mot pour mot ici.
library;

import 'dart:async';

import 'content_player.dart';

/// **Le temps qu'on laisse à une lecture muette avant de la rouvrir.**
///
/// Écrit ici, une seule fois, et lu par les deux implémentations réelles du
/// contrat. Deux contraintes le bornent, et elles se resserrent :
///
/// - **assez long** pour ne pas casser une mise en tampon normale. Un
///   enseignement encodé à 64 kbps, tiré en 4G togolaise, met couramment
///   plusieurs secondes à reconstituer son tampon après un changement de
///   cellule. Rouvrir la source à ce moment-là remplacerait une attente qui
///   allait aboutir par une attente qui recommence ;
/// - **assez court** pour que le fidèle n'ait pas déjà renoncé. Au-delà d'une
///   demi-minute de silence, il a rangé son téléphone.
///
/// Vingt-cinq secondes : au moins trois fois une reprise de tampon normale, et
/// en deçà du seuil d'abandon. **Valeur à confirmer sur le terrain** — c'est
/// une estimation, pas une mesure.
const Duration kPlaybackStallTimeout = Duration(seconds: 25);

/// Surveille une suite de [ContentPlayback] et signale les décrochages.
///
/// Il ne connaît **ni lecteur ni source** : il reçoit des valeurs et rend une
/// position. C'est ce qui le rend vérifiable sans navigateur, sans canal de
/// plugin et sans iPhone — les trois choses que la panne qu'il corrige exige
/// par ailleurs.
class PlaybackWatchdog {
  PlaybackWatchdog({
    required this.onStalled,
    this.timeout = kPlaybackStallTimeout,
  });

  /// Rappelé avec la position figée. À charge de l'implémentation de rouvrir
  /// la source à cet endroit.
  final void Function(Duration at) onStalled;

  /// Le délai de silence toléré. Injectable pour les tests, jamais autrement :
  /// la valeur de production est [kPlaybackStallTimeout], et elle est unique.
  final Duration timeout;

  Timer? _timer;

  /// La position sur laquelle la minuterie en cours a été armée.
  Duration? _watched;

  bool _disposed = false;

  /// **Une émission du lecteur.** À appeler à chaque valeur, sans filtre.
  void observe(ContentPlayback playback) {
    if (_disposed) return;

    // Un décrochage ne se reconnaît qu'à trois choses réunies. Hors de là, une
    // position immobile est parfaitement normale — une pause, une fin
    // atteinte, un contenu chargé mais pas démarré — et rouvrir la source y
    // serait la panne, pas le remède.
    //
    // La panne **déjà déclarée** compte parmi les exclusions : l'écran affiche
    // alors « Reprendre », et recharger dans son dos ferait repartir le son
    // sans que personne ne l'ait demandé.
    final watching =
        playback.isPlaying && playback.isBuffering && !playback.hasError;
    if (!watching) {
      cancel();
      return;
    }

    // La position avance : le tampon se remplit lentement, mais il se remplit.
    // L'échéance repart de zéro.
    if (_timer != null && playback.position == _watched) return;
    _watched = playback.position;
    _arm();
  }

  /// Désarme sans rien signaler.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _watched = null;
  }

  /// Libère la minuterie. Sûr et idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(timeout, () {
      _timer = null;
      final at = _watched;
      if (_disposed || at == null) return;
      // **On ne renonce pas.** Un décrochage se répare quand le réseau
      // revient, et personne ne peut dire quand. La réouverture republie une
      // mise en tampon, donc réarme ce chien de garde : la tentative se répète
      // tant que le silence dure. Quelques requêtes toutes les vingt-cinq
      // secondes contre une écoute morte, le compte est vite fait.
      onStalled(at);
    });
  }
}
