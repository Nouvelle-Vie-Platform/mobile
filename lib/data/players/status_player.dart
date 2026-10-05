import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size, Widget;

/// Durées d'affichage par défaut d'un statut, dernier maillon de la chaîne de
/// résolution : durée réelle du lecteur → durée mesurée par le transcodeur
/// (`mediaDurationMs`) → défaut par type. Voir [effectiveStatusDuration].
abstract final class StatusDurations {
  /// Statut sans média temporel (texte, image).
  static const Duration still = Duration(seconds: 5);

  /// Statut porteur d'un média temporel (audio, vidéo).
  static const Duration media = Duration(seconds: 30);
}

/// **La durée effective d'un statut — la chaîne écrite une fois** (§4.2 de
/// `docs/statuts-annonces.md`) :
///
/// 1. la durée **réelle** que le lecteur a lue dans le média ([real]) ;
/// 2. sinon la durée **mesurée par le transcodeur** et servie
///    ([announcedMs], `mediaDurationMs`) ;
/// 3. sinon le défaut par type ([StatusDurations]) — 30 s avec un média,
///    5 s sans.
///
/// Une durée nulle ou négative ne compte pour aucun des deux premiers
/// maillons : elle finirait le statut à la seconde où il commence.
///
/// Le lecteur réel l'appelle quand le média lui dit sa durée ; l'écran
/// l'appelle **sans** [real] pour la durée de repli qu'il passe à
/// [StatusPlayer.load]. Deux appelants, une seule règle.
Duration effectiveStatusDuration({
  Duration? real,
  int? announcedMs,
  required bool hasMedia,
}) {
  if (real != null && real > Duration.zero) return real;
  if (announcedMs != null && announcedMs > 0) {
    return Duration(milliseconds: announcedMs);
  }
  return hasMedia ? StatusDurations.media : StatusDurations.still;
}

/// Ce que le lecteur doit jouer pour un statut : **rien** (`null` — texte,
/// image), un son, ou une vidéo (qui porte son son).
enum StatusMediaKind { audio, video }

/// Instantané de l'état de lecture d'un statut.
///
/// Valeur immuable : c'est le seul objet que l'UI observe. Aucun écran n'a
/// besoin de connaître l'implémentation du lecteur qui la produit.
@immutable
class StatusPlayback {
  const StatusPlayback({
    this.statusId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isCompleted = false,
    this.videoSize,
    this.hasVideoFrame = false,
  });

  /// Identifiant du statut chargé, `null` tant qu'aucun `load` n'a eu lieu.
  final String? statusId;

  /// Position courante de la tête de lecture.
  final Duration position;

  /// Durée effective retenue pour ce statut (voir [StatusDurations]).
  final Duration duration;

  /// Vrai lorsque la lecture avance.
  final bool isPlaying;

  /// Vrai lorsque la lecture a atteint [duration] (le statut est terminé).
  final bool isCompleted;

  /// Dimensions **natives** de la vidéo chargée, `null` tant qu'elle ne les a
  /// pas dites (ou pour un statut sans vidéo). C'est ce qui décide du cadrage :
  /// une vidéo verticale occupe le fond, une horizontale est gardée entière
  /// (`statusVideoFraming`).
  final Size? videoSize;

  /// Vrai dès que la vidéo a une **image à montrer**. Jusque-là, c'est
  /// l'affiche qui couvre le chargement : un carré noir à la place d'un poster
  /// serait la seule chose que verrait un fidèle sur un réseau lent.
  final bool hasVideoFrame;

  /// Progression 0..1 (0 si [duration] est nulle).
  double get progress {
    if (duration <= Duration.zero) return 0;
    final ratio = position.inMicroseconds / duration.inMicroseconds;
    return ratio.clamp(0.0, 1.0);
  }

