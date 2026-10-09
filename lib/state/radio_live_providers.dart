/// **La couche sociale de la page radio** (#135) : le direct, le compteur, les
/// réactions, le fil et sa modération — au-dessus du son, jamais dedans.
///
/// L'écoute elle-même reste à `RadioListening` (`radio_providers.dart`), et rien
/// ici n'y touche : le fil peut tomber, le canal se couper, une route refuser,
/// **le son continue**.
///
/// ## Une source de vérité par moment, et jamais deux à la fois
///
/// | moment | ce qui fait foi |
/// | --- | --- |
/// | ouverture de la page | `GET /radio/antenna` + `GET /radio/comments` (+ la file pour un modérateur) |
/// | connexion (re)ouverte | la même relecture, qui **remplace** l'affichage |
/// | entre les deux | les événements du canal `radio`, appliqués en mémoire |
///
/// La relecture remplace, elle ne fusionne pas : c'est ce qui fait qu'un
/// événement manqué pendant une coupure (une bascule bleu/vert coupe Transmit
/// ~120 s, piège 2 du plan) ne laisse aucune trace fausse.
///
/// ## Jamais de sondage
///
/// Aucune horloge ne relit quoi que ce soit. La seule minuterie est la
/// **réouverture** d'un canal tombé ([kRadioChannelRetryDelay]), et une
/// réouverture qui échoue ne relit rien : seule une connexion **réussie**
/// déclenche une relecture. Un garde-fou de source le verrouille
/// (`test/state/radio_live_controller_test.dart`).
///
/// ## Aligné sur l'écoute de chacun (mobile#187)
///
/// L'auditeur entend l'antenne ~24 s en retard. Un commentaire, un agrégat de
/// réactions, le début et la fin du direct portent leur **heure d'antenne**
/// (`airedAt`, `startedAt`, `endedAt`) ; ils s'appliquent quand le lecteur
/// **entend** cette heure (`ContentPlayer.heardTime`). Entre-temps ils
/// attendent dans une file triée, qu'**un seul `Timer` ponctuel** réarmé sur
/// sa tête fait avancer — jamais un battement. Sans heure entendue (`null` :
/// flux sans PDT, web), tout s'applique tout de suite, comme avant. Mes propres
/// envois et `comment.hidden` ne passent jamais par la file.
///
/// ## Ouvert avec la page, fermé avec elle
///
/// `autoDispose` : l'écran l'observe, Riverpod le jette quand l'écran s'en va,
/// et [RadioLiveController] rend la socket. L'arrière-plan ferme aussi, le
/// retour relit puis rouvre — comme le fil d'un groupe (`open_thread_channel.dart`).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/players/content_player.dart';
import '../data/radio/http_radio_live_repository.dart';
import '../data/radio/radio_antenna.dart';
import '../data/radio/radio_channel.dart';
import '../data/radio/radio_live.dart';
import '../data/radio/radio_live_repository.dart';
import '../data/radio/radio_repository.dart';
import '../data/radio/sse_radio_channel.dart';
import 'player_providers.dart';
import 'radio_providers.dart';

/// Le délai avant de rouvrir un canal tombé. Nommé **une seule fois**, et
/// **valeur à confirmer**, comme `kGroupChannelRetryDelay` dont il reprend la
/// valeur et la raison : assez court pour qu'une coupure ne se remarque pas,
/// assez long pour ne pas marteler un serveur injoignable.
const Duration kRadioChannelRetryDelay = Duration(seconds: 10);

/// **Combien de réactions des autres une seule seconde d'agrégat fait monter**,
/// par réaction. Une audience nombreuse envoie des centaines de cœurs par
/// seconde ; l'écran n'en montre qu'une poignée, et c'est assez pour dire « on
/// est ensemble ». Le plafond d'affichage global vit dans le widget.
const int kRadioReactionBurstCap = 6;

/// D'où viennent les événements du canal — SSE avec backend, muet sinon.
final radioChannelProvider = Provider<RadioChannel>(
  (ref) => AppEnv.useBackend ? SseRadioChannel() : const SilentRadioChannel(),
);

