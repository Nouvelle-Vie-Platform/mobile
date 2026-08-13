/// **Ce qu'un élément `<audio>` raconte, traduit en [ContentPlayback]** — et
/// rien d'autre.
///
/// Ce fichier ne touche **ni le DOM, ni `dart:js_interop`**. C'est délibéré, et
/// c'est la seule chose qui rend le lecteur web vérifiable : `flutter test`
/// tourne sur la VM, jamais dans un navigateur, donc aucun test ne peut
/// instancier un `<audio>`. Si les décisions vivaient dans le fichier de
/// l'interop, elles ne seraient couvertes que par un coup d'œil dans Chrome.
///
/// Toutes les décisions du lecteur web sont donc ici : ce qu'on fait d'une
/// durée `NaN`, d'un flux live, d'une position illisible, d'une fin de média
/// qu'un déplacement annule. `HlsContentPlayer` n'y ajoute que des câbles.
library;

import 'package:flutter/foundation.dart';

import 'content_player.dart';

/// **Une panne de lecture web**, portée telle quelle par
/// [ContentPlayback.error].
///
/// Volontairement **sans `operator ==`** : le contrat veut qu'« une panne
/// fraîche ne soit jamais égale à la précédente », pour qu'un réessai qui
/// échoue de la même façon se voie quand même à l'écran. Une chaîne de
/// caractères, elle, serait égale à la précédente et n'émettrait rien.
class MediaPlaybackError {
  MediaPlaybackError(this.source, this.detail);

  /// D'où vient la panne : l'élément média, `hls.js`, ou la demande de lecture.
  final String source;

  /// Ce qu'il y a à mettre au journal. L'UI n'en lit rien.
  final String detail;

  @override
  String toString() => 'MediaPlaybackError($source) : $detail';
}

/// **La machine à états du lecteur web**, sans navigateur.
///
/// Chaque méthode correspond à un événement de `HTMLMediaElement` — un
/// vocabulaire de média HTML, et non celui de `just_audio` : les deux moteurs
/// ne racontent pas la même chose, et lisser la différence ici reviendrait à la
/// cacher.
///
/// La correspondance avec l'implémentation mobile est **choisie**, pas subie :
/// `just_audio` distingue l'**intention** de lire (`playing`) de l'**état du
/// tampon** (`processingState`), et l'écran s'appuie sur cette distinction. Le
/// DOM la fait aussi, mais avec d'autres mots — `play` est l'intention,
/// `playing` le son qui sort, `waiting` le tampon vide.
///
/// Sous-classe de [ValueNotifier] : la valeur n'est republiée que lorsqu'elle
/// **change réellement**, `ContentPlayback` ayant un `operator ==` fidèle. Cela
/// compte, `timeupdate` battant plusieurs fois par seconde — même rythme et
/// même sémantique que sur mobile, dont l'écran de lecture dépend.
class MediaElementPlayback extends ValueNotifier<ContentPlayback> {
  MediaElementPlayback() : super(const ContentPlayback());

  bool _disposed = false;

  /// Vrai après [dispose] : toutes les entrées deviennent alors sans effet.
  ///
  /// Les événements du DOM continuent d'arriver un instant après le
  /// détachement d'une source — un `timeupdate` en vol ne doit pas faire lever
  /// un [ValueNotifier] déjà libéré.
  bool get isDisposed => _disposed;

  /// **Un chargement commence.**
  ///
  /// Valeur **neuve** et non `copyWith` : durée, fin atteinte et panne du
  /// contenu précédent doivent disparaître, et `copyWith` ne sait pas effacer.
  /// `isBuffering` dès maintenant — le manifeste HLS n'est pas encore lu, rien
  /// ne sortira avant plusieurs allers-retours réseau.
  void startLoading(String contentId) {
    _emit(ContentPlayback(contentId: contentId, isBuffering: true));
  }

  /// `timeupdate` — la tête de lecture a bougé.
  ///
  /// Ignore une valeur non finie plutôt que de la ramener à zéro : un
  /// `currentTime` illisible ne veut pas dire « retour au début », et l'écran
  /// dessinerait un recul qui n'a pas eu lieu.
  void updatePosition(double seconds) {
    final position = positionFromSeconds(seconds);
    if (position == null) return;
    _emit(value.copyWith(position: position));
  }

  /// `durationchange` / `loadedmetadata` — la durée du média est connue.
  ///
  /// **Ne remplace jamais une durée connue par « inconnue »** : au détachement
  /// d'une source, l'élément repasse par `NaN`, et la barre de l'écran
  /// sauterait en indéterminé au dernier instant d'un enseignement. Un nouveau
  /// chargement, lui, repart d'une valeur neuve — c'est [startLoading] qui
  /// efface.
  void updateDuration(double seconds) {
    final duration = durationFromSeconds(seconds);
    if (duration == null) return;
    _emit(value.copyWith(duration: duration));
  }

