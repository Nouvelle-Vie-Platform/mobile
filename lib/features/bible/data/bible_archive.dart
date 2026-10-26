/// **L'archive d'une version de la Bible** (C4, décision 4 de
/// server-portal#605) : la descendre, la **refuser si elle est abîmée**, la
/// ranger, et en lire un chapitre.
///
/// C'est la tranche qui fait enfin lire un verset : jusqu'ici le module servait
/// la Bible factice (`placeholder_bible.dart`), le portail produisait les
/// archives, et personne ne les téléchargeait.
///
/// ## Le contrat de l'archive, mesuré côté serveur
///
/// L'URL vit dans `bible_versions.archive_url`, et sa clé est
/// `uploads/bible/<code>-<12 hex du sha256>.zip`. Le zip (pas de dossier
/// enveloppe, pas de zip64, noms ASCII) porte :
///
/// - `manifest.json` — `code`, `name`, `language`, `license`, `filled`, et
///   `versification` : par code OSIS, le nombre de versets de chaque chapitre
///   (`[14, 17, 24, 0]`) ;
/// - `books/01.json` … `books/66.json` — `book` (son rang dans le canon) et
///   `chapters`, un tableau de tableaux de versets. **Un fichier par livre**.
///
/// Un chapitre **vide** (`[]`) n'est pas une avarie : il dit « ce chapitre
/// n'existe pas dans cette version ». La S21 déclare Malachie 4 et le laisse
/// vide parce qu'elle suit la Bible hébraïque, et la `versification` du
/// manifeste le relève `0` (`versification.dart`).
///
/// ## Pourquoi l'empreinte n'a que 12 caractères
///
/// L'intégrité se vérifie en recalculant le sha256 des octets reçus et en
/// comparant **les 12 premiers caractères hexadécimaux** à ceux que porte le
/// nom de l'archive — décision du propriétaire du produit. Il n'y a rien
/// d'autre à comparer : **aucune colonne ne stocke l'empreinte complète**, et
/// 48 bits suffisent largement à détecter une troncature ou un octet retourné,
/// seul accident qu'une origine HTTPS laisse passer. Une archive qui ne
/// correspond pas **ne s'installe pas** : [BibleArchiveException].
///
/// ## Où les octets se rangent, et pourquoi pas dans le cache
///
/// Sous `getApplicationSupportDirectory()`, comme `MessageMediaStore` (T1,
/// #223) et pour la même raison mesurée : `getTemporaryDirectory()` est vidé
/// par le système quand il veut, donc « téléchargé pour lire hors réseau » n'y
/// est **jamais** durable. Le chemin retenu est enregistré dans
/// `bible_installed_versions.localPath` ; désinstaller l'emporte.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'bible_source.dart';
import 'canon.dart';

/// Descendre une archive, en annonçant sa progression. C'est la **seule**
/// couture réseau de la tranche : les tests y posent des octets en mémoire,
/// sans canal de plugin ni serveur (même patron que `ContentPlayer` devant
/// `just_audio`).
typedef BibleArchiveFetch = Future<List<int>> Function(
  String url,
  void Function(int received, int total) onProgress,
);

/// L'archive est refusée. Rien n'est installé, et l'écran le dit.
final class BibleArchiveException implements Exception {
  const BibleArchiveException(this.reason);

  /// Pour le journal, pas pour l'écran : les libellés viennent des `.arb`.
  final String reason;

  @override
  String toString() => 'BibleArchiveException: $reason';
}

/// L'implémentation réelle de [BibleArchiveFetch].
///
/// `ResponseType.bytes` et non un fichier : une version pèse quelques Mo, et
/// l'empreinte se calcule de toute façon sur l'ensemble des octets — les
/// écrire pour les relire ne servirait à rien. `onReceiveProgress` ne reçoit
/// `total` que si l'origine annonce `Content-Length` ; sinon il vaut `-1`, et
/// la barre reste indéterminée plutôt que de mentir.
Future<List<int>> downloadBibleArchive(
  String url,
  void Function(int received, int total) onProgress,
) async {
  final response = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
    onReceiveProgress: onProgress,
  );
  final data = response.data;
  if (data == null || data.isEmpty) {
    throw const BibleArchiveException('archive vide');
  }
  return data;
}

/// **Les 12 hex que le nom de l'archive porte**, ou `null` s'il n'en porte
/// pas. Ancré sur la fin de l'URL (ou sur son `?`) : un tiret suivi de douze
/// hex plus tôt dans le chemin ne doit pas passer pour l'empreinte.
String? bibleArchiveFingerprint(String url) =>
    RegExp(r'-([0-9a-f]{12})\.zip(?:$|\?|#)').firstMatch(url)?.group(1);

/// Les **seules** entrées attendues dans le zip. Tout le reste est écarté, et
/// ce n'est pas de la coquetterie : un nom d'entrée est une chaîne servie, et
/// `../` y écrirait hors du dossier de la version (« zip slip »).
final RegExp _expectedEntry = RegExp(r'^(manifest\.json|books/\d{2}\.json)$');

/// Un code de version ne nomme un dossier qu'une fois réduit à ce qui ne peut
/// pas sortir du magasin — il vient du serveur, on ne le suppose pas sain
/// (même garde que `MessageMediaStore._safe`).
String _safeCode(String code) => code.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');

/// Le dossier de la version [code], **qu'il existe ou non**.
Future<Directory> bibleVersionDirectory(
  String code, {
  Future<Directory> Function()? root,
}) async {
  final base = await (root ?? getApplicationSupportDirectory)();
  return Directory('${base.path}/bible/${_safeCode(code)}');
}