/// D'où viennent le fil et ses écritures — HTTP avec backend, inerte sinon.
final radioLiveRepositoryProvider = Provider<RadioLiveRepository>(
  (ref) => AppEnv.useBackend
      ? HttpRadioLiveRepository()
      : const InertRadioLiveRepository(),
);

/// **Des réactions à faire monter**, un lot à la fois.
@immutable
class RadioReactionBurst {
  const RadioReactionBurst(this.reaction, this.count, {this.own = false});

  final RadioReaction reaction;

  /// Déjà plafonné ([kRadioReactionBurstCap]).
  final int count;

  /// La mienne : elle monte **tout de suite**, sans attendre le serveur.
  final bool own;
}

/// **Ce que la page live affiche**, hors du son.
@immutable
class RadioLiveState {
  const RadioLiveState({
    this.live,
    this.listeners,
    this.comments = const [],
    this.viewer = RadioViewer.unknown,
    this.reported = const [],
    this.connected = false,
    this.liveHeard = false,
  });

  final RadioLive? live;

  /// `null` : le compteur ne s'affiche pas (voir `RadioAntenna.listeners`).
  final int? listeners;

  /// Du plus ancien au plus récent, [kRadioCommentWindow] au plus. Vide hors
  /// direct : le fil n'existe que pendant un direct (décision 5).
  final List<RadioComment> comments;
  final RadioViewer viewer;

  /// La file des signalements — vide pour qui n'est pas modérateur.
  final List<RadioReportedComment> reported;

  /// Le canal tient. Pour le diagnostic : l'écran ne l'affiche pas, parce que
  /// la page doit marcher pareil sans temps réel.
  final bool connected;

  /// Le début du direct est **entendu** (`startedAt + kLiveAudioLatency`), et
  /// sa fin pas encore. Vrai d'emblée sans heure entendue.
  final bool liveHeard;

  bool get isLive => live != null;

  /// **Le badge « EN DIRECT »** : il s'allume avec la voix, pas avec la régie.
  bool get showsLiveBadge => isLive && liveHeard;

  /// Le champ de saisie est offert : un direct, et pas réduit au silence. Un
  /// invité sans pseudo **l'a aussi** — le serveur répondra
  /// `E_RADIO_PSEUDONYM_REQUIRED`, et la page ouvrira le formulaire.
  bool get offersComposer => isLive && !viewer.silenced;

  static const Object _keep = Object();

  RadioLiveState copyWith({
    Object? live = _keep,
    Object? listeners = _keep,
    List<RadioComment>? comments,
    RadioViewer? viewer,
    List<RadioReportedComment>? reported,
    bool? connected,
    bool? liveHeard,
  }) =>
      RadioLiveState(
        live: identical(live, _keep) ? this.live : live as RadioLive?,
        listeners:
            identical(listeners, _keep) ? this.listeners : listeners as int?,
        comments: comments ?? this.comments,
        viewer: viewer ?? this.viewer,
        reported: reported ?? this.reported,
        connected: connected ?? this.connected,
        liveHeard: liveHeard ?? this.liveHeard,
      );
}

/// L'issue d'un envoi de commentaire, telle que l'écran doit la dire.
enum RadioSendOutcome {
  sent,

  /// Un invité sans pseudo : ouvrir le formulaire, puis renvoyer.
  pseudonymRequired,
  silenced,
  closed,
  throttled,
  invalid,
  failed,
}

/// L'issue de l'enregistrement d'un pseudo.
enum RadioPseudonymOutcome { saved, invalid, throttled, failed }

/// L'issue d'un signalement.
enum RadioReportOutcome {
  reported,
  alreadyReported,

  /// Un invité signale aussi sous un pseudo : même formulaire qu'à l'envoi.
  pseudonymRequired,

  /// Le message n'existe plus (masqué) ou le fil est fermé.
  gone,
  failed,
}

/// L'issue d'un geste de modération.
enum RadioModerationOutcome { done, notGuest, gone, failed }

