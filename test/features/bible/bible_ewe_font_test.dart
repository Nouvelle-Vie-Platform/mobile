/// **La police posée couvre-t-elle vraiment l'éwé ?** (30/10/2026)
///
/// Ce test lit la **table de caractères du fichier** `.ttf` qui part dans
/// l'application, et vérifie qu'elle porte tout ce que l'éwé écrit. Rien
/// d'autre ne le dirait : une police incomplète se déclare, se charge, se
/// compile — et rend des carrés vides au milieu de l'Écriture, sur l'appareil
/// d'un fidèle, sans qu'aucun garde-fou ne bronche.
///
/// Il y a une raison précise à ce test, et elle est arrivée le jour même :
/// Andika est **détourée** pour ne pas peser 912 Ko, et mon premier détourage
/// s'arrêtait à `U+024F` — la fin du latin étendu B. Les cinq lettres les plus
/// fréquentes de l'éwé (`ɔ ɖ ɛ ɣ ʋ`) vivent **juste après**, dans le bloc
/// phonétique. La police s'installait sans rien dire et ne changeait rien.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Les caractères non-ASCII de la Bible éwé **servie en production**, relevés
/// dans `ewe2020-2b478ab73a82.zip` le 30/10/2026 (3,8 millions de caractères,
/// 66 livres). C'est la liste réelle, pas une liste d'alphabet : elle porte
/// aussi les diacritiques combinants et la ponctuation typographique, qui
/// manquent tout aussi silencieusement.
const String kEweCharacters = '©ÀÈÉàáãèéìíòóõĩŊŋũƆƉƐƑƒƔƲɔɖɛɣʋ́̃Ẽẽ–—‘’“”…™';

void main() {
  const dossier = 'assets/fonts/Andika';

  for (final nom in const ['Andika-Regular.ttf', 'Andika-Bold.ttf']) {
    test('$nom porte toutes les lettres de l\'éwé', () {
      final fichier = File('$dossier/$nom');
      expect(fichier.existsSync(), isTrue,
          reason: '$nom absent : le pubspec la déclare pourtant');

      final couverts = _codePointsOf(fichier.readAsBytesSync());

      // Le latin de base : un verset en éwé en est surtout fait.
      for (var c = 0x20; c <= 0x7E; c++) {
        expect(couverts, contains(c),
            reason: 'ASCII U+${c.toRadixString(16)} absent de $nom');
      }

      final manquants = [
        for (final c in kEweCharacters.runes)
          if (!couverts.contains(c)) String.fromCharCode(c),
      ];
      expect(manquants, isEmpty,
          reason: '$nom ne porte pas : ${manquants.join(' ')} — '
              'le détourage est trop serré (voir COMMENT-ELLE-EST-FAITE.md)');
    });
  }

  test('la police reste légère : elle est téléchargée au démarrage sur le web',
      () {
    for (final nom in const ['Andika-Regular.ttf', 'Andika-Bold.ttf']) {
      final octets = File('$dossier/$nom').lengthSync();
      // Andika complète pèse ~460 Ko la graisse. Au-delà de 200 Ko, c'est
      // qu'on a reposé la police entière sans la détourer — et Flutter web
      // télécharge **toutes** les polices déclarées au démarrage, même celles
      // qu'un lecteur francophone n'ouvrira jamais.
      expect(octets, lessThan(200 * 1024),
          reason: '$nom fait ${(octets / 1024).round()} Ko : non détourée ?');
    }
  });
}

/// Les points de code qu'une police porte, lus dans sa table `cmap`.
///
/// Seul le **format 4** est lu : c'est celui qu'écrit `pyftsubset`, et le seul
/// que porte la police posée (vérifié). Une police qui n'en aurait pas rendrait
/// un ensemble vide, et les tests ci-dessus rougiraient — ce qui est le bon
/// sens de l'échec.
Set<int> _codePointsOf(Uint8List octets) {
  final data = ByteData.sublistView(octets);
  final tables = data.getUint16(4);
  var cmapOffset = -1;
  for (var i = 0; i < tables; i++) {
    final entree = 12 + i * 16;
    final tag = String.fromCharCodes(octets.sublist(entree, entree + 4));
    if (tag == 'cmap') cmapOffset = data.getUint32(entree + 8);
  }
  if (cmapOffset < 0) return const {};

  final sous = data.getUint16(cmapOffset + 2);
  final couverts = <int>{};
  for (var i = 0; i < sous; i++) {
    // En-tête `cmap` : version (2) + nombre de tables (2), puis des
    // enregistrements de 8 octets dont l'adresse occupe les 4 derniers.
    final table = cmapOffset + data.getUint32(cmapOffset + 4 + i * 8 + 4);
    if (data.getUint16(table) != 4) continue;

    final segX2 = data.getUint16(table + 6);
    final fins = table + 14;
    final debuts = fins + segX2 + 2;
    final deltas = debuts + segX2;
    final plages = deltas + segX2;

    for (var s = 0; s < segX2 ~/ 2; s++) {
      final fin = data.getUint16(fins + s * 2);
      final debut = data.getUint16(debuts + s * 2);
      if (debut > fin) continue;
      final plage = data.getUint16(plages + s * 2);
      for (var c = debut; c <= fin && c != 0xFFFF; c++) {
        if (plage == 0) {
          couverts.add(c);
          continue;
        }
        // `idRangeOffset` pointe **depuis sa propre case** dans le tableau des
        // glyphes : un glyphe 0 veut dire « pas de dessin », donc pas couvert.
        final at = plages + s * 2 + plage + (c - debut) * 2;
        if (at + 1 < octets.length && data.getUint16(at) != 0) couverts.add(c);
      }
    }
  }
  return couverts;
}
