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

/// **Compare deux versions affichables** — `1.4.0` contre `1.10.2`.
///
/// Rend un ordre à la manière de `Comparable.compareTo` : négatif si [version]
/// est antérieure à [other], zéro si elles décrivent le même palier, positif
/// au-delà.
///
/// **Et `null` quand la question n'a pas de réponse.** C'est le point de cette
/// fonction, et la seule raison pour laquelle elle existe plutôt qu'un
/// `compareTo` sur deux chaînes : une version se compare **segment par segment,
/// en nombres** — `1.10.0` est postérieure à `1.9.0`, alors que l'ordre
/// alphabétique dit l'inverse —, et un segment qui n'est pas un nombre
/// (`1.0.0-rc1`, un seuil recopié de travers dans le portail) ne se compare pas
/// du tout. L'appelant ne décide alors **rien** ; pour le bandeau de mise à
/// jour, ne rien décider veut dire ne rien afficher.
///
/// Le **build** (`+12`) est ignoré des deux côtés : c'est l'identité d'un
/// binaire, pas un palier publié, et deux builds de la même version sont le même
/// palier pour quelqu'un qu'on invite à monter.
///
/// Les longueurs inégales sont complétées par des zéros : `1.4` et `1.4.0` sont
/// la même version.
int? compareAppVersions(String version, String other) {
  final left = _versionSegments(version);
  final right = _versionSegments(other);
  if (left == null || right == null) return null;

  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final a = i < left.length ? left[i] : 0;
    final b = i < right.length ? right[i] : 0;
    if (a != b) return a < b ? -1 : 1;
  }
  return 0;
}

/// Les segments numériques d'une version, ou `null` si l'un d'eux n'en est pas
/// un. Tolérante sur le seul `+build`, qui est coupé avant lecture.
List<int>? _versionSegments(String raw) {
  final trimmed = raw.trim().split('+').first;
  if (trimmed.isEmpty) return null;

  final segments = <int>[];
  for (final part in trimmed.split('.')) {
    final value = int.tryParse(part);
    if (value == null || value < 0) return null;
    segments.add(value);
  }
  return segments;
}
