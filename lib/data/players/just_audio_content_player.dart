/// **L'implémentation réelle du lecteur** — et le seul fichier du dépôt qui
/// importe `just_audio`.
///
/// Deux objets y vivent, et c'est délibéré :
///
/// - [ContentAudioHandler] — le `BaseAudioHandler` d'`audio_service`. Il tient
///   l'`AudioPlayer`, publie l'état que le système affiche (notification,
///   écran verrouillé, casque, Android Auto) et déclare **quels boutons** y
///   paraissent : recul, lecture/pause, avance.
/// - [JustAudioContentPlayer] — l'adaptation de ce handler au contrat
///   [ContentPlayer], que le reste de l'application est seul à connaître.
///
/// Les séparer en deux fichiers aurait donné **deux** imports de `just_audio` :
/// le handler pilote le lecteur, l'adaptateur en observe les flux. Le critère
/// « `just_audio` n'est importé que par l'implémentation réelle » se vérifie au
/// `grep`, et il tient précisément parce que les deux tiennent ici.
///
/// **Rien de ce fichier ne s'instancie sous `flutter test`** : `setUrl` et
/// `dispose` lèvent `MissingPluginException`, il n'y a pas de canal de plugin
/// dans le harnais. C'est le démarrage de l'application qui construit ces
/// objets, et lui seul — voir `main.dart`.
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'content_player.dart';
import 'playback_watchdog.dart';

