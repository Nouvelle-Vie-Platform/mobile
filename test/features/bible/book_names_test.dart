/// **Les noms de livres suivent la langue** (#254).
///
/// Avant cette tranche, `osisBooksFr` était la seule table du dépôt : l'appli
/// servait « Genèse » et « Exode » à ses lecteurs anglophones, sous des en-têtes
/// « Old Testament ». Constaté sur capture le 27/10/2026.
///
/// Le premier test est le plus important : il garde la **complétude**. Une table
/// incomplète ne casse rien — elle retombe silencieusement sur le français, et
/// personne ne s'en aperçoit avant qu'un fidèle ne lise un titre dans la mauvaise
/// langue au milieu des autres.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/search/bible_reference_parser.dart';

void main() {
  test('les trois tables couvrent les 66 livres, et les mêmes', () {
    expect(osisBooksFr, hasLength(66));
    for (final lang in const ['en', 'ee']) {
      final table = osisBooksFor(lang);
      expect(table, hasLength(66), reason: 'table « $lang » incomplète');
      expect(table.keys.toSet(), osisBooksFr.keys.toSet(),
          reason: 'la table « $lang » ne porte pas les mêmes codes OSIS');
      // Un nom vide retomberait sur le français sans rien dire.
      for (final e in table.entries) {
        expect(e.value.trim(), isNotEmpty,
            reason: '${e.key} vide en « $lang »');
      }
    }
  });

  test('chaque langue rend son propre nom, et le français sert de repli', () {
    final gen = bibleCanon.first;
    expect(gen.osis, 'Gen');
    expect(gen.nameIn('fr'), 'Genèse');
    expect(gen.nameIn('en'), 'Genesis');
    expect(gen.nameIn('ee'), startsWith('1 Mɔse'));
    // Une langue sans table : le titre reste lisible plutôt qu'absent.
    expect(gen.nameIn('de'), 'Genèse');
  });

  /*
   * Les codes OSIS sont les clés de `bible_marks`, de `bible_reading_states` et des
   * liens de notes. Les toucher invaliderait des données déjà posées sur les
   * téléphones — seuls les libellés changent.
   */
  test('les codes OSIS ne bougent pas', () {
    expect(bibleCanon.map((b) => b.osis).take(3), ['Gen', 'Exod', 'Lev']);
    expect(bibleCanon.last.osis, 'Rev');
    expect(bibleCanon, hasLength(66));
  });

  test('une référence se tape dans n’importe laquelle des trois langues', () {
    for (final saisie in const ['Jean 3:16', 'John 3:16', 'Yohanes 3:16']) {
      final lien = parseBibleReference(saisie);
      expect(lien?.book, 'John', reason: '« $saisie » non reconnu');
      expect(lien?.chapter, 3);
    }
  });
}
