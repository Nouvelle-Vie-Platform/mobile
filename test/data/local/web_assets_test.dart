import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trois fichiers **cassent le web** si on les oublie, et aucun ne vient de
/// `pub.dev` : `sqlite3.wasm` et `drift_worker.js` (le magasin local),
/// `hls.min.js` (le lecteur de la médiathèque, #46). Ils se téléchargent depuis
/// un dépôt tiers et se versionnent ici.
///
/// La panne gardée est précise : monter `drift` d'une version sans
/// re-télécharger son worker, ou toucher à `hls.min.js` sans le déclarer. Rien
/// ne la signale — l'application compile, se lance, et lève à la **première
/// ouverture de base** ou reste **muette** à la première écoute, sur le web
/// seulement. Aucune vérification de compilation ne l'attrape, parce qu'il n'y
/// a rien à compiler : ce sont des octets servis au navigateur.
///
/// Deux accords sont vérifiés, et le remède est le même dans les deux cas —
/// `make web-assets`, qui régénère tout :
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

  group('hls.js — le lecteur HLS du web (#46)', () {
    // Pas de version à confronter à `pubspec.lock` : `hls.js` n'est pas un
    // paquet Dart, il est épinglé dans `tool/web_assets.sh`. Ce qui se vérifie
    // ici est donc l'accord entre le fichier présent et ce que le dépôt en
    // déclare — le reste (que la bibliothèque joue vraiment) ne se prouve que
    // dans un navigateur.
    test('le fichier est présent et non tronqué', () {
      final file = File('web/hls.min.js');
      expect(file.existsSync(), isTrue, reason: 'web/hls.min.js manque');
      // Sans lui, la médiathèque web est muette hors Safari : `HlsContentPlayer`
      // se rabat sur `<audio src>`, que Chrome refuse en
      // MEDIA_ERR_SRC_NOT_SUPPORTED.
      expect(
        file.lengthSync(),
        greaterThan(200 * 1024),
        reason: 'web/hls.min.js est trop petit pour être la vraie bibliothèque',
      );
    });

    test('le fichier présent est celui que le dépôt déclare', () {
      final digest = sha256.convert(File('web/hls.min.js').readAsBytesSync());
      expect(
        _manifestEntry(manifest, 'hls.min.js', marker: 'hls-web-asset'),
        'sha256:$digest',
        reason: 'web/hls.min.js ne correspond pas à son empreinte déclarée — '
            'relancer `make web-assets`.',
      );
    });

    test('index.html le charge depuis le dépôt, jamais depuis un CDN', () {
      // Le fichier peut être présent et parfaitement à jour sans qu'aucune page
      // ne le charge : rien d'autre ne garde ce lien-là.
      final index = File('web/index.html').readAsStringSync();
      expect(index, contains('src="hls.min.js"'));
      expect(
        index,
        isNot(contains('cdn.jsdelivr.net')),
        reason: 'hls.js se sert depuis le dépôt : une dépendance réseau tierce '
            'au démarrage est une panne de plus.',
      );
    });
  });
}

/// Valeur d'une clé d'un bloc de contrôle de `web/WEB_ASSETS.md`.
String? _manifestEntry(
  String manifest,
  String key, {
  String marker = 'drift-web-assets',
}) {
  final block = RegExp(
    '<!-- ${RegExp.escape(marker)}(.*?)-->',
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
