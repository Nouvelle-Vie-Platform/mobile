/// **C4 (server-portal#605), l'archive** : l'empreinte qui refuse, le
/// dézippage, la versification du manifeste, et la lecture d'un chapitre —
/// chapitre vide compris.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/bible/data/bible_archive.dart';
import 'package:maison_du_miracle/features/bible/data/versification.dart';

import 'bible_archive_fixture.dart';

void main() {
  late Directory root;
  Future<String> support() async => root.path;

  setUp(() {
    // **Pas `getTemporaryDirectory()`** sur l'appareil (le système le vide
    // quand il veut) ; ici un dossier à nous, effacé à la fin du test.
    root = Directory.systemTemp.createTempSync('bible_c4_');
  });
  tearDown(() => root.deleteSync(recursive: true));

  group('L\'empreinte au nom de l\'archive', () {
    test('les 12 hex se lisent à la fin de l\'URL, et nulle part ailleurs', () {
      expect(
        bibleArchiveFingerprint('https://x/uploads/bible/S21-0123456789ab.zip'),
        '0123456789ab',
      );
      // Une signature de requête derrière l'archive ne cache pas l'empreinte.
      expect(
        bibleArchiveFingerprint('https://x/S21-0123456789ab.zip?X-Amz=1'),
        '0123456789ab',
      );
      // Douze hex ailleurs dans le chemin ne sont pas l'empreinte.
      expect(
          bibleArchiveFingerprint('https://x/a-0123456789ab/S21.zip'), isNull);
      expect(
          bibleArchiveFingerprint('https://x/uploads/bible/S21.zip'), isNull);
      // Majuscules : le portail écrit le sha256 en minuscules.
      expect(bibleArchiveFingerprint('https://x/S21-0123456789AB.zip'), isNull);
    });

    test('une archive dont l\'empreinte ne correspond pas n\'installe rien',
        () async {
      final archive = fakeBibleArchive(code: 'S21', books: {
        1: [
          ['au commencement']
        ]
      });
      // Le même zip, annoncé sous une autre empreinte : exactement ce qu'une
      // troncature produit.
      await expectLater(
        unpackBibleArchive(
          code: 'S21',
          url: 'https://x/uploads/bible/S21-ffffffffffff.zip',
          bytes: archive.bytes,
          root: support,
        ),
        throwsA(isA<BibleArchiveException>()),
      );
      expect(Directory('${root.path}/bible').existsSync(), isFalse);
    });

    test('une URL sans empreinte est refusée : il n\'y a rien à comparer',
        () async {
      final archive = fakeBibleArchive(code: 'S21');
      await expectLater(
        unpackBibleArchive(
          code: 'S21',
          url: 'https://x/uploads/bible/S21.zip',
          bytes: archive.bytes,
          root: support,
        ),
        throwsA(isA<BibleArchiveException>()),
      );
      expect(Directory('${root.path}/bible').existsSync(), isFalse);
    });

    test('un octet retourné suffit à faire refuser l\'archive', () async {
      final archive = fakeBibleArchive(code: 'S21');
      final altered = [...archive.bytes]..[12] ^= 0x01;
      await expectLater(
        unpackBibleArchive(
          code: 'S21',
          url: archive.url,
          bytes: altered,
          root: support,
        ),
        throwsA(isA<BibleArchiveException>()),
      );
    });
  });

  group('Le dézippage', () {
    test('les fichiers vont dans le support, et la versification est relevée',
        () async {
      final archive = fakeBibleArchive(
        code: 'S21',
        versification: {
          'Gen': [31, 25],
          'Mal': [14, 17, 24, 0],
        },
        books: {
          1: [
            ['au commencement'],
            ['et Dieu dit']
          ]
        },
      );
      final installed = await unpackBibleArchive(
        code: 'S21',
        url: archive.url,
        bytes: archive.bytes,
        root: support,
      );
      expect(installed.localPath, '${root.path}/bible/S21');
      expect(File('${installed.localPath}/manifest.json').existsSync(), isTrue);
      expect(
        File('${installed.localPath}/books/01.json').existsSync(),
        isTrue,
      );
      // La versification du manifeste, telle que la colonne la relit (C3).
      final v = BibleVersification.tryParse(installed.versification);
      expect(v, isNotNull);
      // Malachie 4 déclaré à 0 : la S21 suit la Bible hébraïque, le chapitre
      // n'existe pas et ne paraît pas dans la grille.
      expect(v!.chapterCount('Mal'), 3);
      expect(v.versesIn('Mal', 4), 0);
      expect(v.versesIn('Gen', 1), 31);
    });

    test('une archive sans manifeste est refusée, et ne laisse rien', () async {
      final archive = fakeBibleArchive(code: 'S21', withManifest: false);
      await expectLater(
        unpackBibleArchive(
          code: 'S21',
          url: archive.url,
          bytes: archive.bytes,
          root: support,
        ),
        throwsA(isA<BibleArchiveException>()),
      );
      expect(Directory('${root.path}/bible/S21').existsSync(), isFalse);
    });

    test('une entrée hors contrat n\'est jamais écrite (« zip slip »)',
        () async {
      final archive = fakeBibleArchive(
        code: 'S21',
        extras: {
          '../evade.json': 'dehors',
          'books/../../evade.json': 'dehors',
          'books/01.txt': 'hors contrat',
        },
      );
      final installed = await unpackBibleArchive(
        code: 'S21',
        url: archive.url,
        bytes: archive.bytes,
        root: support,
      );
      expect(File('${root.path}/bible/evade.json').existsSync(), isFalse);
      expect(File('${root.path}/evade.json').existsSync(), isFalse);
      expect(File('${installed.localPath}/books/01.txt').existsSync(), isFalse);
      expect(
        Directory('${installed.localPath}/books').listSync(),
        isEmpty,
      );
    });

    test('réinstaller n\'empile pas les livres de deux éditions', () async {
      final premiere = fakeBibleArchive(
        code: 'S21',
        books: {
          1: [
            ['ancien']
          ],
          2: [
            ['exode ancien']
          ]
        },
      );
      await unpackBibleArchive(
        code: 'S21',
        url: premiere.url,
        bytes: premiere.bytes,
        root: support,
      );
      final seconde = fakeBibleArchive(code: 'S21', books: {
        1: [
          ['neuf']
        ]
      });
      final installed = await unpackBibleArchive(
        code: 'S21',
        url: seconde.url,
        bytes: seconde.bytes,
        root: support,
      );
      expect(
        Directory('${installed.localPath}/books')
            .listSync()
            .map((f) => f.uri.pathSegments.last),
        ['01.json'],
      );
    });

    test('la versification illisible retombe sur « aucun relevé »', () async {
      // Le canon figé reprend alors la main (C3) : l'état d'une version
      // installée avant C3, pas une panne.
      final archive = fakeBibleArchive(code: 'S21', versification: const {});
      final installed = await unpackBibleArchive(
        code: 'S21',
        url: archive.url,
        bytes: archive.bytes,
        root: support,
      );
      expect(installed.versification, isNull);
    });
  });

  group('La lecture d\'un chapitre installé', () {
    Future<InstalledBibleSource> install(
      Map<int, List<List<String>>> books,
    ) async {
      final archive = fakeBibleArchive(code: 'S21', books: books);
      final installed = await unpackBibleArchive(
        code: 'S21',
        url: archive.url,
        bytes: archive.bytes,
        root: support,
      );
      return InstalledBibleSource('S21', installed.localPath);
    }

    test('un chapitre réel rend ses versets numérotés dans l\'ordre', () async {
      final source = await install({
        1: [
          ['Au commencement, Dieu créa le ciel et la terre.', 'La terre…'],
          ['Ainsi furent achevés le ciel et la terre.'],
        ],
      });
      final chapitre = await source.chapter('Gen', 1);
      expect(chapitre.map((v) => v.number), [1, 2]);
      expect(chapitre.first.text, startsWith('Au commencement'));
      // Rien du texte d'exemple : c'est bien l'archive qui est lue.
      expect(chapitre.first.text, isNot(contains('Texte d\'exemple')));
      expect((await source.chapter('Gen', 2)).single.text,
          startsWith('Ainsi furent'));
    });

    test('un chapitre vide reste vide — il n\'existe pas dans cette version',
        () async {
      // Malachie en S21 : trois chapitres, et un quatrième déclaré vide.
      final source = await install({
        39: [
          ['Parole de l\'Éternel'],
          ['Et maintenant'],
          ['Voici, j\'envoie mon messager'],
          <String>[],
        ],
      });
      expect(await source.chapter('Mal', 3), hasLength(1));
      expect(await source.chapter('Mal', 4), isEmpty);
      // Hors du fichier : vide aussi, jamais une exception.
      expect(await source.chapter('Mal', 5), isEmpty);
      expect(await source.chapter('Mal', 0), isEmpty);
    });

    test('un livre absent de la version se lit vide', () async {
      // L'éwé 2014 n'a ni Esther ni Daniel (décision 3 du PRD) : pas de
      // fichier, donc pas de chapitre — et aucune exception.
      final source = await install({
        1: [
          ['au commencement']
        ]
      });
      expect(await source.chapter('Esth', 1), isEmpty);
      expect(await source.chapter('PasUnLivre', 1), isEmpty);
    });

    test('un fichier de livre abîmé se lit vide', () async {
      final source = await install({
        1: [
          ['au commencement']
        ]
      });
      File('${root.path}/bible/S21/books/01.json')
          .writeAsStringSync('ceci n\'est pas du json');
      expect(await source.chapter('Gen', 1), isEmpty);
    });

    test('deux livres demandés tour à tour se lisent chacun le sien', () async {
      // Le cache ne garde qu'un livre : la lecture déjà lancée ne doit pas
      // recevoir les chapitres du livre suivant.
      final source = await install({
        1: [
          ['genèse']
        ],
        2: [
          ['exode']
        ],
      });
      final gen = source.chapter('Gen', 1);
      final exo = source.chapter('Exod', 1);
      expect((await gen).single.text, 'genèse');
      expect((await exo).single.text, 'exode');
      expect((await source.chapter('Gen', 1)).single.text, 'genèse');
    });

    test('le manifeste écrit est bien celui du portail', () async {
      await install({
        1: [
          ['au commencement']
        ]
      });
      final manifest = jsonDecode(
        File('${root.path}/bible/S21/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(manifest['code'], 'S21');
      expect(manifest.containsKey('versification'), isTrue);
    });
  });
}
