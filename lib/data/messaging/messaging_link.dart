/// **Le lien temps réel de la messagerie : ouvert au premier plan, session
/// ouverte, et fermé sinon** (#140).
///
/// Il tient le canal `users/{monId}` et fait trois choses de ce qu'il reçoit :
///
/// 1. **une ligne** → elle est rangée dans le magasin, par la même fonction que
///    la ligne de synchronisation ([MessagingStoreWriter]) ; si elle cite un
///    groupe que le magasin ne connaît pas, **un cycle** suit pour ramener le
///    reste (profils, roster) ;
/// 2. **l'ouverture** (première ou reconnexion) → **un cycle** de rattrapage. Un
///    canal neuf n'a aucune mémoire de ce qui s'est diffusé pendant la coupure,
///    et la synchronisation ne perd rien (piège 4 du plan) ;
/// 3. **le silence** → au-delà de [kMessagingSilenceLimit] sans rien recevoir —
///    ni ligne, ni battement —, la connexion est morte même si le système ne l'a
///    pas dit : on la ferme et on en rouvre une. **Seulement si un battement a
///    été vu sur cette connexion** : le chien de garde est adaptatif (voir
///    plus bas).
///
/// ## Le chien de garde ne s'arme qu'après un battement
///
/// Le serveur n'émet pas de battement pour l'instant (`pingInterval` retiré :
/// l'application installée prendrait chaque trame pour un signal). Sans
/// battement, un canal calme est **muet par nature** : reconnecter après 60 s
/// de silence rouvrirait le canal chaque minute, avec un cycle à chaque fois.
/// Le constat de silence ne s'arme donc qu'au premier `$$transmit/ping` reçu
/// sur la connexion **courante** — chaque connexion repart désarmée. Le jour
/// où le serveur réactive le battement, le client s'y met tout seul. La
/// reconnexion sur erreur ou fermeture, elle, ne dépend de rien.
///
/// ## Portée : tant que l'application est au premier plan
///
/// Un seul canal pour **toutes** les discussions, et non plus un par fil
/// affiché : la liste, le badge et le fil se tiennent à jour ensemble. En
/// arrière-plan, la connexion est fermée proprement (`paused`, `hidden`,
/// `detached`) plutôt que de mourir sur une pile réseau suspendue ; le réveil
/// push reste le seul messager d'une application qui dort. Le retour rouvre, et
/// l'ouverture déclenche le cycle.
///
/// ## Pourquoi une minuterie, alors que le dépôt interdit le sondage
///
/// Deux minuteries, et aucune ne sonde le moteur : l'une **rouvre** une
/// connexion tombée ([kMessagingRetryDelay]), l'autre **constate** un silence.
/// Un échec de réouverture ne déclenche aucun cycle — seul un abonnement réussi
/// en déclenche un. Et elles ne vivent qu'au premier plan.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'messaging_channel.dart';

/// Le délai avant de rouvrir un canal tombé. Le même que celui du canal par
/// groupe de #101 : assez court pour qu'un trou ne se remarque pas dans une
/// conversation, assez long pour ne pas marteler un serveur injoignable.
const Duration kMessagingRetryDelay = Duration(seconds: 10);

/// **Le silence qui vaut une mort**, une fois le battement constaté : quand le
/// serveur bat (25 s, `config/transmit.ts`), deux battements manqués et un peu
/// de marge. Sans battement vu, aucun silence ne vaut une mort.
const Duration kMessagingSilenceLimit = Duration(seconds: 60);

/// Tient le canal `users/{userId}` ouvert tant que l'application est au premier
/// plan.
class MessagingLink with WidgetsBindingObserver {
  MessagingLink({
    required this.userId,
    required MessagingChannel channel,
    required Future<bool> Function(MessagingRowEvent event) apply,
    required Future<void> Function() resynchronize,
    Duration retryDelay = kMessagingRetryDelay,
    Duration silenceLimit = kMessagingSilenceLimit,
    WidgetsBinding? binding,
  })  : _channel = channel,
        _apply = apply,
        _resynchronize = resynchronize,
        _retryDelay = retryDelay,
        _silenceLimit = silenceLimit,
        _binding = binding;

  /// Moi : le seul canal auquel ce porteur a droit.
  final String userId;

  final MessagingChannel _channel;

  /// **Range une ligne**, et dit si le groupe qu'elle cite était connu.
  /// Injecté : c'est [MessagingStoreWriter.store] en production.
  final Future<bool> Function(MessagingRowEvent event) _apply;

  /// **Demande un cycle de synchronisation.** Injecté, comme partout.
  final Future<void> Function() _resynchronize;

