/// **Le canal d'un fil ouvert : ouvert avec l'écran, fermé avec lui** (#101).
///
/// Une seule règle, et elle tient en une phrase : **tout signal déclenche un
/// cycle de synchronisation, et rien d'autre**. L'objet ne lit aucune charge
/// utile, n'écrit rien, ne rend rien à peindre. Il traduit « va voir » en un appel
/// au planificateur, exactement comme le fera le réveil push (ADR-0006,
/// ADR-0017).
///
/// ## Portée : pendant que l'écran est affiché, et pas une seconde de plus
///
/// Pas d'abonnement permanent à tous ses groupes. Une connexion ouverte coûte de
/// la batterie et du forfait, et au Togo le second compte autant que la première ;
/// un membre de huit groupes n'a pas besoin de huit connexions pour lire un fil à
/// la fois. La durée de vie est portée par `openThreadChannelProvider`
/// (`lib/state/echanges_providers.dart`), `autoDispose` et clé par groupe : l'écran
/// l'observe, Riverpod le jette quand l'écran s'en va, et [close] rend la socket.
///
/// ## Les trois pièges, qui sont la vraie difficulté de la tranche
///
/// 1. **La reconnexion n'a aucune mémoire** de ce qui est passé pendant la
///    coupure : rien dans le flux ne rattrape le trou. C'est pourquoi l'ouverture
///    du canal est elle-même un signal (voir [GroupChannelSignal]) — toute
///    reconnexion déclenche donc un cycle, et c'est le moteur qui comble le trou.
/// 2. **Le flux ne se ferme pas tout seul** au démontage de l'écran. Si personne
///    n'annule, la connexion survit à l'écran — et, sous `flutter test`, le
///    harnais attend indéfiniment une minuterie que plus rien ne possède.
/// 3. **Le passage en arrière-plan ferme proprement**, plutôt que de laisser la
///    connexion mourir en silence sur une pile réseau suspendue. Le retour
///    déclenche un cycle **avant** de rouvrir : le rattrapage ne doit pas dépendre
///    de la réussite d'une réouverture, qui peut très bien échouer (on revient
///    souvent d'arrière-plan dans un ascenseur).
///
/// ## Pourquoi une minuterie ici, alors que le dépôt interdit le sondage
///
/// La minuterie ne sonde **rien** : elle rouvre une connexion tombée, et un échec
/// de réouverture ne déclenche aucun cycle (seul un abonnement réussi en
/// déclenche un). Une réouverture est donc une tentative de connexion, jamais une
/// requête au moteur — l'interdit d'ADR-0017 tient. Et elle ne tourne que pendant
/// qu'un fil est affiché : sa durée est bornée par l'attention de quelqu'un.
///
/// Pas de repli exponentiel, délibérément : sur un écran qu'on regarde, un fil
/// qu'on vient d'ouvrir doit rattraper vite, et un délai qui doublerait finirait
/// par rendre le temps réel inutile au moment où il sert le plus — une connexion
/// instable.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'group_channel.dart';

/// Le délai avant de rouvrir un canal tombé. Nommé **une seule fois**.
///
/// **Valeur à confirmer**, comme `kPlaybackStallTimeout` : assez court pour qu'un
/// trou de réseau ne se remarque pas dans une conversation, assez long pour ne pas
/// marteler un serveur injoignable pendant qu'on relit un fil.
const Duration kGroupChannelRetryDelay = Duration(seconds: 10);

/// Tient le canal d'un groupe ouvert tant que son écran est affiché.
class OpenThreadChannel with WidgetsBindingObserver {
  OpenThreadChannel({
    required this.groupId,
    required GroupChannel channel,
    required Future<void> Function() resynchronize,
    Duration retryDelay = kGroupChannelRetryDelay,
    WidgetsBinding? binding,
  })  : _channel = channel,
        _resynchronize = resynchronize,
        _retryDelay = retryDelay,
        _binding = binding;

  /// Le groupe dont le fil est affiché.
  final String groupId;

  final GroupChannel _channel;

  /// **Le seul effet de cet objet** : demander un cycle. Injecté, comme partout
  /// ailleurs dans ce dépôt — et c'est lui qui rend vérifiable le fait qu'un
  /// signal n'écrit rien lui-même.
  final Future<void> Function() _resynchronize;

  final Duration _retryDelay;
  final WidgetsBinding? _binding;

  StreamSubscription<GroupChannelSignal>? _subscription;
  Timer? _reopen;
  bool _wanted = false;
  bool _observing = false;

