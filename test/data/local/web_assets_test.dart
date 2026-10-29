import 'dart:convert';
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

  group('le SDK JS de Firebase — les annonces du navigateur (#283)', () {
    const files = [
      'firebase/firebase-app.js',
      'firebase/firebase-messaging.js',
    ];

    test('les deux modules sont présents et non tronqués', () {
      for (final fileName in files) {
        final file = File('web/$fileName');
        expect(file.existsSync(), isTrue, reason: 'web/$fileName manque');
        expect(
          file.lengthSync(),
          greaterThan(20 * 1024),
          reason: 'web/$fileName est trop petit pour être le vrai bundle',
        );
      }
    });

    test('les fichiers présents sont ceux que le dépôt déclare', () {
      for (final fileName in files) {
        final digest = sha256.convert(File('web/$fileName').readAsBytesSync());
        expect(
          _manifestEntry(manifest, fileName, marker: 'firebase-web-asset'),
          'sha256:$digest',
          reason: 'web/$fileName ne correspond pas à son empreinte déclarée — '
              'relancer `make web-assets`.',
        );
      }
    });

    test('la version servie est celle que `firebase_core_web` attend', () {
      // ⚠️ **Cette version ne se choisit pas, elle se subit** : le paquet est
      // testé contre une version précise du SDK JS et imprime un avertissement
      // devant toute autre. Monter `firebase_core` déplace donc la cible, et
      // c'est ce test qui le dira — rien d'autre ne le ferait, puisque nos deux
      // fichiers resteraient parfaitement « à jour » de leur côté.
      // Remède : changer `FIREBASE_SDK_VERSION` dans `tool/web_assets.sh`,
      // puis `make web-assets`.
      final source = File(
        '${_packageRoot('firebase_core_web')}src/firebase_sdk_version.dart',
      ).readAsStringSync();
      final expected = RegExp("supportedFirebaseJsSdkVersion = '([^']+)'")
          .firstMatch(source)
          ?.group(1);
      expect(expected, isNotNull,
          reason: 'constante introuvable dans le paquet');
      expect(
        _manifestEntry(manifest, 'firebase-js-sdk',
            marker: 'firebase-web-asset'),
        expected,
      );
    });

    test('aucun des deux n\'importe quoi que ce soit hors de notre origine',
        () {
      // **C'est la mesure de la tranche, tenue sur les octets.**
      // `firebase-messaging.js` arrive de chez Google avec un
      // `from"https://www.gstatic.com/.../firebase-app.js"` **écrit dans ses
      // octets** : servi tel quel, il déplacerait 37 ko et laisserait le
      // navigateur chercher les 106 ko du cœur chez Google — et la CSP de
      // l'origine le refuserait. `tool/web_assets.sh` remplace cette chaîne par
      // `./firebase-app.js` ; si la retouche sautait (nouveau bundle, script
      // modifié), rien d'autre ne le dirait avant la console d'un fidèle.
      final imports = RegExp(r'''(?:from|import)\s*\(?\s*["']https?:''');
      for (final fileName in files) {
        final code = File('web/$fileName').readAsStringSync();
        expect(
          imports.hasMatch(code),
          isFalse,
          reason: 'web/$fileName importe un module hors de notre origine',
        );
      }
      expect(
        File('web/firebase/firebase-messaging.js').readAsStringSync(),
        contains('from"./firebase-app.js"'),
        reason: 'la retouche de `tool/web_assets.sh` doit être en place',
      );
    });

    test('le worker de messagerie est à son nom exact, et sans SDK', () {
      // Le SDK enregistre lui-même `/firebase-messaging-sw.js` : renommer le
      // fichier, c'est un worker qui ne s'enregistre jamais.
      final worker = File('web/firebase-messaging-sw.js');
      expect(worker.existsSync(), isTrue);
      // Commentaires retirés : l'en-tête **parle** de `importScripts` pour dire
      // pourquoi il n'y en a pas.
      final code = worker
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code,
        isNot(contains('importScripts')),
        reason: 'ce worker lit l\'événement `push` du navigateur ; il n\'a '
            'aucun bundle tiers à charger, et donc aucun à versionner.',
      );
      expect(code, isNot(contains('gstatic.com')));
    });
  });
}

/// Racine du paquet résolu, lue dans `.dart_tool/package_config.json`.
String _packageRoot(String package) {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final packages = config['packages'] as List<Object?>;
  final entry = packages.cast<Map<String, Object?>>().firstWhere(
        (p) => p['name'] == package,
        orElse: () => throw StateError('$package absent du package_config'),
      );
  final root = Uri.parse(entry['rootUri'] as String);
  final packageUri = entry['packageUri'] as String;
  // `rootUri` est relative au dossier `.dart_tool/` quand elle n'est pas
  // absolue — c'est le cas des paquets du cache sur certaines machines.
  final resolved =
      root.hasScheme ? root : Uri.directory('.dart_tool').resolveUri(root);
  return '${resolved.toFilePath()}/$packageUri'.replaceAll('//', '/');
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
