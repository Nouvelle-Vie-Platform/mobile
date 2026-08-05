import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le magasin local est la seule dépendance du dépôt qui **casse le web** si on
/// l'oublie : `sqlite3.wasm` et `drift_worker.js` ne viennent pas de `pub.dev`,
/// ils se téléchargent depuis GitHub et se versionnent à la main.
///
/// La panne qu'on garde ici est précise : monter `drift` d'une version sans
/// re-télécharger son worker. Rien ne le signale — l'application compile, se
/// lance, et lève à la **première ouverture de base**, sur le web seulement.
/// Aucune CI de compilation ne l'attrape, parce qu'il n'y a rien à compiler.
void main() {
  final web = Directory('web');
  final lock = File('pubspec.lock').readAsStringSync();
  final manifest = File('web/WEB_ASSETS.md').readAsStringSync();

  test('les deux binaires du web sont bien présents', () {
    expect(File('${web.path}/sqlite3.wasm').existsSync(), isTrue);
    expect(File('${web.path}/drift_worker.js').existsSync(), isTrue);
    // Un fichier LFS non résolu ou un téléchargement raté ferait un fichier
    // minuscule qui existe quand même.
    expect(
      File('${web.path}/sqlite3.wasm').lengthSync(),
      greaterThan(100 * 1024),
    );
    expect(
      File('${web.path}/drift_worker.js').lengthSync(),
      greaterThan(50 * 1024),
    );
  });

  test('leurs versions correspondent à celles verrouillées', () {
    for (final package in const ['drift', 'sqlite3']) {
      expect(
        _declaredAssetVersion(manifest, package),
        _lockedVersion(lock, package),
        reason: 'web/WEB_ASSETS.md annonce une version de $package qui n\'est '
            'pas celle de pubspec.lock — relancer `make web-assets`.',
      );
    }
  });
}

/// Version annoncée par le bloc `drift-web-assets` de `web/WEB_ASSETS.md`.
String? _declaredAssetVersion(String manifest, String package) {
  final block = RegExp(
    r'<!-- drift-web-assets(.*?)-->',
    dotAll: true,
  ).firstMatch(manifest);
  if (block == null) return null;
  return RegExp('^\\s*$package:\\s*(\\S+)\\s*\$', multiLine: true)
      .firstMatch(block.group(1)!)
      ?.group(1);
}

/// Version résolue par `pubspec.lock` pour ce paquet.
String? _lockedVersion(String lock, String package) {
  return RegExp(
    '^  $package:\\n(?:.*\\n)*?    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lock)?.group(1);
}
