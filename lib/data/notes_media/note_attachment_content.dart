/// **Les pièces jointes dans le Delta d'une note** (N4, mobile#192) — pur
/// Dart, sans base ni réseau.
///
/// ## Le chemin local ne voyage pas
///
/// Une pièce jointe est insérée **tout de suite**, avant toute préparation ni
/// montée. Tant qu'elle n'a pas de clé, son embed porte `localId` (l'`embedId`
/// de sa ligne `pending_note_media`) et **pas** de `key` :
///
/// ```json
/// {"insert": {"nvAttachment": {"kind": "image", "name": "IMG_0042.jpg",
///   "mime": "image/jpeg", "size": 183402, "localId": "019f…"}}}
/// ```
///
/// Le fichier local se lit sur la ligne en attente (`localPath`), jamais dans
/// le Delta. Une fois montée, l'embed reçoit `key` (et `thumbKey`) et perd
/// `localId` : il a alors la forme exacte du contrat serveur.
///
/// Le serveur refuse tout champ hors de sa liste et exige `key` : la note part
/// donc par [serverNoteContent], qui **retire** les embeds encore sans clé et
/// tout champ inconnu. Le brouillon local, lui, les garde — d'où
/// [hasPendingAttachment], que la purge des brouillons doit respecter (voir le
/// README de `features/notes_editor/attachments/`).
library;

import 'dart:convert';

import '../../features/notes_editor/note_content.dart' show noteAttachmentEmbed;

/// Le champ **local** d'un embed pas encore monté.
const String kNoteAttachmentLocalId = 'localId';

/// Les champs que le serveur accepte dans un `nvAttachment`, et aucun autre.
const Set<String> kNoteAttachmentServerFields = {
  'kind',
  'key',
  'thumbKey',
  'name',
  'mime',
  'size',
  'duration',
  'width',
  'height',
};

/// Les ops d'un Delta JSON (`{"ops": […]}` ou `[…]`), ou `null` si illisible.
List<dynamic>? _opsOf(String? contentJson) {
  if (contentJson == null || contentJson.trim().isEmpty) return null;
  try {
    return switch (jsonDecode(contentJson)) {
      {'ops': final List<dynamic> ops} => ops,
      final List<dynamic> ops => ops,
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

/// Les données de l'embed `nvAttachment` d'une op, ou `null`.
Map<String, dynamic>? attachmentOf(Object? op) {
  if (op is! Map) return null;
  final insert = op['insert'];
  if (insert is! Map) return null;
  final data = insert[noteAttachmentEmbed];
  return data is Map ? Map<String, dynamic>.from(data) : null;
}

/// **Le contenu tel qu'il part au serveur** : les embeds sans `key` retirés,
/// les champs locaux ôtés. `null` reste `null` ; un JSON illisible est rendu
/// tel quel (le serveur le refusera, comme avant N4).
String? serverNoteContent(String? contentJson) {
  final ops = _opsOf(contentJson);
  if (ops == null) return contentJson;
  final out = <dynamic>[];
  for (final op in ops) {
    final data = attachmentOf(op);
    if (data == null) {
      out.add(op);
      continue;
    }
    if (data['key'] is! String) continue;
    out.add({
      ...(op as Map),
      'insert': {
        noteAttachmentEmbed: {
          for (final e in data.entries)
            if (kNoteAttachmentServerFields.contains(e.key)) e.key: e.value,
        },
      },
    });
  }
  return jsonEncode({'ops': out});
}

/// Le contenu porte-t-il une pièce jointe **pas encore montée** ?
bool hasPendingAttachment(String? contentJson) =>
    (_opsOf(contentJson) ?? const []).any(
      (op) => attachmentOf(op)?[kNoteAttachmentLocalId] is String,
    );

/// Le contenu cite-t-il l'embed [embedId] (par `localId`) ou la clé [key] ?
bool contentCites(String? contentJson, {String? embedId, String? key}) {
  for (final op in _opsOf(contentJson) ?? const []) {
    final data = attachmentOf(op);
    if (data == null) continue;
    if (embedId != null && data[kNoteAttachmentLocalId] == embedId) return true;
    if (key != null && data['key'] == key) return true;
  }
  return false;
}

/// [old] complété de [fields] ; une `key` posée fait tomber `localId`. Une
/// valeur `null` dans [fields] retire le champ.
Map<String, dynamic> mergeAttachment(
  Map<String, dynamic> old,
  Map<String, Object?> fields,
) {
  final merged = {...old};
  fields.forEach((k, v) => v == null ? merged.remove(k) : merged[k] = v);
  if (merged['key'] is String) merged.remove(kNoteAttachmentLocalId);
  return merged;
}

/// **Patche l'embed [embedId]** d'un Delta JSON. Rend le nouveau JSON, ou
/// `null` si l'embed n'y est pas (déjà patché, ou effacé par l'utilisateur).
String? patchAttachmentJson(
  String? contentJson,
  String embedId,
  Map<String, Object?> fields,
) {
  final ops = _opsOf(contentJson);
  if (ops == null) return null;
  var found = false;
  final out = [
    for (final op in ops)
      if (!found && attachmentOf(op)?[kNoteAttachmentLocalId] == embedId)
        () {
          found = true;
          return {
            ...(op as Map),
            'insert': {
              noteAttachmentEmbed: mergeAttachment(attachmentOf(op)!, fields),
            },
          };
        }()
      else
        op,
  ];
  return found ? jsonEncode({'ops': out}) : null;
}
