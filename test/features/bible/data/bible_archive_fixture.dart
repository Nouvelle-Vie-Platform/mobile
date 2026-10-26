/// **Une archive de version, fabriquée pour les tests** (C4) : un zip au
/// contrat du portail, et le nom de fichier qui porte **l'empreinte de ces
/// octets-là**.
///
/// C'est le zip qui est fabriqué, pas un double de son lecteur : les tests
/// traversent donc `ZipDecoder`, le sha256 et le manifeste, comme sur
/// l'appareil. Seule la descente réseau est remplacée.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// Les octets d'une archive et l'URL qui va avec.
typedef FakeBibleArchive = ({Uint8List bytes, String url});

/// Un zip de version : `manifest.json` et un `books/NN.json` par entrée de
/// [books] (la clé est le rang du livre dans le canon, 1-indexé).
///
/// [extras] ajoute des entrées hors contrat — de quoi vérifier qu'elles ne
/// sont pas écrites ; [withManifest] à `false` en retire le manifeste.
FakeBibleArchive fakeBibleArchive({
  required String code,
  Map<String, List<int>> versification = const {
    'Gen': [31]
  },
  Map<int, List<List<String>>> books = const {},
  Map<String, String> extras = const {},
  bool withManifest = true,
  String host = 'https://example.test/uploads/bible',
}) {
  final zip = Archive();
  if (withManifest) {
    zip.add(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'code': code,
          'name': 'Version $code',
          'language': 'fr',
          'license': 'domaine public',
          'versification': versification,
          'filled': <String>[],
        }),
      ),
    );
  }
  books.forEach((book, chapters) {
    zip.add(
      ArchiveFile.string(
        'books/${book.toString().padLeft(2, '0')}.json',
        jsonEncode({'book': book, 'chapters': chapters}),
      ),
    );
  });
  extras.forEach((name, content) => zip.add(ArchiveFile.string(name, content)));
  final bytes = Uint8List.fromList(ZipEncoder().encode(zip));
  return (bytes: bytes, url: urlFor(code, bytes, host: host));
}

/// L'URL d'une archive : `<code>-<12 hex du sha256>.zip`.
String urlFor(
  String code,
  List<int> bytes, {
  String host = 'https://example.test/uploads/bible',
}) =>
    '$host/$code-${sha256.convert(bytes).toString().substring(0, 12)}.zip';