/// Les bornes du pseudo (`E_RADIO_PSEUDONYM_INVALID`), vérifiées avant l'envoi
/// pour répondre tout de suite — le serveur reste juge.
const int kRadioPseudonymMin = 2;
const int kRadioPseudonymMax = 24;

/// La borne d'un commentaire (`E_RADIO_COMMENT_INVALID`).
const int kRadioCommentMaxLength = 200;

/// **La page live** — ouverte avec l'écran, fermée avec lui.
final radioLiveProvider =
    NotifierProvider.autoDispose<RadioLiveController, RadioLiveState>(
  RadioLiveController.new,
);

/// Ce que la file retardée retient : un commentaire, un agrégat, ou une
/// bascule du direct (début ou fin entendus).
enum _AiredKind { comment, reactions, live }

/// **Un événement qui attend d'être entendu.**
class _Aired {
  _Aired(this.at, this.kind, this.apply, {this.commentId});

  /// L'heure d'antenne à laquelle l'appliquer.
  final DateTime at;
  final _AiredKind kind;
  final void Function() apply;
  final String? commentId;
}

class RadioLiveController extends Notifier<RadioLiveState>
    with WidgetsBindingObserver {
  late RadioChannel _channel;
  late RadioLiveRepository _repository;
  late RadioRepository _antenna;
  late ContentPlayer _player;

  /// **La file retardée**, triée par heure d'antenne, et sa **seule** minuterie
  /// — ponctuelle, armée sur la tête. Voir « Aligné sur l'écoute ».
  final List<_Aired> _aired = [];
  Timer? _airedTimer;

  StreamSubscription<RadioChannelEvent>? _subscription;
  Timer? _reopen;

  /// **Synchrone**, exprès : ma réaction monte dans le même geste que l'appui,
  /// pas à la microtâche suivante — et un test peut le constater avant que le
  /// serveur ait répondu.
  StreamController<RadioReactionBurst> _bursts =
      StreamController<RadioReactionBurst>.broadcast(sync: true);

  bool _disposed = false;
  bool _observing = false;

  /// S'abonner aussi à `radio/moderation` — vrai dès qu'une relecture a dit
  /// `viewer.moderator`.
  bool _wantModeration = false;

  /// Chaque relecture porte un numéro ; une réponse arrivée après une relecture
  /// plus récente est jetée.
  int _generation = 0;

  /// **Mes réactions pas encore revenues dans un agrégat**, par réaction.
  ///
  /// Elles sont montées tout de suite à l'appui ; l'agrégat de la seconde
  /// suivante les compte aussi. Sans ce décompte, chaque cœur envoyé monterait
  /// deux fois. Pas d'horloge : une réaction refusée (429) est retirée du
  /// décompte à son échec, une réaction acceptée est consommée par l'agrégat.
  final Map<RadioReaction, int> _ownPending = {};

  /// La dernière panne (canal ou relecture), pour le diagnostic — jamais
  /// affichée : la page doit vivre pareil sans temps réel.
  Object? lastFailure;

  /// Les réactions à faire monter. Diffusion : l'écran s'y abonne une fois.
  Stream<RadioReactionBurst> get bursts => _bursts.stream;

  @override
  RadioLiveState build() {
    _disposed = false;
    _channel = ref.watch(radioChannelProvider);
    _repository = ref.watch(radioLiveRepositoryProvider);
    _antenna = ref.watch(radioRepositoryProvider);
    _player = ref.read(contentPlayerProvider);
    if (_bursts.isClosed) {
      _bursts = StreamController<RadioReactionBurst>.broadcast(sync: true);
    }
    ref.onDispose(_dispose);

    // Ce que la route d'antenne a déjà dit : le badge et le compteur sont là
    // dès la première image, sans attendre la relecture.
    final known = ref.read(radioAntennaProvider).value;

    _observe();
    _connect();
    // **La lecture d'ouverture.** Elle part sans attendre le canal : la page
    // doit se remplir aussi quand le temps réel n'existe pas (sans backend, ou
    // un canal qui ne s'ouvre pas). L'ouverture du canal en déclenchera une
    // seconde — c'est le prix d'un ordre sûr : rien de ce qui s'est passé avant
    // l'abonnement ne peut manquer.
    scheduleMicrotask(() => unawaited(resynchronize()));

    return RadioLiveState(
      live: known?.live,
      listeners: known?.listeners,
      // L'heure entendue n'est pas encore lue : comme avant, le badge est là
      // dès la première image ; la relecture le corrige.
      liveHeard: known?.live != null,
    );
  }

  // ---------------------------------------------------------------------------
  // Le canal
  // ---------------------------------------------------------------------------

  void _observe() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  void _connect() {
    if (_disposed) return;
    _disconnect();
    final subscription = _channel.watch(moderation: _wantModeration).listen(
      _onEvent,
      onError: (Object error) {
        lastFailure = error;
        _subscription = null;
        _forgetAired();
        _setConnected(false);
        // Un refus ne se réessaie pas : insister ne changerait pas la
        // réponse. La page vit alors de ses relectures, sans temps réel.
        if (error is RadioChannelRefused) return;
        _reopenLater();
      },
      onDone: () {
        _subscription = null;
        _forgetAired();
        _setConnected(false);
        _reopenLater();
      },
      cancelOnError: true,
    );
    _subscription = subscription;
  }

  void _disconnect() {
    _forgetAired();
    _reopen?.cancel();
    _reopen = null;
    final open = _subscription;
    _subscription = null;
    if (open != null) unawaited(open.cancel());
  }

  void _reopenLater() {
    if (_disposed) return;
    _reopen?.cancel();
    _reopen = Timer(kRadioChannelRetryDelay, _connect);
  }

  void _setConnected(bool connected) {
    if (_disposed || state.connected == connected) return;
    state = state.copyWith(connected: connected);
  }

  /// **L'arrière-plan ferme, le retour relit puis rouvre.**
  ///
  /// La relecture part **avant** la réouverture : le rattrapage ne doit pas
  /// dépendre d'une réouverture qui peut échouer. `inactive` seul (une alerte
  /// système) ne ferme rien.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (_disposed) return;
    if (lifecycle == AppLifecycleState.resumed) {
      if (_subscription != null) return;
      unawaited(resynchronize());
      _connect();
      return;
    }
    if (lifecycle != AppLifecycleState.inactive) {
      _disconnect();
      _setConnected(false);
    }
  }

  void _onEvent(RadioChannelEvent event) {
    if (_disposed) return;
    switch (event) {
      case RadioChannelOpened():
        lastFailure = null;
        _setConnected(true);
        unawaited(resynchronize());
      case RadioLiveChanged(:final live, :final listeners, :final endedAt):
        if (live == null) {
          state = state.copyWith(listeners: listeners);
          final ended = state.live;
          if (ended == null || endedAt == null) {
            _close();
          } else {
            // **Le fil se ferme quand on entend la fin** — d'ici là, la fin
            // du direct reste commentable (décision 5 du plan).
            unawaited(_endWhenHeard(ended, endedAt.add(kLiveAudioLatency)));
          }
        } else {
          final same = state.live == live;
          state = state.copyWith(
            live: live,
            listeners: listeners,
            comments: same ? state.comments : const [],
            liveHeard: same ? state.liveHeard : false,
          );
          if (!same) unawaited(_followLive(live));
          // Le porteur peut désormais écrire : `viewer` se relit.
          unawaited(_readThread());
        }
      case RadioListenersChanged(:final listeners):
        state = state.copyWith(listeners: listeners);
      case RadioReactionsAggregated(:final counts, :final airedAt):
        final bursts = _othersOf(counts);
        if (bursts.isEmpty) break;
        if (airedAt == null) {
          bursts.forEach(_emit);
        } else {
          unawaited(_whenHeard(_Aired(
            airedAt,
            _AiredKind.reactions,
            () => bursts.forEach(_emit),
          )));
        }
      case RadioCommentPosted(:final comment):
        // Déjà affiché (le mien, rendu par le `POST`) : remplacé tout de suite.
        if (state.comments.any((shown) => shown.id == comment.id)) {
          _append(comment);
        } else {
          unawaited(_whenHeard(_Aired(
            comment.airedAt,
            _AiredKind.comment,
            () => _append(comment),
            commentId: comment.id,
          )));
        }
      case RadioCommentHidden(:final commentId):
        _forget(commentId);
      case RadioModerationChanged(:final commentId, :final isReview):
        if (isReview) {
          // « Les autres modérateurs retirent l'entrée sans relire. »
          state = state.copyWith(
            reported: [
              for (final item in state.reported)
                if (item.comment.id != commentId) item,
            ],
          );
        } else {
          unawaited(_readQueue());
        }
    }
  }

  /// Les réactions **des autres** dans un agrégat. Les miennes sont décomptées
  /// à la réception, pas à l'affichage : elles sont déjà montées.
  List<RadioReactionBurst> _othersOf(Map<RadioReaction, int> counts) {
    final bursts = <RadioReactionBurst>[];
    for (final MapEntry(key: reaction, value: count) in counts.entries) {
      if (count <= 0) continue;
      final own = _ownPending[reaction] ?? 0;
      final matched = math.min(own, count);
      if (matched > 0) _ownPending[reaction] = own - matched;
      final others = count - matched;
      if (others <= 0) continue;
      bursts.add(RadioReactionBurst(
        reaction,
        math.min(others, kRadioReactionBurstCap),
      ));
    }
    return bursts;
  }

  void _emit(RadioReactionBurst burst) {
    if (!_bursts.isClosed) _bursts.add(burst);
  }

  void _append(RadioComment comment) {
    if (_disposed) return;
    // Mon propre message arrive deux fois — par la réponse du `POST` et par le
    // canal. L'identifiant départage ; la version du canal remplace l'autre.
    final next = [
      for (final existing in state.comments)
        if (existing.id != comment.id) existing,
      comment,
    ];
    state = state.copyWith(
      comments: next.length <= kRadioCommentWindow
          ? next
          : next.sublist(next.length - kRadioCommentWindow),
    );
  }

  void _forget(String commentId) {
    if (_disposed) return;
    _aired.removeWhere((item) => item.commentId == commentId);
    state = state.copyWith(
      comments: [
        for (final comment in state.comments)
          if (comment.id != commentId) comment,
      ],
      reported: [
        for (final item in state.reported)
          if (item.comment.id != commentId) item,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Les relectures
  // ---------------------------------------------------------------------------

  /// **Relit l'antenne et le fil, et remplace l'affichage** — à l'ouverture, à
  /// chaque connexion, au retour d'arrière-plan. Jamais sur une horloge.
  ///
  /// Une lecture qui échoue garde ce qu'on avait : un fil vidé parce qu'une
  /// relecture a pris un délai dépassé serait pire qu'un fil un peu en retard.
  Future<void> resynchronize() async {
    if (_disposed) return;
    final generation = ++_generation;
    final antennaRead = _antenna.antenna().then<RadioAntenna?>(
      (antenna) => antenna,
      onError: (Object error) {
        lastFailure = error;
        return null;
      },
    );
    final threadRead = _repository.thread().then<RadioThread?>(
      (thread) => thread,
      onError: (Object error) {
        lastFailure = error;
        return null;
      },
    );
    final heardRead = _heardTime();
    final antenna = await antennaRead;
    final thread = await threadRead;
    final heard = await heardRead;
    if (_disposed || generation != _generation) return;

    var next = state;
    if (antenna != null) {
      next = next.copyWith(listeners: antenna.listeners, live: antenna.live);
    }
    if (thread != null) {
      next = _withThread(next, thread, heard).copyWith(
        reported: thread.viewer.moderator ? next.reported : const [],
      );
    }
    if (antenna != null || thread != null) next = _withLive(next, heard);
    state = next;
    _arm(heard);
    if (thread != null) _followModeration(thread.viewer.moderator);
  }

  Future<void> _readThread() async {
    final generation = _generation;
    try {
      final thread = await _repository.thread();
      final heard = await _heardTime();
      if (_disposed || generation != _generation) return;
      state = _withThread(state, thread, heard);
      _arm(heard);
      _followModeration(thread.viewer.moderator);
    } catch (error) {
      lastFailure = error;
    }
  }

  /// **Le fil relu remplace l'affichage** — mais seulement ce qu'on a déjà
  /// entendu ; le reste repart en file, à son heure.
  RadioLiveState _withThread(
    RadioLiveState from,
    RadioThread thread,
    DateTime? heard,
  ) {
    _aired.removeWhere((item) => item.kind == _AiredKind.comment);
    final shown = <RadioComment>[];
    for (final comment in thread.comments) {
      if (heard == null || !comment.airedAt.isAfter(heard)) {
        shown.add(comment);
      } else {
        _queue(_Aired(
          comment.airedAt,
          _AiredKind.comment,
          () => _append(comment),
          commentId: comment.id,
        ));
      }
    }
    return from.copyWith(
      live: thread.live,
      comments: shown,
      viewer: thread.viewer,
    );
  }

  // ---------------------------------------------------------------------------
  // La file retardée (mobile#187)
  // ---------------------------------------------------------------------------

  /// L'heure d'antenne entendue ; une panne vaut « je ne sais pas ».
  Future<DateTime?> _heardTime() async {
    try {
      return await _player.heardTime();
    } catch (_) {
      return null;
    }
  }

  /// Insère à sa place — après ses égaux, pour garder l'ordre d'arrivée.
  void _queue(_Aired item) {
    final at = _aired.indexWhere((other) => other.at.isAfter(item.at));
    _aired.insert(at < 0 ? _aired.length : at, item);
  }

  Future<void> _whenHeard(_Aired item) async {
    _queue(item);
    await _drain();
  }

  /// **Applique ce qui est entendu, puis réarme sur la tête.**
  ///
  /// [reached] : l'heure que la minuterie visait. Elle est tenue pour
  /// entendue même si le lecteur dit moins (en pause, en tampon) — sans quoi
  /// une écoute arrêtée réarmerait sans fin la même minuterie.
  Future<void> _drain({DateTime? reached}) async {
    final heard = await _heardTime();
    if (_disposed) return;
    // `heard` nul : on ne sait pas ce qu'on entend, tout part tout de suite.
    final now = heard == null || reached == null || heard.isAfter(reached)
        ? heard
        : reached;
    while (
        _aired.isNotEmpty && (now == null || !_aired.first.at.isAfter(now))) {
      _aired.removeAt(0).apply();
    }
    _arm(heard);
  }

  /// **La seule minuterie de la file**, ponctuelle, sur sa tête.
  void _arm(DateTime? heard) {
    _airedTimer?.cancel();
    _airedTimer = null;
    if (_disposed || _aired.isEmpty) return;
    if (heard == null) {
      unawaited(_drain());
      return;
    }
    final head = _aired.first.at;
    _airedTimer = Timer(
      head.difference(heard),
      () => unawaited(_drain(reached: head)),
    );
  }

  /// La file ne survit pas au canal : la prochaine connexion relit, et
  /// remplace. Seules les bascules du direct restent — elles ne viennent pas
  /// du canal.
  void _forgetAired() {
    _aired.removeWhere((item) => item.kind != _AiredKind.live);
    if (_aired.isEmpty) {
      _airedTimer?.cancel();
      _airedTimer = null;
    }
  }

  /// **Le badge suit le début entendu** du direct de [from].
  RadioLiveState _withLive(RadioLiveState from, DateTime? heard) {
    _aired.removeWhere((item) => item.kind == _AiredKind.live);
    final live = from.live;
    if (live == null) return from.copyWith(liveHeard: false);
    final on = live.startedAt.add(kLiveAudioLatency);
    if (heard == null || !on.isAfter(heard)) {
      return from.copyWith(liveHeard: true);
    }
    _queue(_Aired(on, _AiredKind.live, () {
      if (!_disposed && state.live == live) {
        state = state.copyWith(liveHeard: true);
      }
    }));
    return from.copyWith(liveHeard: false);
  }

  Future<void> _followLive(RadioLive live) async {
    final heard = await _heardTime();
    if (_disposed || state.live != live) return;
    state = _withLive(state, heard);
    _arm(heard);
  }

  Future<void> _endWhenHeard(RadioLive ended, DateTime at) async {
    await _whenHeard(_Aired(at, _AiredKind.live, () {
      if (state.live == ended) _close();
    }));
  }

  /// **Le direct est fini : le fil est fermé**, et la file avec lui.
  void _close() {
    if (_disposed) return;
    _aired.removeWhere((item) => item.kind != _AiredKind.reactions);
    state = state.copyWith(
      live: null,
      comments: const [],
      reported: const [],
      liveHeard: false,
    );
  }

  /// **Le modérateur écoute aussi le canal privé**, et relit sa file.
  ///
  /// On ne le sait qu'après une relecture : la connexion est alors rouverte
  /// avec les deux abonnements. Un changement de rôle dans l'autre sens la
  /// rouvre sans. La file se relit à chaque relecture d'un modérateur.
  void _followModeration(bool moderator) {
    if (_disposed) return;
    if (moderator != _wantModeration) {
      _wantModeration = moderator;
      if (!moderator) state = state.copyWith(reported: const []);
      _connect();
    }
    if (moderator) unawaited(_readQueue());
  }

  Future<void> _readQueue() async {
    if (!_wantModeration) return;
    try {
      final queue = await _repository.moderationQueue();
      if (_disposed) return;
      state = state.copyWith(reported: queue.items);
    } catch (error) {
      lastFailure = error;
    }
  }

  // ---------------------------------------------------------------------------
  // Les gestes
  // ---------------------------------------------------------------------------

  /// **Une réaction : elle monte tout de suite**, et part au serveur.
  ///
  /// Un refus est **silencieux** — 429 compris (20 réactions / 10 s) : une
  /// réaction n'a pas de texte, et lui donner une erreur à l'écran pour un
  /// cœur de trop serait disproportionné.
  void react(RadioReaction reaction) {
    _emit(RadioReactionBurst(reaction, 1, own: true));
    _ownPending[reaction] = (_ownPending[reaction] ?? 0) + 1;
    unawaited(
      _heardTime()
          .then((heard) => _repository.react(reaction, heardAt: heard))
          .catchError((Object error) {
        // Elle ne reviendra dans aucun agrégat : ne plus l'attendre.
        final pending = _ownPending[reaction] ?? 0;
        if (pending > 0) _ownPending[reaction] = pending - 1;
        lastFailure = error;
      }),
    );
  }

  /// **Envoie un commentaire.** Le texte est nettoyé côté serveur ; ici on
  /// refuse seulement le vide, pour ne pas faire un aller-retour pour rien.
  Future<RadioSendOutcome> send(String body) async {
    final text = body.trim();
    if (text.isEmpty || text.length > kRadioCommentMaxLength) {
      return RadioSendOutcome.invalid;
    }
    try {
      // L'heure entendue **au geste** : le serveur en tire `airedAt`.
      final heardAt = await _heardTime();
      final comment = await _repository.postComment(text, heardAt: heardAt);
      _aired.removeWhere((item) => item.commentId == comment.id);
      _append(comment);
      return RadioSendOutcome.sent;
    } on RadioLiveException catch (error) {
      lastFailure = error;
      switch (error.refusal) {
        case RadioLiveRefusal.pseudonymRequired:
          return RadioSendOutcome.pseudonymRequired;
        case RadioLiveRefusal.silenced:
          if (!_disposed) {
            state =
                state.copyWith(viewer: state.viewer.copyWith(silenced: true));
          }
          return RadioSendOutcome.silenced;
        case RadioLiveRefusal.closed:
          // Le serveur dit qu'il n'y a pas de direct : on le croit, même si
          // `live.ended` s'est perdu en route.
          _close();
          return RadioSendOutcome.closed;
        case RadioLiveRefusal.throttled:
          return RadioSendOutcome.throttled;
        case RadioLiveRefusal.invalid:
          return RadioSendOutcome.invalid;
        default:
          return RadioSendOutcome.failed;
      }
    } catch (error) {
      lastFailure = error;
      return RadioSendOutcome.failed;
    }
  }

  /// **Enregistre le pseudo d'un invité** — le serveur s'en souvient, lié au
  /// jeton d'appareil : les fois suivantes, l'invité écrit directement.
  Future<RadioPseudonymOutcome> savePseudonym(String pseudonym) async {
    final text = pseudonym.trim();
    if (text.length < kRadioPseudonymMin || text.length > kRadioPseudonymMax) {
      return RadioPseudonymOutcome.invalid;
    }
    try {
      final saved = await _repository.savePseudonym(text);
      if (!_disposed) {
        state = state.copyWith(viewer: state.viewer.copyWith(pseudonym: saved));
      }
      return RadioPseudonymOutcome.saved;
    } on RadioLiveException catch (error) {
      lastFailure = error;
      return switch (error.refusal) {
        RadioLiveRefusal.pseudonymInvalid ||
        RadioLiveRefusal.invalid =>
          RadioPseudonymOutcome.invalid,
        RadioLiveRefusal.throttled => RadioPseudonymOutcome.throttled,
        _ => RadioPseudonymOutcome.failed,
      };
    } catch (error) {
      lastFailure = error;
      return RadioPseudonymOutcome.failed;
    }
  }

  /// **Signale un message.** Il reste visible jusqu'à ce qu'un modérateur
  /// tranche (décision 6) : rien ne change à l'écran.
  Future<RadioReportOutcome> report(String commentId) async {
    try {
      await _repository.report(commentId);
      return RadioReportOutcome.reported;
    } on RadioLiveException catch (error) {
      lastFailure = error;
      return switch (error.refusal) {
        RadioLiveRefusal.alreadyReported => RadioReportOutcome.alreadyReported,
        RadioLiveRefusal.pseudonymRequired =>
          RadioReportOutcome.pseudonymRequired,
        RadioLiveRefusal.notFound ||
        RadioLiveRefusal.closed =>
          RadioReportOutcome.gone,
        _ => RadioReportOutcome.failed,
      };
    } catch (error) {
      lastFailure = error;
      return RadioReportOutcome.failed;
    }
  }

  /// **Masque un message** : il quitte le fil et la file, ici tout de suite —
  /// les autres le verront partir par `comment.hidden`.
  Future<RadioModerationOutcome> hide(String commentId) =>
      _moderate(() => _repository.hide(commentId), () => _forget(commentId));

  /// **Garde un message signalé** : il quitte la file, il reste au fil.
  Future<RadioModerationOutcome> keep(String commentId) => _moderate(
        () => _repository.keep(commentId),
        () {
          if (_disposed) return;
          state = state.copyWith(
            reported: [
              for (final item in state.reported)
                if (item.comment.id != commentId) item,
            ],
          );
        },
      );

  /// **Réduit l'auteur au silence** jusqu'à la fin du direct. Rien n'est
  /// annoncé à l'audience (contrat serveur) : le fil ne change pas.
  Future<RadioModerationOutcome> silence(String commentId) =>
      _moderate(() => _repository.silence(commentId), () {});

  /// **Réinitialise le pseudo d'un invité** : il devra en choisir un autre.
  Future<RadioModerationOutcome> resetPseudonym(String commentId) =>
      _moderate(() => _repository.resetPseudonym(commentId), () {});

  Future<RadioModerationOutcome> _moderate(
    Future<void> Function() call,
    void Function() onDone,
  ) async {
    try {
      await call();
      onDone();
      return RadioModerationOutcome.done;
    } on RadioLiveException catch (error) {
      lastFailure = error;
      return switch (error.refusal) {
        RadioLiveRefusal.notGuest => RadioModerationOutcome.notGuest,
        RadioLiveRefusal.notFound ||
        RadioLiveRefusal.closed =>
          RadioModerationOutcome.gone,
        _ => RadioModerationOutcome.failed,
      };
    } catch (error) {
      lastFailure = error;
      return RadioModerationOutcome.failed;
    }
  }

  void _dispose() {
    _disposed = true;
    _disconnect();
    _aired.clear();
    _airedTimer?.cancel();
    _airedTimer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    unawaited(_bursts.close());
  }
}