/// Ce qu'une archive installée laisse derrière elle : son dossier, et la
/// versification que son manifeste relève (`null` s'il n'en relève pas — le
/// canon figé sert alors de repli, C3 #240).
typedef BibleArchiveInstalled = ({String localPath, String? versification});

/// **Vérifie [bytes] contre l'empreinte de [url], puis les dézippe** dans le
/// dossier de [code]. Lève [BibleArchiveException] sans rien écrire si
/// l'empreinte manque, ne correspond pas, ou si l'archive n'a pas de
/// manifeste.
///
/// Le dossier est **effacé d'abord** : une réinstallation ne doit pas laisser
/// cohabiter les livres de deux éditions.
Future<BibleArchiveInstalled> unpackBibleArchive({
  required String code,
  required String url,
  required List<int> bytes,
  Future<Directory> Function()? root,
}) async {
  final expected = bibleArchiveFingerprint(url);
  if (expected == null) {
    // Sans empreinte au nom, il n'y a **rien** à comparer : refuser est le
    // seul choix sûr, puisque aucune colonne ne porte le sha256 complet.
    throw const BibleArchiveException('aucune empreinte au nom de l\'archive');
  }
  final actual = sha256.convert(bytes).toString().substring(0, 12);
  if (actual != expected) {
    throw BibleArchiveException('empreinte $actual, attendue $expected');
  }

  final dir = await bibleVersionDirectory(code, root: root);
  if (dir.existsSync()) await dir.delete(recursive: true);
  await Directory('${dir.path}/books').create(recursive: true);
  for (final entry in ZipDecoder().decodeBytes(bytes)) {
    if (!entry.isFile || !_expectedEntry.hasMatch(entry.name)) continue;
    final content = entry.readBytes();
    if (content == null) continue;
    await File('${dir.path}/${entry.name}').writeAsBytes(content);
  }

  final manifest = File('${dir.path}/manifest.json');
  if (!manifest.existsSync()) {
    await dir.delete(recursive: true);
    throw const BibleArchiveException('manifest.json absent');
  }
  return (localPath: dir.path, versification: _versificationOf(manifest));
}

/// La versification du manifeste, **ré-encodée telle quelle** pour la colonne
/// `bible_installed_versions.versification` — c'est la forme que
/// [BibleVersification.tryParse] relit. `null` si le manifeste n'en porte pas
/// ou si elle est illisible : le canon figé reprend alors la main, ce qui est
/// exactement l'état d'une version installée avant C3.
String? _versificationOf(File manifest) {
  try {
    final decoded = jsonDecode(manifest.readAsStringSync());
    if (decoded is! Map) return null;
    final counts = decoded['versification'];
    if (counts is! Map) return null;
    final json = jsonEncode(counts);
    return BibleVersification.tryParse(json) == null ? null : json;
  } on FormatException {
    return null;
  }
}

/// **Le texte d'une version installée**, lu dans son dossier.
///
/// Un fichier **par livre**, et c'est tout l'intérêt : [chapter] est le seul
/// membre que l'application appelle, donc lire Jean coûte ~60 Ko au lieu des
/// 4 Mo de la version entière. Un seul livre reste en mémoire — le lecteur
/// avance chapitre par chapitre dans le même livre, et l'indexation plein
/// texte (M3) parcourt les chapitres livre par livre : avec ce cache,
/// construire l'index lit 66 fichiers au lieu de 1 189.
final class InstalledBibleSource implements BibleSource {
  InstalledBibleSource(this.versionCode, this.directory);

  @override
  final String versionCode;

  /// `bible_installed_versions.localPath`.
  final String directory;

  String? _book;
  Future<List<List<String>>>? _chapters;

  @override
  Future<List<BibleVerse>> chapter(String book, int chapter) async {
    final chapters = await _chaptersOf(book);
    if (chapter < 1 || chapter > chapters.length) return const [];
    return [
      for (final (i, text) in chapters[chapter - 1].indexed)
        BibleVerse(i + 1, text),
    ];
  }

  /// Le futur du livre en cache, ou celui du livre demandé. L'appelant tient
  /// *son* futur : un second livre demandé entre-temps remplace le cache sans
  /// perturber la lecture déjà lancée.
  Future<List<List<String>>> _chaptersOf(String book) {
    if (_book == book && _chapters != null) return _chapters!;
    _book = book;
    return _chapters = _read(book);
  }

  /// `books/NN.json`, où `NN` est le **rang du livre dans le canon**, 1-indexé
  /// et sur deux chiffres — ce que le champ `book` du fichier répète. Un livre
  /// que cette version n'a pas (l'éwé 2014 n'a ni Esther ni Daniel) n'a pas de
  /// fichier, et se lit vide au lieu de lever.
  Future<List<List<String>>> _read(String book) async {
    final index = bibleBook(book)?.index;
    if (index == null) return const [];
    final file = File(
      '$directory/books/${(index + 1).toString().padLeft(2, '0')}.json',
    );
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const [];
      final chapters = decoded['chapters'];
      if (chapters is! List) return const [];
      return [
        for (final c in chapters)
          if (c is List)
            [
              for (final v in c)
                if (v is String) v,
            ]
          else
            const <String>[],
      ];
    } on FormatException {
      // Un fichier abîmé se lit vide : le lecteur affiche un chapitre vide,
      // il ne rougit pas au milieu de l'Écriture.
      return const [];
    }
  }
}
