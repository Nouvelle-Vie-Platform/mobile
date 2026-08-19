/// **L'orchestrateur du temps-réel** — SSE → sync, jamais SSE → peindre.
///
/// `RealtimeService` est la pièce **dédiée** décrite au §2 de
/// `docs/temps-reel-sse.md` : elle possède un [TransmitClient], observe le cycle
/// de vie de l'application et le flux Drift de mes appartenances, coalesce les
/// événements reçus, et déclenche une **sync** ([SyncTrigger.realtime]). Elle est
/// **hors** de `lib/data/sync/` à dessein — voir « pourquoi le Timer est ici »
/// plus bas. Chacune de ses décisions vient d'une décision figée de la note :
///
/// - **D1 — SSE → sync, pas SSE → peindre.** Un événement ne sert qu'à savoir
///   qu'*il s'est passé quelque chose* : le service **ne lit pas** la charge utile
///   ([TransmitEvent.payload] est ignorée), il appelle [_onRealtimeSignal] et
///   laisse le flux delta de `/sync` ramener le message. « Le réseau ne peint
///   jamais » (ADR-0026).
/// - **D2 — Abonnement large.** On s'abonne à **tous mes groupes/DM** sur une
///   seule connexion (Transmit multiplexe) — un DM **est** une ligne `groups`,
///   donc le canal commun `groups/{id}` ([channelForGroup]) rend la liste
///   « Échanges » *et* le fil ouvert temps-réel du même coup.
/// - **D3 — Premier plan seulement.** La connexion s'ouvre à
///   `AppLifecycleState.resumed`, se ferme à `paused`. L'arrière-plan (app
///   fermée) est le rôle du FCM, hors périmètre.
/// - **D4 — Rattrapage à chaque (re)connexion.** À chaque ouverture on déclenche
///   une sync : ce qui a été émis pendant un trou SSE est rejoué par le curseur
///   `?since`. Redondant avec la sync de premier plan **exprès** — c'est le filet
///   qui garantit la non-perte, et le planificateur la coalesce de toute façon (un
///   déclenchement pendant qu'un cycle tourne rejoint ce cycle).
/// - **D5 — Coalescing ~300 ms.** Un fil actif émet en rafale ; on regroupe les
///   événements rapprochés en **une** sync via un [Timer] local, pour ne pas
///   marteler `/sync`.
/// - **D7 — Réabonnement réactif.** On observe le flux Drift des identifiants de
///   mes appartenances ([GroupDao.watchMyGroupIds]) ; à chaque changement on
///   **diffe** l'ensemble désiré et (dés)abonne les canaux correspondants. Ça
///   couvre le nouveau DM : sa première ligne d'appartenance arrive par la sync
///   (qui amène aussi le 1ᵉʳ message), on s'abonne alors, les suivants sont live.
///
/// **Pourquoi le Timer de coalescing vit ICI et pas dans le moteur.** Le
/// garde-fou du dépôt « aucun `Timer` dans `lib/data/sync/` » (un test le vérifie
/// sur la source) interdit tout intervalle au socle : un `Timer` là-bas ne se
/// distinguerait pas d'un polling, or le moteur ne sonde jamais. Le debounce de
/// coalescing **n'est pas** un polling — il ne se rallume pas tout seul, il ne
/// s'arme que lorsqu'un événement *poussé* arrive — mais pour que la règle reste
/// simple et vérifiable, la minuterie vit dans ce service, en dehors du socle.
/// Le moteur, lui, reçoit un cycle de plus, jamais une horloge.
///
/// **Double inerte, aucune socket en test.** Le défaut hors backend est
/// [InertTransmitClient] (flux vide) : aucun événement, donc aucune sync
/// déclenchée par le temps-réel. Un test qui veut prouver le déclenchement injecte
/// un faux client qui émet à la demande.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'transmit_client.dart';

