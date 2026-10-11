import 'dart:io';
import 'dart:typed_data';

import 'note_media_dao.dart';
import 'note_media_urls.dart';

/// **Les octets d'une photo de note, pour le PDF** (N4, mobile#192) — le
/// `loadImage` de `NotePdfExporter.build`.
///
/// Le fichier local tant qu'il existe (une photo qui vient d'être montée),
/// sinon l'URL signée, téléchargée **juste avant** la génération (piège 8 :
/// elle ne vaut qu'une heure). `null` si ni l'un ni l'autre : la photo sort en
/// ligne « Pièce jointe : nom ».
Future<Uint8List?> loadImageForPdf(
  String key, {
  required NoteMediaDao dao,
  required NoteMediaUrls urls,
}) async {
  final path = (await dao.byKey(key))?.localPath;
  if (path != null) {
    final file = File(path);
    if (await file.exists()) return file.readAsBytes();
  }
  return urls.bytes(key);
}
