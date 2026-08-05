import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le magasin local est la seule dépendance du dépôt qui **casse le web** si on
/// l'oublie : `sqlite3.wasm` et `drift_worker.js` ne viennent pas de `pub.dev`,
/// ils se téléchargent depuis GitHub et se versionnent dans le dépôt.
///
/// La panne gardée ici est précise : monter `drift` d'une version sans
/// re-télécharger son worker. Rien ne la signale — l'application compile, se
/// lance, et lève à la **première ouverture de base**, sur le web seulement.
/// Aucune vérification de compilation ne l'attrape, parce qu'il n'y a rien à
/// compiler : ce sont des octets servis au navigateur.
///
/// Deux accords sont vérifiés, et le remède est le même dans les deux cas —
/// `make web-assets`, qui régénère tout depuis `pubspec.lock` :
/// 1. les versions déclarées sont celles que `pubspec.lock` a résolues ;
/// 2. les fichiers présents sont ceux que le dépôt déclare.
void main() {
  final lock = File('pubspec.lock').readAsStringSync();
  final manifest = File('web/WEB_ASSETS.md').readAsStringSync();

  const assets = {
    'drift': 'drift_worker.js',
    'sqlite3': 'sqlite3.wasm',
  };

  test('les deux binaires du web sont présents et non tronqués', () {
    for (final fileName in assets.values) {
      final file = File('web/$fileName');
      expect(file.existsSync(), isTrue, reason: 'web/$fileName manque');
      // Un téléchargement interrompu ou un pointeur LFS non résolu ferait un
      // fichier qui existe quand même.
      expect(
        file.lengthSync(),
        greaterThan(50 * 1024),
        reason: 'web/$fileName est trop petit pour être le vrai binaire',
      );
    }
  });

  test('les versions déclarées sont celles de pubspec.lock', () {
    for (final package in assets.keys) {
      expect(
        _manifestEntry(manifest, package),
        _lockedVersion(lock, package),
        reason: 'web/WEB_ASSETS.md annonce une version de $package qui n\'est '
            'pas celle de pubspec.lock — relancer `make web-assets`.',
      );
    }
  });

  test('les fichiers présents sont ceux que le dépôt déclare', () {
    for (final fileName in assets.values) {
      final digest = sha256.convert(File('web/$fileName').readAsBytesSync());
      expect(
        _manifestEntry(manifest, fileName),
        'sha256:$digest',
        reason: 'web/$fileName ne correspond pas à son empreinte déclarée — '
            'relancer `make web-assets`.',
      );
    }
  });
}

/// Valeur d'une clé du bloc `drift-web-assets` de `web/WEB_ASSETS.md`.
String? _manifestEntry(String manifest, String key) {
  final block = RegExp(
    r'<!-- drift-web-assets(.*?)-->',
    dotAll: true,
  ).firstMatch(manifest);
  if (block == null) return null;
  return RegExp('^\\s*${RegExp.escape(key)}:\\s*(\\S+)\\s*\$', multiLine: true)
      .firstMatch(block.group(1)!)
      ?.group(1);
}

/// Version résolue par `pubspec.lock` pour ce paquet.
String? _lockedVersion(String lock, String package) {
  return RegExp(
    '^  ${RegExp.escape(package)}:\\n(?:.*\\n)*?    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lock)?.group(1);
}