/// Orchestre le temps-réel : cycle de vie, abonnements, coalescing.
///
/// **Ne possède pas** le socle de synchronisation : il l'atteint par le callback
/// [_onRealtimeSignal], que le câblage (`app.dart`) branche sur
/// `scheduler.trigger(SyncTrigger.realtime)`. Le service reste ainsi ignorant du
/// moteur — il sait seulement « déclencher une sync ».
class RealtimeService with WidgetsBindingObserver {
  RealtimeService({
    required TransmitClient client,
    required Stream<List<String>> myGroupIds,
    required Future<void> Function() onRealtimeSignal,
    WidgetsBinding? binding,
    Duration coalesceWindow = const Duration(milliseconds: 300),
  })  : _client = client,
        _myGroupIds = myGroupIds,
        _onRealtimeSignal = onRealtimeSignal,
        _binding = binding,
        _coalesceWindow = coalesceWindow;

  final TransmitClient _client;

  /// Le flux des identifiants de mes appartenances (source du réabonnement
  /// réactif, D7). Typiquement `groupDao.watchMyGroupIds(userId).watch()`.
  final Stream<List<String>> _myGroupIds;

  /// Le pont vers le socle : `() => scheduler.trigger(SyncTrigger.realtime)`.
  /// Ne **lève pas** (le planificateur retient l'échec, il ne le propage pas).
  final Future<void> Function() _onRealtimeSignal;

  final WidgetsBinding? _binding;
  final Duration _coalesceWindow;

  /// Le motif de canal Transmit, **unique** dans le code : groupes ET DM
  /// partagent `groups/{id}` (D2). C'est la seule frontière entre un identifiant
  /// de groupe et un nom de canal.
  @visibleForTesting
  static String channelForGroup(String groupId) => 'groups/$groupId';

  /// Le **canal réservé du battement de cœur** de Transmit. C'est une trame bien
  /// formée (pas un commentaire SSE `:`), donc elle traverse le décodage et
  /// arrive ici comme un événement — mais elle ne signale **aucun** message. On
  /// ne déclenche donc pas de sync dessus. Aujourd'hui le serveur a
  /// `pingInterval: false` (aucun ping émis), mais l'ignorer ici évite qu'activer
  /// le heartbeat un jour ne déclenche une sync **par battement** — un piège qui
  /// ne se verrait qu'à l'usage.
  static const String _pingChannel = r'$$transmit/ping';

  /// Les canaux **désirés** (l'image miroir de mes appartenances). Conservé même
  /// connexion fermée, pour differ correctement un changement survenu en
  /// arrière-plan et pour ré-affirmer les abonnements à la reconnexion.
  final Set<String> _subscribed = <String>{};

  StreamSubscription<List<String>>? _membershipSub;
  StreamSubscription<TransmitEvent>? _eventsSub;
  Timer? _coalesceTimer;

  bool _started = false;
  bool _connected = false;

  /// **Démarre** l'orchestration : observe le cycle de vie, branche le flux
  /// d'appartenances et le flux d'événements, puis ouvre la connexion.
  ///
  /// Appelé au premier frame par `app.dart`, sous `AppEnv.useBackend`, l'app est
  /// alors au **premier plan** : on connecte donc d'emblée (l'observateur, lui,
  /// n'entend que les transitions *suivantes*). Idempotent.
  void start() {
    if (_started) return;
    _started = true;

    (_binding ?? WidgetsBinding.instance).addObserver(this);

    // Le flux d'événements est **broadcast** et survit aux disconnect/connect
    // (il se tait puis reprend) : on l'écoute **une seule fois**, pour toute la
    // vie du service. On ignore la charge utile (D1) — un événement ne sert qu'à
    // armer le coalescing.
    _eventsSub = _client.events.listen((event) {
      if (event.channel == _pingChannel) return; // heartbeat : pas un message
      _coalesceSignal();
    });

    // Le flux d'appartenances émet sa valeur courante à l'abonnement : le premier
    // événement pose l'ensemble initial de canaux (retenus par le client tant que
    // la connexion n'est pas ouverte). On l'écoute **avant** de connecter, pour
    // que les intentions soient déjà là quand la connexion s'établit.
    _membershipSub = _myGroupIds.listen(_reconcileSubscriptions);

    unawaited(_openConnection());
  }