/// **Le pilote du média, côté système.**
///
/// `SeekHandler` fournit `rewind` et `fastForward` à partir des intervalles de
/// l'`AudioServiceConfig` — c'est ce qui fait que les boutons de la
/// notification reculent et avancent du même pas que ceux de l'écran.
class ContentAudioHandler extends BaseAudioHandler with SeekHandler {
  ContentAudioHandler() {
    // Un seul abonnement pour republier l'état système : `playbackEventStream`
    // bat à chaque changement utile (lecture, tampon, position corrigée).
    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      // Une panne de lecture arrive **par le flux**, jamais par une exception
      // synchrone. Sans ce `onError`, elle deviendrait une erreur asynchrone
      // non rattrapée — le défaut même que cette architecture cherche à éviter.
      onError: (Object error, StackTrace stackTrace) {
        _failure = error;
        _broadcastState();
      },
    );
    // La durée d'un flux HLS arrive **après** le manifeste. Il faut la
    // republier dans le `MediaItem` : `SeekHandler` borne ses avances sur
    // `mediaItem.duration`, et tant qu'elle vaut `null` il ramène chaque avance
    // rapide à zéro — le bouton « +30 s » ferait alors revenir au début.
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item == null || duration == null || item.duration == duration) return;
      mediaItem.add(item.copyWith(duration: duration));
    });
  }

  final AudioPlayer _player = AudioPlayer();

  /// Le lecteur sous-jacent, observé par [JustAudioContentPlayer].
  ///
  /// Exposé plutôt que dupliqué : le handler parle au système, l'adaptateur
  /// parle à l'UI, et les deux doivent lire le **même** état — pas deux copies
  /// qui dérivent.
  AudioPlayer get player => _player;

  /// Dernière panne connue, remise à zéro à chaque chargement.
  Object? _failure;

  /// Ouvre un média et annonce ce que le système doit afficher.
  ///
  /// Ne démarre pas la lecture : c'est [play] qui le fait.
  ///
  /// [at] est la position d'ouverture, passée à `setUrl` plutôt que suivie
  /// d'un `seek` : un déplacement demandé après coup part d'un lecteur qui a
  /// déjà commencé à remplir son tampon depuis le début, et le fidèle entend
  /// alors une seconde du tout début du prêche avant d'être ramené où il en
  /// était. C'est le chemin du repli de [JustAudioContentPlayer.resume] et
  /// celui du chien de garde.
  Future<void> open({
    required String url,
    required MediaItem item,
    Duration? at,
  }) async {
    _failure = null;
    mediaItem.add(item);
    await _player.setUrl(url, initialPosition: at);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    mediaItem.add(null);
    await super.stop();
  }

  /// Libère le lecteur natif. Appelée à la fin de vie de l'application.
  Future<void> close() => _player.dispose();

  void _broadcastState() {
    playbackState.add(
      playbackState.value.copyWith(
        // **Les trois boutons, et leur ordre.** C'est exactement ce que
        // `just_audio_background` ne permet pas de choisir, et la raison pour
        // laquelle `audio_service` est pris en direct.
        controls: [
          MediaControl.rewind,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.rewind,
          MediaAction.fastForward,
        },
        // Les trois tiennent dans la vue compacte d'Android : un prêche
        // s'écoute écran éteint, c'est là que les reculs servent.
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _failure != null
            ? AudioProcessingState.error
            : _processingStates[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  static const Map<ProcessingState, AudioProcessingState> _processingStates = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };
}

/// **Le contrat [ContentPlayer], servi par `just_audio`.**
///
/// N'ouvre pas de lecteur : il en reçoit un, déjà construit par
/// `AudioService.init()`. C'est ce qui garantit qu'il n'existe **qu'un seul**
/// `AudioPlayer` dans le processus — un second fait lever le service audio — et
/// que sa création reste sur le chemin de démarrage, celui que les tests ne
/// prennent jamais.
class JustAudioContentPlayer extends ValueNotifier<ContentPlayback>
    implements ContentPlayer {
  JustAudioContentPlayer(this._handler) : super(const ContentPlayback()) {
    final player = _handler.player;
    // Trois flux, trois champs. Séparés plutôt que fondus dans
    // `playbackEventStream` : la position bat plusieurs fois par seconde, la
    // durée une fois par média, l'état à chaque transition. Les recomposer à la
    // main ferait payer le rythme de la position à tout le reste.
    _subscriptions.addAll([
      player.positionStream.listen((position) {
        _emit(value.copyWith(position: position));
      }),
      player.durationStream.listen((duration) {
        if (duration == null) return;
        _emit(value.copyWith(duration: duration));
      }),
      player.playerStateStream.listen((state) {
        _emit(
          value.copyWith(
            isPlaying: state.playing,
            isBuffering: state.processingState == ProcessingState.loading ||
                state.processingState == ProcessingState.buffering,
            isCompleted: state.processingState == ProcessingState.completed,
            // `ready` est le premier instant où le média **peut** sortir du
            // son. C'est ce qui fera dire à l'écran « lecture interrompue »
            // plutôt que « il faut du réseau » si tout s'arrête ensuite. Une
            // fois vrai, il ne redevient faux qu'au chargement d'un autre
            // contenu — d'où le `||`.
            hasStarted: value.hasStarted ||
                state.processingState == ProcessingState.ready ||
                state.processingState == ProcessingState.completed,
          ),
        );
      }),
      // Les pannes de lecture voyagent par le flux d'événements, pas par une
      // exception. On ne s'abonne qu'à son canal d'erreur.
      player.playbackEventStream.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          _emit(value.copyWith(error: error, isBuffering: false));
        },
      ),
    ]);
  }

  final ContentAudioHandler _handler;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _disposed = false;

  /// Ce que le lecteur tient, et qu'une reprise rouvrirait. `null` après un
  /// [stop] : il n'y a alors plus rien à reprendre.
  ContentRequest? _request;

  /// **Le chien de garde du décrochage silencieux — c'est ici qu'il compte.**
  ///
  /// Sur iOS, un décrochage réseau ne remonte aucune erreur et il n'y a pas de
  /// reconnexion native : sans lui, un prêche d'une heure s'arrête au bout de
  /// dix minutes, définitivement, et rien n'en portera jamais la trace.
  late final PlaybackWatchdog _watchdog = PlaybackWatchdog(
    onStalled: (at) {
      final request = _request;
      if (request == null) return;
      unawaited(_reopenAt(request, at));
    },
  );

  void _emit(ContentPlayback playback) {
    if (_disposed) return;
    value = playback;
    _watchdog.observe(playback);
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
    final request = ContentRequest(
      contentId: contentId,
      url: url,
      title: title,
      author: author,
      artUrl: artUrl,
    );
    _request = request;
    // Valeur **neuve** : durée, fin atteinte et panne du contenu précédent
    // doivent disparaître, et `copyWith` ne sait pas effacer.
    _emit(ContentPlayback(contentId: contentId, isBuffering: true));
    await _open(request);
  }

  /// **Reprendre une lecture interrompue, à la position atteinte.**
  ///
  /// Deux chemins, et le second existe parce que le premier n'est garanti par
  /// aucun contrat :
  ///
  /// 1. **le raccourci.** À la panne fatale, la plateforme repasse en
  ///    `ProcessingState.idle` et `just_audio` bascule sur un lecteur inactif
  ///    **en capturant la position et la source** ; `play()` réactive alors la
  ///    plateforme en rechargeant à la position mémorisée. Vérifié dans le
  ///    source de `just_audio` 0.10.6, **documenté nulle part** — d'où le
  ///    repli. La condition que `play()` exige est exactement celle qu'on
  ///    teste : une source encore tenue (`audioSource`, c'est-à-dire la
  ///    playlist non vide) ;
  /// 2. **le repli explicite** : rouvrir la source nous-mêmes, à la dernière
  ///    position connue.
  ///
  /// Dans les deux cas la position vient de [value], jamais de zéro : c'est ce
  /// que le mot « Reprendre » promet au fidèle.
  @override
  Future<void> resume() async {
    if (_disposed) return;
    final request = _request;
    if (request == null) return;
    final at = value.position;
    // Valeur neuve : `copyWith` ne sait pas effacer une panne.
    _emit(
      ContentPlayback(
        contentId: request.contentId,
        position: at,
        duration: value.duration,
        isPlaying: true,
        isBuffering: true,
        hasStarted: value.hasStarted,
      ),
    );
    if (_handler.player.audioSource != null) {
      unawaited(_handler.play());
      return;
    }
    await _reopenAt(request, at);
  }

  /// Rouvre la source à [at] et repart — le geste commun au repli de [resume]
  /// et au chien de garde.
  Future<void> _reopenAt(ContentRequest request, Duration at) async {
    await _open(request, at: at);
    if (_disposed) return;
    unawaited(_handler.play());
  }

  /// Ouvre (ou rouvre) la source, éventuellement à une position.
  Future<void> _open(ContentRequest request, {Duration? at}) async {
    try {
      await _handler.open(
        // **Le palier se choisit ici, par l'URL.** Sur Android c'est le seul
        // levier qui existe ; sur les autres plateformes il double le plafond
        // de débit, sans le contredire — un rendu unique ne laisse rien à
        // adapter au-dessus.
        url: variantPlaylistUrl(request.url, _variant),
        at: at,
        item: MediaItem(
          // L'identifiant du contenu, pas l'URL : c'est lui qui désigne un
          // enseignement dans tout le reste de l'application (routes,
          // notifications), et le système le rendra un jour à Android Auto.
          id: request.contentId,
          title: request.title,
          artist: request.author,
          artUri: request.artUrl == null ? null : Uri.tryParse(request.artUrl!),
        ),
      );
    } catch (error) {
      _emit(value.copyWith(error: error, isBuffering: false));
    }
  }

  @override
  void play() {
    if (_disposed) return;
    unawaited(_handler.play());
  }

  @override
  void pause() {
    if (_disposed) return;
    unawaited(_handler.pause());
  }

  @override
  void seek(Duration position) {
    if (_disposed) return;
    unawaited(_handler.seek(value.clampPosition(position)));
  }

  /// **Le plafond ne mord que sur iOS et macOS**, et c'est une limite du
  /// greffon, pas un oubli d'ici : `just_audio` documente
  /// `setPreferredPeakBitRate` comme « iOS/macOS », et son implémentation
  /// Android reçoit l'appel pour répondre `success` **sans rien faire**
  /// (`AudioPlayer.java`, `case "setPreferredPeakBitRate"`). ExoPlayer sait
  /// pourtant le faire (`TrackSelectionParameters.setMaxAudioBitrate`), mais
  /// le greffon ne l'expose pas.
  ///
  /// Conséquence à connaître avant de croire le réglage universel : sur
  /// Android, la qualité d'écoute est **enregistrée et sans effet**, comme le
  /// direct et le téléchargement. Sur iOS et sur le web, elle agit.
  ///
  /// `0` est la valeur « aucun plafond » d'`AVPlayer` — pas `-1`, et pas
  /// `null`.
  @override
  void setBitrateCap(int? bitsPerSecond) {
    if (_disposed) return;
    unawaited(
      _handler.player.setPreferredPeakBitRate((bitsPerSecond ?? 0).toDouble()),
    );
  }

  /// **Le seul levier de qualité qui morde sur Android.** Le plafond de débit
  /// y est ignoré par le greffon ; charger directement la liste de lecture d'un
  /// rendu ne dépend, elle, que de l'URL.
  String? _variant;

  @override
  void setPreferredVariant(String? variant) {
    if (_disposed) return;
    _variant = variant;
  }

  @override
  void stop() {
    if (_disposed) return;
    _request = null;
    _emit(const ContentPlayback());
    unawaited(_handler.stop());
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _watchdog.dispose();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    unawaited(_handler.close());
    super.dispose();
  }
}
