/// **Le lecteur de la médiathèque, derrière une abstraction** — le contrat, sa
/// valeur observable, et l'implémentation inerte des tests.
///
/// Même motif que `status_player.dart`, et pour une raison mesurée, pas par
/// goût de la symétrie : sous `flutter test`, il n'y a **pas de canal de
/// plugin**. Un `AudioPlayer` se construit sans broncher, mais `setUrl` **et**
/// `dispose` lèvent `MissingPluginException`, et l'initialisation de
/// l'arrière-plan produit une **erreur asynchrone non rattrapée** — celle-là
/// traverse le `try/catch` qui l'entoure et fait rougir des tests qui n'ont
/// rien demandé. **Le lecteur ne peut donc pas vivre dans un widget.**
///
/// Ce fichier ne connaît ni `just_audio` ni `audio_service` : c'est la
/// condition pour qu'il y ait un jour une troisième implémentation (le web, par
/// `hls.js`) sans qu'un seul écran change.
library;

import 'package:flutter/foundation.dart';

/// **Le pas des reculs et des avances rapides** — 30 secondes.
///
/// Écrit ici, une seule fois, parce qu'il vaut à trois endroits qui doivent
/// s'accorder : les boutons de l'écran de lecture, ceux de la notification
/// Android, et ceux de l'écran verrouillé iOS. Deux valeurs qui divergent
/// donnent un « −30 s » qui ne recule pas de trente secondes selon l'endroit où
/// on appuie — un défaut qu'aucun test d'écran ne verrait.
const Duration kContentSkipInterval = Duration(seconds: 30);

/// **Instantané de l'état de lecture d'un contenu.**
///
/// Valeur immuable : c'est le seul objet que l'UI observe. Aucun écran n'a
/// besoin de savoir quelle implémentation la produit.
///
/// L'égalité n'est pas décorative. La position émet **plusieurs fois par
/// seconde** : sans `operator ==` fidèle, chaque émission propagerait une valeur
/// « nouvelle » et tout écran abonné se reconstruirait en continu.
@immutable
class ContentPlayback {
  const ContentPlayback({
    this.contentId,
    this.position = Duration.zero,
    this.duration,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.error,
  });

  /// Identifiant du contenu chargé, `null` tant qu'aucun `load` n'a eu lieu.
  final String? contentId;

  /// Position courante de la tête de lecture.
  final Duration position;

  /// Durée du média, **`null` quand elle est inconnue**.
  ///
  /// Ce n'est pas une précaution de style : en HLS, la durée arrive après le
  /// manifeste, et sur iOS elle est peu fiable — elle peut rester nulle sur un
  /// flux entier. La rendre non nullable obligerait à inventer un zéro, que
  /// l'UI dessinerait comme un média de durée nulle.
  final Duration? duration;

  /// Vrai lorsque la lecture avance.
  final bool isPlaying;

  /// Vrai pendant la mise en tampon : le média est chargé, le son ne sort pas
  /// encore. À distinguer d'une pause — c'est une attente, pas une décision.
  final bool isBuffering;

  /// Vrai lorsque le média est arrivé à son terme.
  final bool isCompleted;

  /// La panne, ou `null`.
  ///
  /// Portée telle quelle : l'UI n'a besoin que de savoir qu'**il y a quelque
  /// chose à réessayer** ; l'objet sert au journal. Une panne fraîche n'est
  /// jamais égale à la précédente, et c'est voulu — un réessai qui échoue à
  /// nouveau doit se voir.
  final Object? error;

  /// Vrai quand la lecture est en panne.
  bool get hasError => error != null;