  /// **Cycle de vie (D3).** Premier plan → connexion ; arrière-plan → fermeture.
  ///
  /// On n'attend pas les futures ici (la signature est synchrone) : `connect` /
  /// `disconnect` ne lèvent pas et gèrent seuls leur backoff.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_openConnection());
      case AppLifecycleState.paused:
        unawaited(_closeConnection());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Ni ouverture ni fermeture : `inactive`/`hidden` sont des états de
        // transition (bascule d'app, tiroir de notifications) où couper la
        // connexion la rouvrirait aussitôt. Seul `paused` ferme (D3).
        break;
    }
  }

  Future<void> _openConnection() async {
    if (_connected) return;
    _connected = true; // posé **avant** l'await : un double `resumed` ne
    // rouvre pas.
    await _client.connect();

    // Ré-affirme les abonnements désirés. Le contrat n'**oblige** pas
    // l'implémentation à conserver ceux d'une connexion précédemment fermée
    // (« peuvent être conservés ») : on les repose donc, c'est idempotent et bon
    // marché, et ça garantit D2 quelle que soit la politique de rétention.
    for (final channel in _subscribed) {
      unawaited(_client.subscribe(channel));
    }

    // D4 — rattrapage : à chaque (ré)ouverture, une sync.
    unawaited(_onRealtimeSignal());
  }

  Future<void> _closeConnection() async {
    if (!_connected) return;
    _connected = false;
    // Une coalescence en attente ne sert plus à rien en arrière-plan : le retour
    // au premier plan déclenchera de toute façon un rattrapage (D4).
    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    await _client.disconnect();
  }

  /// **Réabonnement réactif (D7).** Diffe l'ensemble désiré (mes appartenances,
  /// muées en canaux) contre l'ensemble courant, et (dés)abonne le delta.
  ///
  /// Fonctionne connexion **ouverte ou fermée** : à connexion fermée, le client
  /// retient l'intention pour le prochain `connect`. On tient [_subscribed] à
  /// jour dans les deux cas, pour que le prochain diff parte du bon état.
  void _reconcileSubscriptions(List<String> groupIds) {
    final desired = groupIds.map(channelForGroup).toSet();

    for (final channel in desired.difference(_subscribed)) {
      _subscribed.add(channel);
      unawaited(_client.subscribe(channel));
    }
    for (final channel in _subscribed.difference(desired).toList()) {
      _subscribed.remove(channel);
      unawaited(_client.unsubscribe(channel));
    }
  }

  /// **Coalescing (D5).** Le premier événement d'une rafale arme une fenêtre de
  /// [_coalesceWindow] ; les événements suivants dans la fenêtre sont absorbés (on
  /// ne réarme pas) ; à l'échéance, **une** sync part. Un `Timer` local, jamais
  /// un intervalle qui se rallume — voir l'en-tête du fichier.
  void _coalesceSignal() {
    if (_coalesceTimer?.isActive ?? false) return;
    _coalesceTimer = Timer(_coalesceWindow, () {
      _coalesceTimer = null;
      unawaited(_onRealtimeSignal());
    });
  }

  /// **Arrête** l'orchestration : se désabonne du cycle de vie et des flux, annule
  /// la coalescence en cours et ferme la connexion. Idempotent.
  void dispose() {
    if (!_started) return;
    _started = false;

    (_binding ?? WidgetsBinding.instance).removeObserver(this);
    unawaited(_membershipSub?.cancel());
    _membershipSub = null;
    unawaited(_eventsSub?.cancel());
    _eventsSub = null;
    _coalesceTimer?.cancel();
    _coalesceTimer = null;

    _connected = false;
    unawaited(_client.disconnect());
  }
}
