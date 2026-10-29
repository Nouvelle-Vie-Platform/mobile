import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Le worker de drift doit fournir tout ce que `sqlite3.wasm` réclame** — et
/// rien d'autre ne le vérifie.
///
/// `web/drift_worker.js` n'est pas du code à nous : c'est un artefact **publié
/// par drift**, qui embarque **sa propre** version du paquet `sqlite3`.
/// `web/sqlite3.wasm`, lui, vient de la version que notre `pubspec.lock` a
/// résolue. Les deux peuvent donc parfaitement être « à jour » chacun de son
/// côté et ne pas s'accorder — ce que `web_assets_test.dart` ne peut pas voir,
/// puisqu'il compare des versions déclarées et des empreintes, pas des
/// symboles.
///
/// C'est arrivé, et ça a coûté la journée du 29/10/2026 : `drift 2.34.0`
/// publiait un worker bâti sur un `sqlite3` antérieur à 3.4.0, donc **sans
/// `xFileControl`** ; notre wasm 3.5.1 le réclamait. Dans le navigateur, le
/// magasin levait
/// `LinkError: Import #10 "dart" "xFileControl": function import requires a
/// callable` — **et nulle part ailleurs** : sur mobile, le wasm ne sert pas.
/// Tous les écrans adossés au magasin tombaient, en parlant de connexion
/// internet.
///
/// Le remède fut de monter drift à 2.34.2+, où le worker fournit l'import. Ce
/// test tient l'accord pour la fois suivante, **quelle que soit** la version
/// qui dérive — c'est l'invariant, pas une valeur.
void main() {
  test('tous les imports « dart » du wasm existent dans le worker', () {
    final wasm = File('web/sqlite3.wasm').readAsBytesSync();
    final worker = File('web/drift_worker.js').readAsStringSync();

    // Dans la section d'imports, chaque entrée s'écrit `0x04 "dart" <len> <nom>`.
    // On lit les noms sans décoder tout le module : ce qui compte est l'accord
    // des symboles, pas la structure du binaire.
    const prefixe = [0x04, 0x64, 0x61, 0x72, 0x74]; // longueur 4 puis « dart »
    final nomValide = RegExp(r'^[A-Za-z0-9_$]+$');
    final reclames = <String>{};

    for (var i = 0; i + prefixe.length < wasm.length; i++) {
      var trouve = true;
      for (var j = 0; j < prefixe.length; j++) {
        if (wasm[i + j] != prefixe[j]) {
          trouve = false;
          break;
        }
      }
      if (!trouve) continue;

      final debut = i + prefixe.length;
      final longueur = wasm[debut];
      if (longueur == 0 || longueur > 63) continue;
      if (debut + 1 + longueur > wasm.length) continue;

      final nom = String.fromCharCodes(wasm, debut + 1, debut + 1 + longueur);
      if (nomValide.hasMatch(nom)) reclames.add(nom);
    }

    expect(
      reclames,
      contains('xFileControl'),
      reason: 'La lecture du binaire ne rend plus rien : si la section '
          'd\'imports a changé de forme, ce test est à réécrire — pas à '
          'supprimer. Sans lui, un worker désaccordé ne se voit que dans la '
          'console d\'un fidèle.',
    );

    final manquants = reclames.where((nom) => !worker.contains(nom)).toList()
      ..sort();

    expect(
      manquants,
      isEmpty,
      reason: 'Le worker publié par drift ne fournit pas ces imports, que le '
          'wasm réclame : la base lèvera un LinkError dans le navigateur, et '
          'seulement là. Remède : monter `drift` jusqu\'à une version dont le '
          'worker les porte, puis `make web-assets`.',
    );
  });
}
