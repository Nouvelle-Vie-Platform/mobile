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
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/placeholder_bible.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_catalog.dart';
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
    // Le nom de l'éditeur, recopié de son `BookNames.xml` : le Pentateuque
    // porte le nom de Moïse, numéroté **après** et en chiffres romains.
    expect(gen.nameIn('ee'), 'Mose I');
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

  /*
   * **La table éwé est celle de l'éditeur** (31/10/2026) : `BookNames.xml` de
   * Biblica pour `Agbenya La™`, la traduction même que l'application sert. Le
   * relevé précédent, sans source, se trompait sur 31 noms sur 66 — et rien ne
   * l'aurait jamais dit : un nom faux s'affiche aussi bien qu'un nom juste.
   * Ces six-là sont ceux qui divergeaient le plus.
   */
  test('les noms éwé sont ceux de l\'éditeur de la traduction', () {
    const attendus = {
      'Ps': 'Psalmowo',
      'Judg': 'Ʋɔnudrɔ̃lawo',
      'Lam': 'Konyifahawo',
      'Ezek': 'Hezekiel',
      'Acts': 'Dɔwɔwɔwo',
      'Rev': 'Nyaɖeɖefia',
    };
    for (final MapEntry(key: osis, value: nom) in attendus.entries) {
      expect(bibleBook(osis)?.nameIn('ee'), nom, reason: osis);
    }
  });

  test('les livres numérotés le sont en chiffres romains, après le nom', () {
    expect(bibleBook('1Sam')?.nameIn('ee'), 'Samuel I');
    expect(bibleBook('2Cor')?.nameIn('ee'), 'Korintotɔwo II');
    expect(bibleBook('3John')?.nameIn('ee'), 'Yohanes III');
    expect(bibleBook('Deut')?.nameIn('ee'), 'Mose V');
  });

  test('une référence se tape dans n’importe laquelle des trois langues', () {
    for (final saisie in const ['Jean 3:16', 'John 3:16', 'Yohanes 3:16']) {
      final lien = parseBibleReference(saisie);
      expect(lien?.book, 'John', reason: '« $saisie » non reconnu');
      expect(lien?.chapter, 3);
    }
  });

  /*
   * **La version ouverte décide des titres** (demandé le 30/10/2026). Un fidèle
   * qui n'a téléchargé que l'éwé lisait un verset en éwé sous un titre
   * « Jean 8:36 » — constaté sur capture le même jour.
   */
  group('Le libellé d\'une référence suit la langue', () {
    const lien = BibleLink('John', 8, from: 36);

    test('chaque langue rend le sien, et le français reste le repli', () {
      expect(lien.labelIn('fr'), 'Jean 8:36');
      expect(lien.labelIn('en'), 'John 8:36');
      expect(lien.labelIn('ee'), startsWith('Yohanes'));
      // Une langue sans table : lisible plutôt qu'absent.
      expect(lien.labelIn('de'), 'Jean 8:36');
    });

    test('labelFr reste le français quoi qu’il arrive', () {
      expect(lien.labelFr, 'Jean 8:36');
    });

    test('un intervalle et un chapitre entier se libellent pareil', () {
      expect(const BibleLink('John', 3, from: 16, to: 18).labelIn('en'),
          'John 3:16-18');
      expect(const BibleLink('Ps', 23).labelIn('en'), 'Psalms 23');
    });
  });

  group('La langue des titres vient de la version ouverte', () {
    test('le catalogue rend la langue déclarée par la version', () {
      final catalogue = MergedBibleCatalog(
        remote: [
          BibleVersionRow(
            syncStamp: 0,
            id: 1,
            code: 'ewe2020',
            name: 'Éwé',
            language: 'ee',
            sortOrder: 0,
            archiveUrl: 'https://x/ewe2020-0123456789ab.zip',
          ),
        ],
        installed: [
          BibleInstalledVersionRow(
            code: 'ewe2020',
            name: 'Éwé',
            language: 'ee',
            installedAt: DateTime.utc(2026, 10, 30),
            indexed: true,
          ),
        ],
      );
      expect(catalogue.languageFor('ewe2020'), 'ee');
      // Une version inconnue ne doit pas rendre un titre absent.
      expect(catalogue.languageFor('inexistante'), 'fr');
    });

    test('les versions d\'exemple restent en français', () {
      expect(const PlaceholderBibleCatalog().languageFor('EXA'), 'fr');
    });
  });
}