  /// Progression `0..1`, **`null` tant que la durée est inconnue**.
  ///
  /// `null` et `0` ne se dessinent pas pareil : une durée inconnue appelle une
  /// barre indéterminée, un zéro dessinerait une lecture figée au début.
  double? get progress {
    final total = duration;
    if (total == null) return null;
    if (total <= Duration.zero) return 0;
    return (position.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
  }

  /// Borne une position au média chargé.
  ///
  /// Toujours par le bas ; par le haut **seulement si la durée est connue**.
  /// Refuser d'avancer faute de durée reviendrait à priver iOS de l'avance
  /// rapide sur tout un flux HLS.
  Duration clampPosition(Duration wanted) {
    if (wanted < Duration.zero) return Duration.zero;
    final total = duration;
    if (total != null && wanted > total) return total;
    return wanted;
  }

  /// Copie modifiée. **Ne sait pas effacer** une durée ou une panne : pour
  /// repartir de rien, on construit une valeur neuve — c'est ce que fait
  /// `load`.
  ContentPlayback copyWith({
    String? contentId,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    Object? error,
  }) {
    return ContentPlayback(
      contentId: contentId ?? this.contentId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ContentPlayback &&
        other.contentId == contentId &&
        other.position == position &&
        other.duration == duration &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.isCompleted == isCompleted &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
        contentId,
        position,
        duration,
        isPlaying,
        isBuffering,
        isCompleted,
        error,
      );

  @override
  String toString() =>
      'ContentPlayback(contentId: $contentId, position: $position, '
      'duration: $duration, isPlaying: $isPlaying, isBuffering: $isBuffering, '
      'isCompleted: $isCompleted, error: $error)';
}

/// **Lecteur d'un contenu de médiathèque.**
///
/// Contrat unique dont dépend l'UI. Implémente [ValueListenable] pour que les
/// écrans se contentent d'observer : **l'horloge appartient au lecteur, jamais
/// au widget**. Une minuterie vivant dans le `State` d'un écran survivrait à
/// l'écrasement du provider et ferait échouer les tests sur « pending timer ».
///
/// Trois implémentations sont prévues derrière ce contrat, et le reste de
/// l'application ignore laquelle tourne : la réelle (`just_audio` +
/// `audio_service`), l'[InertContentPlayer] des tests, et un jour le web
/// (`hls.js` par interop JS, sans passer par `just_audio`).
///
/// `load` est le seul membre asynchrone : ouvrir un flux HLS **peut échouer**,
/// et l'appelant a le droit d'attendre le verdict. Les commandes de transport,
/// elles, ne se guettent pas — leur effet se lit dans [value].
abstract interface class ContentPlayer
    implements ValueListenable<ContentPlayback> {
  /// Charge un contenu et remet la lecture à zéro.
  ///
  /// [title] et [author] ne sont pas décoratifs : ce sont les lignes que le
  /// système affiche dans la notification et sur l'écran verrouillé. [artUrl]
  /// est la pochette, absente quand le contenu n'a pas de visuel.
  ///
  /// Charger **ne démarre pas** la lecture : ouvrir un enseignement ne doit pas
  /// faire sortir du son dans une salle de culte.
  Future<void> load({
    required String contentId,
    required String url,
    required String title,
    String? author,
    String? artUrl,
  });

  /// Démarre ou reprend la lecture.
  void play();

  /// Suspend la lecture en figeant la position.
  void pause();

  /// Déplace la tête de lecture (bornée par [ContentPlayback.clampPosition]).
  void seek(Duration position);

  /// Relâche le média : la valeur repart à vide, la notification disparaît.
  ///
  /// À distinguer de [dispose] — après `stop`, le lecteur peut encore charger.
  void stop();

  /// Libère les ressources. Sûr et idempotent.
  void dispose();
}

/// **Lecteur inerte, destiné aux tests d'écran** : aucune minuterie, aucun canal
/// de plugin, jamais.
///
/// [play] marque la lecture comme active pour que l'UI s'affiche dans son état
/// « en cours », mais **la position ne bouge pas d'elle-même** et le contenu ne
/// se termine jamais tout seul : l'écran reste « settleable », et aucun test ne
/// dépend du temps qui passe.
///
/// C'est aussi la valeur **par défaut** de `contentPlayerProvider` : le seul
/// lecteur qu'on puisse construire sans canal de plugin. La vraie
/// implémentation est injectée par le démarrage de l'application, chemin que
/// les tests ne prennent jamais.
class InertContentPlayer extends ValueNotifier<ContentPlayback>
    implements ContentPlayer {
  InertContentPlayer() : super(const ContentPlayback());

  bool _disposed = false;

  /// URL du média **actuellement tenu** — pour que les tests vérifient ce
  /// qu'on aurait joué, à défaut de le jouer. `null` après un [stop].
  @visibleForTesting
  String? loadedUrl;

  /// Titre **actuellement affiché par le système** : la notification, l'écran
  /// verrouillé.
  ///
  /// Il se vide sur [stop], comme la vraie implémentation vide son élément
  /// média. Ce n'est pas de la coquetterie de double : c'est le seul endroit où
  /// un test puisse constater qu'un contenu **retiré pendant l'écoute** cesse
  /// d'être annoncé au système. Sans lui, l'oubli resterait invisible — l'écran
  /// montrerait bien l'absence, et le titre continuerait de s'afficher sur
  /// l'écran verrouillé.
  @visibleForTesting
  String? loadedTitle;

  /// Nombre de chargements — un rechargement en boucle se voit ici.
  @visibleForTesting
  int loadCount = 0;

  /// Pose un état arbitraire, sans lecture réelle.
  ///
  /// C'est le pinceau des tests d'écran : une durée connue, une mise en tampon,
  /// une fin atteinte, une panne — chacun de ces rendus se demande ici, au lieu
  /// d'être attendu d'un média qui n'existe pas.
  @visibleForTesting
  void emit(ContentPlayback playback) {
    if (_disposed) return;
    value = playback;
  }

  @override
  Future<void> load({
    required String contentId,
    required String url,
    required String title,
    String? author,
    String? artUrl,
  }) async {
    if (_disposed) return;
    loadedUrl = url;
    loadedTitle = title;
    loadCount++;
    // Valeur **neuve** et non `copyWith` : c'est le seul moyen d'effacer une
    // durée, une fin atteinte ou une panne héritées du contenu précédent.
    value = ContentPlayback(contentId: contentId);
  }

  @override
  void play() {
    if (_disposed || value.isPlaying) return;
    value = value.copyWith(isPlaying: true);
  }

  @override
  void pause() {
    if (_disposed || !value.isPlaying) return;
    value = value.copyWith(isPlaying: false);
  }

  @override
  void seek(Duration position) {
    if (_disposed) return;
    value = value.copyWith(position: value.clampPosition(position));
  }

  @override
  void stop() {
    if (_disposed) return;
    // Le média est relâché **et** ce que le système affiche est vidé — c'est ce
    // que fait `ContentAudioHandler.stop()` avec `mediaItem.add(null)`.
    loadedUrl = null;
    loadedTitle = null;
    value = const ContentPlayback();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
