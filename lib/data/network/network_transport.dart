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