  /// La dernière panne du canal, `null` si la connexion tient ou a été fermée
  /// proprement.
  ///
  /// Retenue, **jamais propagée** : l'application doit fonctionner exactement
  /// pareil sans temps réel — le fil se remplit au cycle suivant, et aucune erreur
  /// ne paraît à l'écran. Elle est ici pour le diagnostic, comme
  /// `SyncScheduler.lastFailure`.
  Object? lastFailure;

  /// Une connexion est en place (ou en train de s'établir).
  bool get isConnected => _subscription != null;

  /// **Ouvre le canal**, et s'abonne au cycle de vie de l'application.
  ///
  /// Idempotent : un second appel ne rouvre pas une seconde connexion.
  void open() {
    if (_wanted) return;
    _wanted = true;
    if (!_observing) {
      (_binding ?? WidgetsBinding.instance).addObserver(this);
      _observing = true;
    }
    _connect();
  }

  /// **Ferme le canal** et se désabonne du cycle de vie. Idempotent.
  ///
  /// C'est ce que `ref.onDispose` appelle, et le seul endroit où la socket est
  /// rendue. Voir le piège 2 de l'en-tête.
  Future<void> close() async {
    _wanted = false;
    if (_observing) {
      (_binding ?? WidgetsBinding.instance).removeObserver(this);
      _observing = false;
    }
    await _disconnect();
  }

  /// **L'arrière-plan ferme, le retour rouvre — et le retour synchronise
  /// d'abord.**
  ///
  /// Le cycle part avant la réouverture (piège 3). Il rejoint celui que
  /// `SyncScheduler` lance de son côté au même moment pour la même raison — un
  /// cycle en vol est rejoint, jamais doublé —, et ce n'est pas une redondance
  /// inutile : sans cet appel, le rattrapage d'un fil ouvert dépendrait du
  /// câblage d'un autre objet.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_wanted) return;

    if (state == AppLifecycleState.resumed) {
      // Rien à faire si la connexion n'a pas été coupée : `inactive` seul (une
      // alerte système, le sélecteur d'applications effleuré) n'a rien fermé, et
      // rouvrir une connexion saine coûterait un cycle pour rien.
      if (isConnected) return;
      _cycle();
      _connect();
      return;
    }

    // `inactive` est transitoire et ne dit pas qu'on part : fermer dessus
    // couperait le canal à chaque alerte système. `paused`, `hidden` et
    // `detached` disent que la pile réseau ne nous appartient plus.
    if (state != AppLifecycleState.inactive) _disconnect();
  }

  /// Ferme ce qui est ouvert, puis (r)ouvre. Le `_wanted` reste intact : cet
  /// objet est toujours censé écouter.
  void _connect() {
    if (!_wanted) return;
    _disconnect();
    _subscription = _channel.watch(groupId).listen(
      // **La ligne qui porte toute la tranche** : un signal, un cycle. Pas de
      // charge utile lue, pas d'écriture — il n'y a d'ailleurs rien à lire dans
      // un [GroupChannelSignal].
      (_) {
        lastFailure = null;
        _cycle();
      },
      onError: (Object error) {
        lastFailure = error;
        _subscription = null;
        // Un **refus** ne se réessaie pas : le canal est réservé aux membres, et
        // insister ne changerait pas la réponse. L'écran continue de vivre du
        // magasin, ce qui est exactement le régime « sans SSE ».
        if (error is GroupChannelRefused) return;
        _reopenLater();
      },
      // Le serveur a rendu la main : le canal est tombé, on le rouvre.
      onDone: () {
        _subscription = null;
        _reopenLater();
      },
      cancelOnError: true,
    );
  }

  Future<void> _disconnect() async {
    _reopen?.cancel();
    _reopen = null;
    final open = _subscription;
    _subscription = null;
    await open?.cancel();
  }

  void _reopenLater() {
    if (!_wanted) return;
    _reopen?.cancel();
    _reopen = Timer(_retryDelay, _connect);
  }

  /// Demande un cycle, et **avale tout**.
  ///
  /// Une synchronisation qui échoue n'est pas une erreur d'application : le
  /// magasin garde ce qu'il avait, les écrans continuent de peindre, et le cycle
  /// se rejoue au prochain déclencheur. Laisser une erreur remonter d'ici la
  /// ferait paraître à l'écran d'une conversation, pour une cause que personne ne
  /// peut corriger.
  ///
  /// Appelé **sans passer par `Future(…)`** : celui-ci passe par `Timer.run`, et
  /// une minuterie que personne ne possède fait attendre le harnais de test
  /// jusqu'à expiration.
  void _cycle() {
    try {
      _resynchronize().catchError((Object error) => lastFailure = error);
    } catch (error) {
      lastFailure = error;
    }
  }
}
