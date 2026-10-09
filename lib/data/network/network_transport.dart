import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// **Par quel tuyau l'appareil passe** — et rien d'autre.
///
/// Cette abstraction ne dit **pas** si l'appareil a internet, et ne doit jamais
/// être détournée pour le dire. La distinction est celle que `CLAUDE.md` pose
/// déjà : `connectivity_plus` répond « connecté » derrière un portail captif,
/// c'est-à-dire exactement quand sa réponse compterait ; la panne d'écoute
/// continue donc de se déduire de l'échec lui-même (§ « La panne en cours
/// d'écoute »). Lire le *type* de transport est une autre question, et l'OS y
/// répond sans aller-retour réseau.
///
/// Un seul consommateur : le plafond de débit du lecteur, quand la qualité est
/// sur « Automatique ». Si un second apparaît un jour et qu'il a besoin de
/// savoir s'il y a du réseau, ce n'est pas ici qu'il faut l'ajouter.
abstract interface class NetworkTransport {
  /// `true` quand l'appareil passe par des données **mobiles**.
  ///
  /// Faux pour le wifi, l'ethernet, le VPN, le mode avion et l'inconnu. Le
  /// doute penche donc vers « pas de bridage » : brider à tort une écoute en
  /// wifi dégraderait le son sans rien économiser, alors que ne pas brider une
  /// écoute cellulaire coûte de la donnée — mais seulement à qui a laissé le
  /// réglage sur « Automatique », en connaissance de cause.
  Stream<bool> get onCellular;

  /// L'état courant, pour le premier plafond posé avant toute émission.
  Future<bool> isOnCellular();
}

