/// **Le battement d'écoute** — « cet appareil écoute l'antenne en ce moment »
/// (décision 7 du plan `server-portal/docs/radio-adaptative-plan.md`).
///
/// Le serveur compte les identifiants vus depuis 150 s : c'est ce qui donne
/// « N à l'écoute » une fois que MediaMTX ne voit plus les auditeurs (liquidsoap
/// écrit le HLS, Caddy le sert en fichiers), et c'est exact derrière le NAT des
/// opérateurs, là où compter les adresses ne l'était pas.
///
/// Une seule entrée, [onStatus], branchée sur l'état de `RadioListening` :
///
/// - **en lecture** : la séance s'ouvre si elle ne l'est pas — `listenId` neuf,
///   un battement tout de suite, puis toutes les [kRadioHeartbeatInterval] ;
/// - **connexion, « Connexion instable… », « Reconnexion… »** : la séance
///   reste ouverte, mais les battements se taisent. Un échec n'est pas une
///   écoute, et une coupure — même longue, la reprise n'abandonne jamais — ne
///   doit pas changer d'identifiant ;
/// - **au repos** — arrêt, pause : la séance se ferme. Le prochain démarrage
///   par l'auditeur aura un identifiant neuf.
///
/// La minuterie ne repart pas de zéro au retour de la lecture, et c'est voulu :
/// une antenne qui hoquette ferait sinon partir un battement à chaque reprise,
/// et le serveur répondrait 429.
///
/// **Les échecs sont muets** : rien ne remonte vers la lecture, rien n'est
/// réessayé. Un battement perdu est rattrapé par le suivant, bien avant les
/// 150 s.
library;

import 'dart:async';

import 'package:uuid/uuid.dart';

import 'radio_status.dart';

/// La cadence des battements. Le serveur oublie un identifiant après 150 s :
/// deux battements perdus d'affilée restent tolérés.
const Duration kRadioHeartbeatInterval = Duration(seconds: 60);

class RadioHeartbeat {
  RadioHeartbeat({
    required Future<void> Function(String listenId) send,
    String Function()? mintListenId,
    Duration interval = kRadioHeartbeatInterval,
  })  : _send = send,
        _mintListenId = mintListenId ?? (() => const Uuid().v4()),
        _interval = interval;

  final Future<void> Function(String listenId) _send;
  final String Function() _mintListenId;
  final Duration _interval;

  /// L'identifiant de la séance en cours, `null` hors séance.
  String? _listenId;
  Timer? _timer;
  bool _playing = false;

  /// L'identifiant de la séance en cours — pour les tests.
  String? get listenId => _listenId;

  /// Idempotent : la même valeur répétée ne fait rien de plus.
  void onStatus(RadioStatus status) {
    switch (status.phase) {
      case RadioPhase.playing:
        _playing = true;
        if (_listenId != null) return;
        _listenId = _mintListenId();
        _beat();
        _timer = Timer.periodic(_interval, (_) {
          if (_playing) _beat();
        });
      case RadioPhase.idle:
        _close();
      default:
        _playing = false;
    }
  }

  void dispose() => _close();

  void _beat() {
    final id = _listenId;
    if (id == null) return;
    // `Future.sync` : même une levée synchrone de [_send] reste muette.
    unawaited(
      Future.sync(() => _send(id)).then((_) {}, onError: (Object _) {}),
    );
  }

  void _close() {
    _timer?.cancel();
    _timer = null;
    _listenId = null;
    _playing = false;
  }
}
