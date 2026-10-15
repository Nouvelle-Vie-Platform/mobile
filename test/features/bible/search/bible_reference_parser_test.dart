/// **Lire une référence tapée** (M3, #201) : formes acceptées, ambiguïtés et
/// refus.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/search/bible_reference_parser.dart';

String? _url(String q) => parseBibleReference(q)?.toUrl();

void main() {
  test('les formes courantes', () {
    const cases = {
      'jn 3 16': 'nv://bible/John/3/16',
      'Jean 3:16-18': 'nv://bible/John/3/16-18',
      'Jean 3.16': 'nv://bible/John/3/16',
      'jean 3,16': 'nv://bible/John/3/16',
      'jn3:16': 'nv://bible/John/3/16',
      '1 Co 13': 'nv://bible/1Cor/13',
      '1co13': 'nv://bible/1Cor/13',
      '1 Corinthiens 13:4-7': 'nv://bible/1Cor/13/4-7',
      'ps 23': 'nv://bible/Ps/23',
      'PSAUMES 23 1': 'nv://bible/Ps/23/1',
      'Genèse 1:1': 'nv://bible/Gen/1/1',
      'genese 1': 'nv://bible/Gen/1',
      'Ésaïe 53:5': 'nv://bible/Isa/53/5',
      'esaie 53': 'nv://bible/Isa/53',
      'És 40:31': 'nv://bible/Isa/40/31',
      '1 Jean 4:8': 'nv://bible/1John/4/8',
      '1jn 4 8': 'nv://bible/1John/4/8',
      'Ap 22:21': 'nv://bible/Rev/22/21',
      'Mt 5:3–12': 'nv://bible/Matt/5/3-12',
      'Rom. 8 28': 'nv://bible/Rom/8/28',
      'Cantique des cantiques 2:4': 'nv://bible/Song/2/4',
      'philip 4:13': 'nv://bible/Phil/4/13',
      'John 3:16': 'nv://bible/John/3/16',
      '  jn 3 16  ': 'nv://bible/John/3/16',
      'Jean 3:16-16': 'nv://bible/John/3/16',
    };
    cases.forEach((q, url) => expect(_url(q), url, reason: q));
  });

  test('ambiguïtés : un préfixe qui désigne plusieurs livres est refusé', () {
    for (final q in ['jo 3', 'ma 3', 'phi 4', 'a 1']) {
      expect(parseBibleReference(q), isNull, reason: q);
    }
    // Mais l'abréviation exacte l'emporte sur le préfixe.
    expect(_url('ex 20'), 'nv://bible/Exod/20');
    expect(_url('ph 4'), 'nv://bible/Phil/4');
  });

  test('refus : hors canon, sans chapitre, ou simples mots', () {
    for (final q in [
      'Jean 22', // 21 chapitres
      'Ps 151',
      'Ps 23:7', // 6 versets
      'Jean 3:18-16',
      'Jean 0',
      'Jean',
      'amour',
      'paix 3',
      'berger fidèle',
      '3 16',
      '',
    ]) {
      expect(parseBibleReference(q), isNull, reason: q);
    }
  });

  test('aucune clé du canon n\'est revendiquée par deux livres', () {
    for (final b in bibleCanon) {
      expect(resolveBibleBook(b.name), b.osis, reason: b.name);
      for (final a in b.abbreviations) {
        expect(resolveBibleBook(a), b.osis, reason: a);
      }
    }
  });
}
