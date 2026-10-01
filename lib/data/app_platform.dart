import 'package:flutter/foundation.dart';

import 'app_platform_io.dart'
    if (dart.library.js_interop) 'app_platform_web.dart' as runtime;

/// **Ce que l'application sait du système qui la fait tourner** : le nom de la
/// plateforme, et le numéro de version du système.
///
/// C'est le pendant d'[AppVersionInfo] (`lib/data/app_version.dart`) : celui-là
/// décrit le binaire, celui-ci décrit la machine qui l'exécute. Les deux
/// voyagent ensemble sur l'en-tête que l'application pose sur toutes ses
/// requêtes (`lib/core/network/app_version_header.dart`).
///
/// **Rien d'autre n'entre ici, et c'est une décision.** Ni identifiant
/// publicitaire, ni modèle d'appareil, ni empreinte : le serveur range ces deux
/// valeurs pour savoir quelles versions tournent encore, pas pour reconnaître
/// un téléphone. L'identifiant d'appareil, lui, existe déjà et vit ailleurs
/// (`lib/data/devices/`), annoncé par son propre bandeau légal.
@immutable
class AppPlatformInfo {
  const AppPlatformInfo({required this.name, this.osVersion});

  /// `android`, `ios`, `web`, `macos`… — en minuscules, tel que la plateforme
  /// se nomme elle-même.
  final String name;

  /// Le numéro de version du système — `14`, `17.0` —, ou `null` quand il n'est
  /// pas connaissable. Ce n'est pas une erreur : la plateforme reste utile
  /// seule.
  final String? osVersion;

  /// La forme posée sur le fil : `android 14`, ou `android` tout court quand le
  /// système ne dit pas sa version.
  String get label => osVersion == null ? name : '$name $osVersion';

  @override
  bool operator ==(Object other) =>
      other is AppPlatformInfo &&
      other.name == name &&
      other.osVersion == osVersion;

  @override
  int get hashCode => Object.hash(name, osVersion);
}

/// **Lire la plateforme**, derrière une abstraction — même motif
/// qu'[AppVersionReader], `StatusImagePicker` ou `DiskSpace` : les tests posent
/// une valeur fixe sans dépendre de la machine qui lance la suite.
///
/// La lecture est **synchrone** : aucun canal de plugin n'est en jeu, tout vient
/// de l'embarqueur Dart. Rend `null` quand il n'y a rien à dire — jamais une
/// exception, pour la raison écrite dans l'en-tête de l'intercepteur :
/// l'en-tête est purement additif.
abstract interface class AppPlatformReader {
  AppPlatformInfo? read();
}

/// L'implémentation réelle : `dart:io` sur les plateformes natives, une valeur
/// fixe sur le web (voir `app_platform_io.dart` / `app_platform_web.dart`).
///
/// **Elle n'échoue jamais vers l'appelant**, comme [PackageInfoAppVersionReader]
/// : un hôte exotique qui refuserait de se nommer ne doit pas pouvoir faire
/// échouer une requête HTTP.
class RuntimeAppPlatformReader implements AppPlatformReader {
  const RuntimeAppPlatformReader();

  @override
  AppPlatformInfo? read() {
    try {
      return runtime.describePlatform();
    } on Object catch (_) {
      return null;
    }
  }
}

/// Lecteur **fixé** : rend la valeur qu'on lui donne.
///
/// Le double des tests, exposé en production pour la même raison que
/// `FixedAppVersionReader` et `InertStatusImagePicker` — un double qui vit à
/// côté de son contrat se met à jour avec lui.
@visibleForTesting
class FixedAppPlatformReader implements AppPlatformReader {
  const FixedAppPlatformReader(this.info);

  /// `null` imite la plateforme qui ne se nomme pas.
  final AppPlatformInfo? info;

  @override
  AppPlatformInfo? read() => info;
}

/// Réduit la chaîne verbeuse d'un système à son **numéro**.
///
/// `dart:io` ne normalise rien : Android rend `14 (API 34)`, iOS et macOS
/// rendent `Version 17.0 (Build 21A329)`. Ce qu'on range côté serveur est une
/// version comparable, pas une phrase — on garde donc la première suite de
/// chiffres pointés, et rien d'autre.
///
/// Rend `null` quand la chaîne n'en contient aucune : la plateforme partira
/// alors seule, ce qui reste exact.
String? shortOsVersion(String raw) =>
    RegExp(r'\d+(?:\.\d+)*').firstMatch(raw)?.group(0);
