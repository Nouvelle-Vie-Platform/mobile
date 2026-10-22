/// **La Bible factice** (M1, #199, décisions 8 et 9) : la vraie structure
/// du canon, un texte d'exemple **déterministe** par verset, et deux versions
/// installées d'office.
///
/// Le texte se compose de quatre morceaux choisis par le rang du verset :
/// même livre, même chapitre, même verset, même version ⇒ même phrase, sur
/// tous les appareils et dans tous les tests. Le premier verset d'un chapitre
/// porte « Texte d'exemple — » pour que personne ne prenne ces phrases pour
/// l'Écriture. Pur Dart.
library;

import 'bible_source.dart';
import 'canon.dart';

/// La marque posée en tête de chaque chapitre.
const String kPlaceholderMark = "Texte d'exemple";

/// Les deux versions factices : même structure, phrases différentes.
const List<BibleVersion> kPlaceholderVersions = [
  BibleVersion(
    code: 'EXA',
    name: "Version d'exemple A",
    language: 'fr',
    installed: true,
  ),
  BibleVersion(
    code: 'EXB',
    name: "Version d'exemple B",
    language: 'fr',
    installed: true,
  ),
];

/// Le catalogue factice : les deux versions, installées.
final class PlaceholderBibleCatalog implements BibleCatalog {
  const PlaceholderBibleCatalog();

  @override
  Future<List<BibleVersion>> versions() async => kPlaceholderVersions;

  @override
  String get defaultVersionCode => kPlaceholderVersions.first.code;

  @override
  BibleSource? sourceFor(String versionCode) {
    final i = kPlaceholderVersions.indexWhere((v) => v.code == versionCode);
    return i < 0 ? null : PlaceholderBibleSource(versionCode, variant: i);
  }

  /// La Bible factice **est** le canon figé : c'est sa versification, et elle
  /// ne change pas (C3, #240).
  @override
  BibleVersification versificationFor(String versionCode) =>
      kCanonVersification;
}

/// Le texte d'exemple d'une version factice.
final class PlaceholderBibleSource implements BibleSource {
  const PlaceholderBibleSource(this.versionCode, {this.variant = 0});

  @override
  final String versionCode;

  /// 0 = « A », 1 = « B » : choisit le jeu de morceaux.
  final int variant;

  @override
  Future<List<BibleVerse>> chapter(String book, int chapter) async =>
      chapterSync(book, chapter);

  /// La même chose, sans attente — pour les tests et l'index (M3).
  List<BibleVerse> chapterSync(String book, int chapter) {
    final count = bibleBook(book)?.versesIn(chapter) ?? 0;
    return [
      for (var v = 1; v <= count; v++)
        BibleVerse(v, verseText(book, chapter, v)),
    ];
  }

  /// La phrase de [book] [chapter]:[verse].
  String verseText(String book, int chapter, int verse) {
    final parts = _parts[variant % _parts.length];
    final b = bibleBook(book)?.index ?? 0;
    // Un mélange simple et stable : pas d'aléa, pas de `hashCode` (qui
    // change d'une exécution à l'autre pour les chaînes).
    final seed = b * 7919 + chapter * 104729 + verse * 1299709;
    // `seed * (salt + 1)` : avec `seed * salt`, le sel 1 donnait `2 × seed`,
    // toujours pair — la moitié des sujets n'apparaissait jamais. Ce mélange
    // garde aussi toutes les paires sujet × complément.
    String pick(List<String> list, int salt) =>
        list[(seed ~/ salt + seed * (salt + 1)) % list.length];
    final sentence = '${pick(parts[0], 1)} ${pick(parts[1], 3)} '
        '${pick(parts[2], 7)} ${pick(parts[3], 11)}';
    return verse == 1 ? '$kPlaceholderMark — $sentence' : sentence;
  }
}

const List<List<List<String>>> _parts = [
  // Version A.
  [
    [
      "L'Éternel",
      'Le Seigneur',
      'Celui qui croit',
      'Le peuple',
      'Mon âme',
      'Le berger',
      'La parole de vérité',
      'Le juste',
    ],
    ['garde', 'éclaire', 'relève', 'conduit', 'console', 'bénit', 'appelle'],
    [
      'ceux qui le cherchent',
      'le cœur des humbles',
      'la maison de Jacob',
      'les pas du voyageur',
      'la ville et ses portes',
      "l'orphelin et la veuve",
    ],
    [
      'en tout temps.',
      'dans le désert.',
      "jusqu'à la fin des jours.",
      'au matin comme au soir.',
      'sur la montagne sainte.',
      'selon sa promesse.',
      'avec fidélité.',
    ],
  ],
  // Version B.
  [
    [
      'Dieu',
      'Le Maître',
      'Quiconque écoute',
      "L'assemblée",
      'Mon cœur',
      'Le serviteur fidèle',
      'La sagesse',
      "L'homme droit",
    ],
    ['protège', 'illumine', 'fortifie', 'guide', 'réconforte', 'visite'],
    [
      'les siens',
      'les pauvres de la terre',
      'le pays tout entier',
      'le chemin des fidèles',
      'les nations lointaines',
      'ceux qui pleurent',
    ],
    [
      'pour toujours.',
      'au milieu de la nuit.',
      "d'âge en âge.",
      'comme il l’a dit.',
      'près des eaux paisibles.',
      'chaque jour.',
    ],
  ],
];