  StatusPlayback copyWith({
    String? statusId,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isCompleted,
    Size? videoSize,
    bool? hasVideoFrame,
  }) {
    return StatusPlayback(
      statusId: statusId ?? this.statusId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isCompleted: isCompleted ?? this.isCompleted,
      videoSize: videoSize ?? this.videoSize,
      hasVideoFrame: hasVideoFrame ?? this.hasVideoFrame,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StatusPlayback &&
        other.statusId == statusId &&
        other.position == position &&
        other.duration == duration &&
        other.isPlaying == isPlaying &&
        other.isCompleted == isCompleted &&
        other.videoSize == videoSize &&
        other.hasVideoFrame == hasVideoFrame;
  }

  @override
  int get hashCode => Object.hash(statusId, position, duration, isPlaying,
      isCompleted, videoSize, hasVideoFrame);

  @override
  String toString() =>
      'StatusPlayback(statusId: $statusId, position: $position, '
      'duration: $duration, isPlaying: $isPlaying, isCompleted: $isCompleted, '
      'videoSize: $videoSize, hasVideoFrame: $hasVideoFrame)';
}

/// Lecteur d'un statut.
///
/// Contrat unique dont dépend l'UI, sur le modèle de `ChurchRepository` :
/// `just_audio` et `video_player` sont branchés derrière lui
/// (`MediaStatusPlayer`, #130) par `main.dart`, **sans qu'aucun écran ne
/// sache lequel tourne**.
///
/// Implémente [ValueListenable] pour que l'UI se contente d'un
/// [ValueListenableBuilder] : **l'horloge et l'auto-avance appartiennent au
/// lecteur, jamais au widget**. Un `Timer` vivant dans le `State` d'un écran
/// survivrait à l'override du provider et ferait échouer les tests sur
/// « pending timer ».
abstract interface class StatusPlayer
    implements ValueListenable<StatusPlayback> {
  /// Charge un statut et remet la lecture à zéro.
  ///
  /// [mediaKind] dit ce que [mediaUrl] désigne ; `null` (ou une URL absente)
  /// = un statut sans média, que seule l'horloge fait avancer.
  ///
  /// [fallbackDuration] s'applique tant que le média n'a pas dit la sienne, et
  /// pour toujours s'il ne la dit jamais (chaîne de résolution :
  /// [effectiveStatusDuration]).
  void load({
    required String statusId,
    String? mediaUrl,
    StatusMediaKind? mediaKind,
    required Duration fallbackDuration,
  });

  /// **Ce qui peint la vidéo chargée**, ou `null` (pas de vidéo, ou lecteur
  /// qui n'en joue pas).
  ///
  /// Le seul point de ce contrat qui rende un widget, et il le faut : une image
  /// décodée par la plateforme ne se peint que par le widget de son greffon. Le
  /// rendu (`StatusVideoLayer`) le pose dans son cadre ; il ne sait pas ce qu'il
  /// contient. Sans dimensions intrinsèques : le cadre lui donne
  /// [StatusPlayback.videoSize].
  Widget? videoSurface();

  /// Démarre ou reprend la lecture.
  void play();

  /// Suspend la lecture en figeant la position.
  void pause();

  /// Déplace la tête de lecture (bornée à `[0, duration]`).
  void seek(Duration position);

  /// État du son, mémorisé pour la session seulement.
  bool get isMuted;

  void setMuted(bool muted);

  /// Libère les ressources. Sûr et idempotent.
  void dispose();
}

/// Base commune aux implémentations locales : gestion de la valeur observable,
/// du son et du cycle de vie. Les sous-classes n'ont plus qu'à décider comment
/// (et si) la position avance.
abstract base class _BaseStatusPlayer extends ValueNotifier<StatusPlayback>
    implements StatusPlayer {
  _BaseStatusPlayer() : super(const StatusPlayback());

  bool _disposed = false;
  bool _muted = false;

  /// URL du média courant — rien n'y est lu ici : elle est retenue pour que
  /// les tests constatent ce qu'on aurait joué.
  String? mediaUrl;

  /// Ce que [mediaUrl] désigne, retenu pour la même raison.
  @visibleForTesting
  StatusMediaKind? mediaKind;

  /// Ce que [videoSurface] rend — rien par défaut, puisque rien n'est décodé.
  ///
  /// Les tests y posent un widget témoin pour constater que la vidéo remplace
  /// l'affiche à la première image, et pas avant.
  @visibleForTesting
  Widget? surface;

  @override
  Widget? videoSurface() => surface;

  /// Pose un état arbitraire, sans lecture réelle — le pinceau des tests
  /// d'écran, comme `InertContentPlayer.emit` : une durée réelle, une première
  /// image, des dimensions de vidéo se demandent ici au lieu d'être attendues
  /// d'un média qui n'existe pas.
  @visibleForTesting
  void emit(StatusPlayback playback) {
    if (_disposed) return;
    value = playback;
  }

  bool get isDisposed => _disposed;

  @override
  bool get isMuted => _muted;

  @override
  void setMuted(bool muted) {
    if (_disposed) return;
    _muted = muted;
  }

  @override
  void load({
    required String statusId,
    String? mediaUrl,
    StatusMediaKind? mediaKind,
    required Duration fallbackDuration,
  }) {
    if (_disposed) return;
    onStop();
    this.mediaUrl = mediaUrl;
    this.mediaKind = mediaKind;
    // Aucun média réel ici : la durée effective est toujours celle fournie par
    // l'appelant. Une implémentation réelle préférera la durée annoncée par le
    // média et ne retombera sur [fallbackDuration] qu'à défaut.
    value = StatusPlayback(statusId: statusId, duration: fallbackDuration);
  }

  @override
  void pause() {
    if (_disposed || !value.isPlaying) return;
    onStop();
    value = value.copyWith(isPlaying: false);
  }

  @override
  void seek(Duration position) {
    if (_disposed) return;
    final current = value;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > current.duration ? current.duration : position);
    final reachedEnd =
        current.duration > Duration.zero && clamped >= current.duration;
    if (reachedEnd) {
      onStop();
      value = current.copyWith(
        position: clamped,
        isPlaying: false,
        isCompleted: true,
      );
      return;
    }
    value = current.copyWith(position: clamped, isCompleted: false);
  }