  /// `play` — **la lecture est demandée**, le son ne sort pas encore.
  ///
  /// C'est l'équivalent DOM du `playing` de `just_audio`, qui est une intention
  /// et non un constat. Ne touche pas au tampon : une reprise immédiate ne doit
  /// pas faire clignoter une barre indéterminée entre `play` et `playing`.
  void markPlayRequested() {
    _emit(value.copyWith(isPlaying: true, isCompleted: false));
  }

  /// `playing` — le son sort.
  ///
  /// Efface la fin atteinte : reprendre après la fin d'un enseignement est un
  /// geste courant, et laisser `isCompleted` à vrai figerait l'écran sur son
  /// rendu de fin pendant que la lecture avance.
  void markRendering() {
    _emit(
      value.copyWith(isPlaying: true, isBuffering: false, isCompleted: false),
    );
  }

  /// `waiting` — le média s'est arrêté faute de données.
  ///
  /// Ne touche pas à `isPlaying` : une attente n'est pas une décision, et la
  /// lecture reste demandée. C'est exactement la distinction que porte
  /// [ContentPlayback.isBuffering].
  void markWaiting() => _emit(value.copyWith(isBuffering: true));

  /// `canplay` / `seeked` — il y a de quoi jouer.
  void markReady() => _emit(value.copyWith(isBuffering: false));

  /// `pause` — la lecture est suspendue, la position reste.
  ///
  /// Ne touche pas au tampon : le navigateur émet aussi `pause` en fin de
  /// média, et [markEnded] est seul à décrire cette fin-là.
  void markPaused() => _emit(value.copyWith(isPlaying: false));

  /// `ended` — le média est arrivé à son terme.
  void markEnded() {
    _emit(
      value.copyWith(isPlaying: false, isBuffering: false, isCompleted: true),
    );
  }

  /// `error` de l'élément, panne **fatale** de `hls.js`, ou `play()` rejeté.
  ///
  /// Coupe la mise en tampon : rien n'arrive plus, et une barre indéterminée
  /// laisserait croire à une attente là où il y a un réessai à faire. Garde
  /// l'identifiant du contenu — l'écran doit pouvoir réessayer **le même**
  /// enseignement.
  void fail(MediaPlaybackError error) {
    _emit(value.copyWith(error: error, isBuffering: false, isPlaying: false));
  }

  /// Le média est relâché : la valeur repart à vide.
  void clear() => _emit(const ContentPlayback());

  /// **Le déplacement de la tête de lecture**, borné au média chargé.
  ///
  /// Rend les secondes à écrire dans `currentTime`, et pose déjà la position
  /// dans la valeur : le navigateur n'émettra `timeupdate` qu'après avoir
  /// cherché, et un curseur qui revient en arrière le temps de la recherche se
  /// voit à l'écran.
  ///
  /// Efface la fin atteinte, parce qu'un déplacement l'annule — c'est
  /// exactement ce que fait le média, qui remet `ended` à faux dès que
  /// `currentTime` change.
  double seekTo(Duration wanted) {
    final target = value.clampPosition(wanted);
    _emit(value.copyWith(position: target, isCompleted: false));
    return target.inMicroseconds / Duration.microsecondsPerSecond;
  }

  void _emit(ContentPlayback playback) {
    if (_disposed) return;
    value = playback;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }

  /// **Une durée de média HTML en [Duration], ou `null` quand elle est
  /// inconnue.**
  ///
  /// Trois cas rendent `null`, et aucun ne se convertit honnêtement :
  ///
  /// - `NaN` — l'élément n'a pas encore lu les métadonnées. C'est la valeur
  ///   qu'il porte pendant tout le début d'un chargement HLS ;
  /// - `Infinity` — un flux **live**, qui n'a pas de fin à afficher ;
  /// - une valeur négative ou nulle — aucun média réel ne dure zéro seconde ;
  ///   la rendre ferait dessiner une lecture terminée d'avance.
  ///
  /// Rendre `0` dans ces cas donnerait une barre pleine ou figée : c'est
  /// précisément ce que la nullabilité du contrat empêche.
  static Duration? durationFromSeconds(double seconds) {
    if (!seconds.isFinite || seconds <= 0) return null;
    return Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
  }

  /// **Une position de média HTML en [Duration], ou `null` si elle est
  /// illisible.**
  ///
  /// Une valeur négative se ramène à zéro — c'est une position, pas une
  /// information à jeter. Une valeur non finie, elle, ne dit rien du tout.
  static Duration? positionFromSeconds(double seconds) {
    if (!seconds.isFinite) return null;
    if (seconds <= 0) return Duration.zero;
    return Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
  }
}
