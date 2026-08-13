import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// **Ce que l'application sait du binaire installé** : sa version affichable et
/// son numéro de build.
///
/// C'est la seule donnée d'« À propos » que le serveur ne peut pas servir. Le
/// portail publie une présentation, une mission, un contact ; il ne sait pas
/// quelle application est posée sur *ce* téléphone-ci — et c'est précisément le
/// renseignement qu'on demande à un fidèle quand il signale une anomalie.
@immutable
class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.build});

  /// Version affichable — `1.0.0`, la partie gauche de `version:` du
  /// `pubspec.yaml`.
  final String version;

  /// Numéro de build — `1`, la partie droite. Deux binaires peuvent porter la
  /// même version et des builds différents : c'est le second qui départage un
  /// rapport de bug.
  final String build;

  @override
  bool operator ==(Object other) =>
      other is AppVersionInfo &&
      other.version == version &&
      other.build == build;

  @override
  int get hashCode => Object.hash(version, build);
}

/// **Lire la version du binaire**, derrière une abstraction.
///
/// Même motif que `StatusImagePicker` (`lib/data/pickers/`) et
/// `ContentPlayer` : l'écran ne connaît que ce contrat, et les tests injectent
/// une implémentation qui ne touche aucun canal de plugin.
///
/// Rend `null` quand la version n'est pas connaissable. Ce n'est pas une
/// erreur, et surtout pas une phrase à afficher : l'écran omet simplement la
/// ligne. Une absence se dessine comme une absence — jamais « Version
/// inconnue », qui ressemblerait à une donnée.
abstract interface class AppVersionReader {
  Future<AppVersionInfo?> read();
}

/// Implémentation réelle : `package_info_plus`.
///
/// **Elle n'échoue jamais vers l'appelant.** Sous `flutter test`, le canal de
/// plugin n'existe pas et `PackageInfo.fromPlatform()` lève
/// `MissingPluginException` ; le laisser remonter ferait rougir tout test qui
/// monte « À propos » sans avoir rien demandé de tel — exactement le piège que
/// `InertContentPlayer` évite du côté du lecteur. L'échec devient donc `null`,
/// c'est-à-dire « pas de version à montrer ».
class PackageInfoAppVersionReader implements AppVersionReader {
  const PackageInfoAppVersionReader();

  @override
  Future<AppVersionInfo?> read() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersionInfo(version: info.version, build: info.buildNumber);
    } catch (_) {
      // `MissingPluginException` en test, `PlatformException` sur un hôte
      // exotique : dans les deux cas il n'y a rien à dire de plus que « je ne
      // sais pas », et rien à réessayer — le binaire ne changera pas de version
      // pendant qu'il tourne.
      return null;
    }
  }
}

/// Lecteur **fixé** : rend la valeur qu'on lui donne, sans canal de plugin.
///
/// C'est le double des tests d'écran. Exposé en production plutôt que défini
/// dans `test/`, pour la même raison qu'`InertStatusImagePicker` : un double qui
/// vit à côté de son contrat se met à jour avec lui.
@visibleForTesting
class FixedAppVersionReader implements AppVersionReader {
  const FixedAppVersionReader(this.info);

  /// `null` imite l'appareil dont la version n'est pas connaissable.
  final AppVersionInfo? info;

  @override
  Future<AppVersionInfo?> read() async => info;
}