/// L'implémentation réelle. **Le seul fichier du dépôt qui importe
/// `connectivity_plus`**, comme `just_audio_content_player.dart` est le seul à
/// importer `just_audio`.
class ConnectivityNetworkTransport implements NetworkTransport {
  ConnectivityNetworkTransport([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Le paquet rend une **liste** : un appareil peut être sur wifi et cellulaire
  /// en même temps (bascule en cours, partage de connexion). On ne considère le
  /// trajet comme cellulaire que si **aucun** transport non facturé n'est
  /// présent — sinon un téléphone qui garde son wifi actif en fond serait bridé
  /// pour rien.
  bool _isCellular(List<ConnectivityResult> results) {
    if (!results.contains(ConnectivityResult.mobile)) return false;
    const free = {
      ConnectivityResult.wifi,
      ConnectivityResult.ethernet,
      ConnectivityResult.vpn,
    };
    return !results.any(free.contains);
  }

  @override
  Stream<bool> get onCellular =>
      _connectivity.onConnectivityChanged.map(_isCellular).distinct();

  @override
  Future<bool> isOnCellular() async {
    try {
      return _isCellular(await _connectivity.checkConnectivity());
    } on Object catch (_) {
      // Un canal de plugin absent (test, plateforme incomplète) ne doit pas
      // empêcher la lecture : on rend « pas de données mobiles », donc pas de
      // bridage. Le mode automatique dégrade vers le comportement d'avant.
      return false;
    }
  }
}

/// **Y a-t-il un tuyau, quel qu'il soit ?** — une question *différente* de
/// [NetworkTransport], et surtout *différente* de « y a-t-il internet ».
///
/// Le dépôt refuse `connectivity_plus` pour trancher « y a-t-il internet » :
/// derrière un portail captif — un hôtel, un wifi d'église mal configuré — il
/// répond « connecté », c'est-à-dire précisément quand sa réponse compterait, et
/// la panne d'écoute se déduit donc de l'échec lui-même
/// (`ContentPlayback.hasStarted`, et l'en-tête de [NetworkTransport]).
/// **Ce n'est pas cette question-ci.** « Hors ligne » veut dire ici que l'OS ne
/// rapporte **aucun transport** (mode avion, radios coupées) : l'OS y répond en
/// local, sans aller-retour, et aucun portail captif ne peut le tromper.
///
/// Un seul décideur s'en sert — le routage offline-first d'un **partiel**
/// (#191, F11) : un fichier tronqué n'est servi que **hors ligne** ; en ligne on
/// préfère le HLS complet. La décision est robuste à l'imprécision du paquet : un
/// portail captif lu « en ligne » route simplement vers le HLS, dont l'échec est
/// déjà raconté par le lecteur (`_Stage.needsNetwork`) — jamais on ne prétend
/// être certain d'avoir internet. C'est ce qui rend cet usage acceptable là où
/// [NetworkTransport] refuse d'aller.
///
/// C'est ce que ce fichier anticipait : « si un second consommateur apparaît et
/// qu'il a besoin de savoir s'il y a du réseau, ce n'est pas dans
/// [NetworkTransport] qu'il faut l'ajouter ». Le voici, à côté, et non dedans.
///
/// La reprise radio (#179) s'y branche aussi, par
/// [ConnectivityNetworkStatus.onTransportChanged] : un **changement** de tuyau
/// avance un essai, rien de plus — jamais une décision « hors ligne ».
abstract interface class NetworkStatus {
  /// `true` quand l'OS ne rapporte **aucun** transport réseau.
  Future<bool> isOffline();
}

/// L'implémentation réelle, sur `connectivity_plus` — comme
/// [ConnectivityNetworkTransport], et rangée dans le **même** fichier pour que
/// « le seul fichier du dépôt qui importe `connectivity_plus` » reste vrai.
class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOffline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
    } on Object catch (_) {
      // Canal de plugin absent (test, plateforme incomplète) ou hoquet : on
      // répond **en ligne**, donc « préférer le HLS ». Le doute ne penche jamais
      // vers « hors ligne » : un faux « hors ligne » servirait un fichier
      // tronqué alors qu'un flux entier était disponible.
      return false;
    }
  }

  /// **« Un tuyau vient d'apparaître ou de changer »** — l'accélérateur de la
  /// reprise radio (#179, décision 9 du plan radio adaptative).
  ///
  /// Émet à chaque transport rapporté par l'OS qui **diffère du précédent et
  /// n'est pas « aucun »** : retour du wifi, passage du wifi aux données, mode
  /// avion levé. La perte du réseau n'émet **rien** : ce signal-là ment trop
  /// souvent (portail captif, iOS qui tarde à publier) pour qu'on le laisse
  /// suspendre quoi que ce soit — il ne sert qu'à avancer un essai.
  ///
  /// **Le point de départ vient de `checkConnectivity()`**, pas de la première
  /// valeur du flux. Android ne republie l'état courant à l'abonnement **que
  /// s'il existe un réseau** : abonné pendant une coupure — le cas même de la
  /// reprise radio —, il ne publie rien, et le retour du wifi devenait le point
  /// de départ, avalé. Mesuré sur émulateur le 09/10/2026 : la relance attendait
  /// la cadence de 5 s au lieu de partir au retour du réseau. Une valeur égale à
  /// la précédente (l'état courant republié) n'émet pas.
  /// L'état est **propre à chaque abonnement** (`Stream.multi`) — un
  /// abonnement repris à la prochaine coupure ne doit pas prendre l'état
  /// courant pour un changement. Une erreur du canal est tue : l'écoute ne
  /// dépend pas de ce signal.
  Stream<void> get onTransportChanged => Stream<void>.multi((out) {
        Set<ConnectivityResult>? last;
        _connectivity
            .checkConnectivity()
            .then((results) => last ??= results.toSet())
            .catchError((Object _) => <ConnectivityResult>{});
        final subscription = _connectivity.onConnectivityChanged.listen(
          (results) {
            final before = last;
            final now = results.toSet();
            last = now;
            if (before == null) return;
            if (now.isEmpty || now.contains(ConnectivityResult.none)) return;
            if (now.length == before.length && now.containsAll(before)) return;
            out.add(null);
          },
          onError: (Object _) {},
          onDone: out.close,
        );
        out.onCancel = subscription.cancel;
      });
}

/// État réseau **figé**, pour les tests et le double de maquette.
class FixedNetworkStatus implements NetworkStatus {
  const FixedNetworkStatus({bool offline = false}) : _offline = offline;

  final bool _offline;

  @override
  Future<bool> isOffline() async => _offline;
}

/// Transport **figé**, pour les tests et pour le double de maquette.
///
/// Aucun canal de plugin, aucune minuterie : c'est ce qui permet de vérifier la
/// règle du mode automatique sur la VM Dart, y compris la bascule en cours
/// d'écoute (`emit`).
class FixedNetworkTransport implements NetworkTransport {
  FixedNetworkTransport({bool cellular = false}) : _cellular = cellular;

  bool _cellular;
  final _controller = StreamController<bool>.broadcast();

  /// Simule un changement de réseau.
  void emit(bool cellular) {
    _cellular = cellular;
    _controller.add(cellular);
  }

  @override
  Stream<bool> get onCellular => _controller.stream;

  @override
  Future<bool> isOnCellular() async => _cellular;

  Future<void> dispose() => _controller.close();
}