  final Duration _retryDelay;
  final Duration _silenceLimit;
  final WidgetsBinding? _binding;

  StreamSubscription<MessagingEvent>? _subscription;
  Timer? _reopen;
  Timer? _silence;
  bool _wanted = false;
  bool _observing = false;

  /// La connexion **courante** a reçu au moins un battement : le constat de
  /// silence est armé. Remis à faux à chaque connexion.
  bool _heartbeatSeen = false;

  /// Les lignes se rangent **une à une, dans l'ordre d'arrivée** : un message
  /// créé puis supprimé dans la même seconde ne doit pas se ranger à l'envers.
  Future<void> _queue = Future<void>.value();

  /// La dernière panne, `null` si tout va bien. Retenue, **jamais propagée** :
  /// l'application fonctionne pareil sans temps réel, le cycle suivant ramène
  /// tout.
  Object? lastFailure;

  /// Une connexion est en place (ou en train de s'établir).
  bool get isConnected => _subscription != null;

  /// **Ouvre le lien**, et s'abonne au cycle de vie. Idempotent.
  void open() {
    if (_wanted) return;
    _wanted = true;
    if (!_observing) {
      (_binding ?? WidgetsBinding.instance).addObserver(this);
      _observing = true;
    }
    _connect();
  }

  /// **Ferme le lien** (fin de session, jet du provider). Idempotent.
  Future<void> close() async {
    _wanted = false;
    if (_observing) {
      (_binding ?? WidgetsBinding.instance).removeObserver(this);
      _observing = false;
    }
    await _disconnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_wanted) return;
    if (state == AppLifecycleState.resumed) {
      // Une connexion saine (`inactive` seul n'a rien fermé) n'a pas à être
      // rouverte : ça coûterait un cycle pour rien.
      if (!isConnected) _connect();
      return;
    }
    // `inactive` est transitoire (une alerte système) ; les trois autres disent
    // que la pile réseau ne nous appartient plus.
    if (state != AppLifecycleState.inactive) _disconnect();
  }

  void _connect() {
    if (!_wanted) return;
    _disconnect();
    _heartbeatSeen = false;
    _subscription = _channel.watch(userId).listen(
      _onEvent,
      onError: (Object error) {
        lastFailure = error;
        _subscription = null;
        _silence?.cancel();
        // Un **refus** ne se réessaie pas : un invité n'a pas de canal, et
        // insister ne changerait pas la réponse.
        if (error is MessagingChannelRefused) return;
        _reopenLater();
      },
      onDone: () {
        _subscription = null;
        _silence?.cancel();
        _reopenLater();
      },
      cancelOnError: true,
    );
  }

  void _onEvent(MessagingEvent event) {
    if (event is MessagingHeartbeat) _heartbeatSeen = true;
    _armSilence();
    switch (event) {
      case MessagingChannelOpened():
        lastFailure = null;
        _cycle();
      case MessagingHeartbeat():
        break;
      case final MessagingRowEvent row:
        _queue = _queue.then((_) => _store(row));
    }
  }

  Future<void> _store(MessagingRowEvent event) async {
    try {
      final known = await _apply(event);
      if (!known) _cycle();
    } catch (error) {
      // Une ligne qu'on n'a pas su ranger (mal formée, base occupée) n'est pas
      // perdue : le cycle la ramènera par le tirage.
      lastFailure = error;
      _cycle();
    }
  }

  Future<void> _disconnect() async {
    _reopen?.cancel();
    _reopen = null;
    _silence?.cancel();
    _silence = null;
    final open = _subscription;
    _subscription = null;
    await open?.cancel();
  }

  void _reopenLater() {
    if (!_wanted) return;
    _reopen?.cancel();
    _reopen = Timer(_retryDelay, _connect);
  }

  /// (Ré)arme le constat de silence : rien reçu pendant [_silenceLimit], la
  /// connexion est rouverte — avec un `uid` neuf, et un cycle à l'ouverture.
  /// **Sans battement vu sur cette connexion, ne fait rien** : un serveur qui
  /// ne bat pas laisse un canal calme muet, et ce silence-là n'est pas une mort.
  void _armSilence() {
    if (!_heartbeatSeen) return;
    _silence?.cancel();
    _silence = Timer(_silenceLimit, () {
      if (!_wanted) return;
      _connect();
    });
  }

  /// Demande un cycle et **avale tout** : une synchronisation qui échoue n'est
  /// pas une erreur d'application. Pas de `Future(…)` : il passe par une
  /// minuterie que personne ne possède, et le harnais de test l'attendrait.
  void _cycle() {
    try {
      _resynchronize().catchError((Object error) => lastFailure = error);
    } catch (error) {
      lastFailure = error;
    }
  }
}
