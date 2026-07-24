import 'dart:async';

import 'package:flutter/foundation.dart';

/// Durées d'affichage par défaut d'un statut, dernier maillon de la chaîne de
/// résolution : durée réelle du lecteur → `durationMs` envoyé par le back →
/// défaut par type.
abstract final class StatusDurations {
  /// Statut sans média temporel (texte, image).
  static const Duration still = Duration(seconds: 5);

  /// Statut porteur d'un média temporel (audio, vidéo).
  static const Duration media = Duration(seconds: 30);
}

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
  }) {
    return StatusPlayback(
      statusId: statusId ?? this.statusId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StatusPlayback &&
        other.statusId == statusId &&
        other.position == position &&
        other.duration == duration &&
        other.isPlaying == isPlaying &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode =>
      Object.hash(statusId, position, duration, isPlaying, isCompleted);

  @override
  String toString() =>
      'StatusPlayback(statusId: $statusId, position: $position, '
      'duration: $duration, isPlaying: $isPlaying, isCompleted: $isCompleted)';
}

/// Lecteur d'un statut.
///
/// Contrat unique dont dépend l'UI, sur le modèle de `ChurchRepository` :
/// brancher `just_audio` / `video_player` consistera à fournir une autre
/// implémentation via `statusPlayerProvider`, **sans toucher un seul écran**.
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
  /// [fallbackDuration] s'applique quand le média ne déclare pas la sienne
  /// (chaîne de résolution : durée réelle du lecteur → `durationMs` du back →
  /// défaut par type, cf. [StatusDurations]).
  void load({
    required String statusId,
    String? mediaUrl,
    required Duration fallbackDuration,
  });

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

  /// URL du média courant — inutilisée en phase 1, elle documente le point
  /// d'accroche des implémentations réelles.
  String? mediaUrl;

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
    required Duration fallbackDuration,
  }) {
    if (_disposed) return;
    onStop();
    this.mediaUrl = mediaUrl;
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

/// Implémentation factice de phase 1 : aucune lecture réelle, mais une horloge
/// qui fait avancer la position pour que toute l'UI (barre de segments,
/// waveform, auto-avance) soit pilotée par les mêmes signaux qu'en phase 2.
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