  /// Interrompt tout mécanisme d'avance en cours (minuterie, décodeur…).
  void onStop();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    onStop();
    super.dispose();
  }
}

/// Implémentation factice : aucune lecture réelle, mais une horloge qui fait
/// avancer la position pour que toute l'UI (barre de segments, waveform,
/// auto-avance) soit pilotée par les mêmes signaux que le lecteur réel.
///
/// Elle reste le **défaut du provider** — donc ce que voient les tests qui ne
/// le surchargent pas — et le lecteur du **web**, où `just_audio` ne joue pas
/// le HLS hors Safari (#46) : un statut y défile avec son affiche, sans son.
final class FakeStatusPlayer extends _BaseStatusPlayer {
  FakeStatusPlayer({this.tick = const Duration(milliseconds: 50)});

  /// Pas d'avance de l'horloge simulée.
  final Duration tick;

  Timer? _timer;

  @override
  void play() {
    if (isDisposed) return;
    final current = value;
    if (current.statusId == null || current.isPlaying || current.isCompleted) {
      return;
    }
    value = current.copyWith(isPlaying: true);
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) => _advance());
  }

  void _advance() {
    final current = value;
    if (!current.isPlaying) {
      onStop();
      return;
    }
    final next = current.position + tick;
    if (next >= current.duration) {
      // Fin atteinte : on se cale pile sur la durée et surtout on annule la
      // minuterie — elle ne doit jamais se replanifier indéfiniment.
      onStop();
      value = current.copyWith(
        position: current.duration,
        isPlaying: false,
        isCompleted: true,
      );
      return;
    }
    value = current.copyWith(position: next);
  }

  @override
  void onStop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Exposé pour les tests : vrai tant qu'une minuterie est en vol.
  @visibleForTesting
  bool get hasPendingTimer => _timer != null;
}

/// Lecteur inerte destiné aux tests d'écran : **aucune minuterie, jamais**.
///
/// [play] marque la lecture comme active pour que l'UI s'affiche dans son état
/// « en cours », mais la position ne bouge pas et le statut ne se termine
/// jamais tout seul — l'écran reste donc « settleable ».
final class InertStatusPlayer extends _BaseStatusPlayer {
  InertStatusPlayer();

  @override
  void play() {
    if (isDisposed || value.isPlaying) return;
    value = value.copyWith(isPlaying: true);
  }

  @override
  void onStop() {}
}
