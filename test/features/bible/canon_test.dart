/// **Le canon et la Bible factice** (M1, #199) : la structure est vraie, le
/// texte est déterministe et marqué.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/data/placeholder_bible.dart';

void main() {
  group('Le canon', () {
    test('66 livres, 39 + 27, dans l\'ordre des liens des notes', () {
      expect(bibleCanon, hasLength(66));
      expect(bibleCanon.map((b) => b.osis), osisBooksFr.keys);
      expect(
        bibleCanon.where((b) => b.testament == Testament.old),
        hasLength(39),
      );
      expect(bibleCanon.first.name, 'Genèse');
      expect(bibleCanon.last.name, 'Apocalypse');
      for (final b in bibleCanon) {
        expect(b.abbreviations, isNotEmpty, reason: b.osis);
        expect(b.abbreviations, contains(b.osis), reason: b.osis);
      }
    });

    test('1 189 chapitres, 31 102 versets', () {
      expect(bibleChapters, hasLength(1189));
      expect(
        bibleCanon.fold<int>(
            0, (n, b) => n + b.verseCounts.fold(0, (a, c) => a + c)),
        31102,
      );
      final ot = bibleCanon
          .where((b) => b.testament == Testament.old)
          .expand((b) => b.verseCounts)
          .fold<int>(0, (a, c) => a + c);
      expect(ot, 23145);
    });

    test('quelques chapitres connus', () {
      expect(bibleBook('Ps')!.chapterCount, 150);
      expect(bibleBook('Ps')!.versesIn(119), 176);
      expect(bibleBook('Ps')!.versesIn(117), 2);
      expect(bibleBook('John')!.versesIn(3), 36);
      expect(bibleBook('Gen')!.versesIn(1), 31);
      expect(bibleBook('Gen')!.chapterCount, 50);
      expect(bibleBook('Obad')!.chapterCount, 1);
      expect(bibleBook('Rev')!.versesIn(22), 21);
      expect(bibleBook('John')!.versesIn(22), 0);
      expect(bibleBook('Xyz'), isNull);
    });

    test('le rang global d\'un chapitre, aller et retour', () {
      expect(bibleChapterIndex('Gen', 1), 0);
      expect(bibleChapterIndex('Rev', 22), 1188);
      expect(bibleChapterIndex('Matt', 1), 929);
      final i = bibleChapterIndex('John', 3);
      expect(bibleChapters[i], (book: 'John', chapter: 3));
      // Le dernier chapitre d'un livre précède le premier du suivant.
      expect(
        bibleChapters[bibleChapterIndex('Mal', 4) + 1],
        (book: 'Matt', chapter: 1),
      );
      expect(bibleChapterIndex('John', 99), -1);
    });

    test('une référence est dans le canon, ou non', () {
      expect(isValidBibleRef(const BibleLink('John', 3, from: 16, to: 18)),
          isTrue);
      expect(isValidBibleRef(const BibleLink('John', 3, from: 36)), isTrue);
      expect(isValidBibleRef(const BibleLink('John', 3, from: 37)), isFalse);
      expect(isValidBibleRef(const BibleLink('John', 22)), isFalse);
    });
  });

  group('La Bible factice', () {
    const a = PlaceholderBibleSource('EXA');
    const b = PlaceholderBibleSource('EXB', variant: 1);

    test('un verset par verset du canon, numérotés', () {
      final verses = a.chapterSync('John', 3);
      expect(verses, hasLength(36));
      expect(verses.map((v) => v.number), List.generate(36, (i) => i + 1));
      expect(a.chapterSync('Ps', 119), hasLength(176));
      expect(a.chapterSync('John', 99), isEmpty);
    });

    test('déterministe, et marqué une fois par chapitre', () {
      final first = a.chapterSync('John', 3);
      final again = const PlaceholderBibleSource('EXA').chapterSync('John', 3);
      expect(first.map((v) => v.text), again.map((v) => v.text));
      expect(first.first.text, startsWith("Texte d'exemple — "));
      expect(
        first.where((v) => v.text.contains(kPlaceholderMark)),
        hasLength(1),
      );
      // Une phrase : majuscule, point final.
      expect(first[15].text, matches(RegExp(r'^[A-ZÉÈ].+[.]$')));
      // Pas tous pareils.
      expect(first.map((v) => v.text).toSet().length, greaterThan(10));
    });

    test('deux versions, deux textes', () {
      expect(a.verseText('John', 3, 16), isNot(b.verseText('John', 3, 16)));
    });

    test('le catalogue : deux versions installées d\'office', () async {
      const catalog = PlaceholderBibleCatalog();
      final versions = await catalog.versions();
      expect(versions.map((v) => v.name),
          ["Version d'exemple A", "Version d'exemple B"]);
      expect(versions.every((v) => v.installed), isTrue);
      expect(catalog.sourceFor(catalog.defaultVersionCode), isNotNull);
      expect(catalog.sourceFor('EXB'), isNotNull);
      expect(catalog.sourceFor('LSG'), isNull);
      final text = await catalog.sourceFor('EXB')!.chapter('Gen', 1);
      expect(text, hasLength(31));
    });
  });
}
