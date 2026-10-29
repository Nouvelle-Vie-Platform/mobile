import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Le magasin local n'ouvre rien sur le web sans `web:`** — et l'oublier ne
/// se voit qu'en production.
///
/// `drift_flutter` lève un `ArgumentError` **synchrone** quand ce paramètre
/// manque et qu'on est compilé pour le web (`drift_flutter/lib/src/web.dart`) :
/// « When compiling to the web, the `web` parameter needs to be set. »
/// `appDatabaseProvider` étant un `Provider` synchrone, l'exception devient
/// l'état du provider et **chaque `ref.read` la relance** : la médiathèque, les
/// échanges, la Bible et les notes tombent d'un coup, en annonçant au fidèle de
/// vérifier sa connexion internet.
///
/// C'est arrivé, et c'est resté invisible du 14/09 au 29/10/2026. Rien ne
/// pouvait l'attraper : la compilation réussit (le paramètre est facultatif à
/// l'écriture), `flutter test` tourne sur la VM où c'est l'implémentation
/// native qui répond, et `web_assets_test.dart` vérifie que `sqlite3.wasm` et
/// `drift_worker.js` sont bien là — ce qui était vrai, et sans objet : la base
/// levait **avant** d'aller les chercher. Sur le banc du 29/10, `sqlite3.wasm`
/// n'a jamais été demandé une seule fois.
///
/// Ce test est donc un **garde-fou de source**, le même motif que celui qui
/// interdit d'importer `just_audio` hors de son lecteur : il ne prouve pas que
/// la base s'ouvre dans un navigateur — seul un navigateur le prouve —, il
/// prouve que l'appel porte ce sans quoi elle ne s'ouvrira jamais.
void main() {
  final source = File('lib/data/local/app_database.dart').readAsStringSync();

  test('la base par défaut passe les options web à drift_flutter', () {
    final call = RegExp(r'driftDatabase\((.|\n)*?\)\)', multiLine: true)
        .firstMatch(source)
        ?.group(0);

    expect(
      call,
      isNotNull,
      reason: 'AppDatabase.defaults() doit construire la base par '
          'driftDatabase() — si ce n\'est plus le cas, ce garde-fou est à '
          'réécrire, pas à supprimer.',
    );
    expect(
      call,
      contains('web:'),
      reason: 'Sans `web:`, drift_flutter lève à la construction sur le web, '
          'et tous les écrans adossés au magasin tombent.',
    );
    expect(call, contains('sqlite3.wasm'));
    expect(call, contains('drift_worker.js'));
  });

  test('les deux adresses restent relatives, donc suivent le base href', () {
    // Une adresse absolue (`/sqlite3.wasm`) marcherait à la racine d'un
    // sous-domaine et casserait sous un préfixe ; une adresse d'origine
    // complète ferait du bundle le prisonnier d'un domaine.
    expect(source, contains("Uri.parse('sqlite3.wasm')"));
    expect(source, contains("Uri.parse('drift_worker.js')"));
    expect(source, isNot(contains("Uri.parse('/sqlite3.wasm')")));
    expect(source, isNot(contains('https://')));
  });
}
