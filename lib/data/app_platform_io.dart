import 'dart:io';

import 'app_platform.dart';

/// La plateforme, vue de `dart:io` — Android, iOS, macOS, Linux, Windows.
///
/// Fichier choisi par **importation conditionnelle** depuis `app_platform.dart`
/// (même motif que `web_content_player.dart`) : `dart:io` n'existe pas sur le
/// web, et une importation inconditionnelle y casserait la compilation. La cible
/// web reste tenue.
AppPlatformInfo describePlatform() => AppPlatformInfo(
      name: Platform.operatingSystem,
      osVersion: shortOsVersion(Platform.operatingSystemVersion),
    );
