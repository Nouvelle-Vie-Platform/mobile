/// **Le contenu d'une note, lu sans flutter_quill** (N3, #191).
///
/// Une note est stockée en **Delta Quill** (`{"ops": [...]}`). Trois lecteurs
/// n'ont pas besoin de l'éditeur pour le lire : l'aperçu des cartes de la
/// liste, le `body` aplati envoyé au serveur (recherche, aperçu), et l'export
/// PDF. Ce fichier est donc **pur Dart** : il décode le JSON, découpe les
/// lignes, et c'est tout.
///
/// ## Le modèle de ligne
///
/// Dans un Delta, les attributs **de bloc** (`header`, `list`, `indent`,
/// `code-block`, `blockquote`) sont portés par l'opération qui contient le
/// `\n` de fin de ligne ; les attributs **en ligne** (`bold`, `color`, …) par
/// les opérations de texte. [parseNoteLines] rend une [NoteLine] par ligne :
/// ses [NoteSpan] (texte ou embed) et ses attributs de bloc.
///
/// ## La liste fermée des attributs
///
/// [noteAllowedAttributes] est la liste que le serveur valide (plan §4). Elle
/// n'est pas appliquée ici — le lecteur rend ce qu'il reconnaît et ignore le
/// reste — mais c'est l'endroit où l'on vient la lire quand on ajoute un
/// bouton à la feuille Format : s'il n'y figure pas, le serveur répondra 422.
library;

import 'dart:convert';

/// Les attributs qu'un Delta de note peut porter — **la même liste que la
/// validation serveur**. Tout autre attribut est refusé à l'écriture (422).
const Set<String> noteAllowedAttributes = {
  'bold',
  'italic',
  'underline',
  'strike',
  'color',
  'background',
  'header',
  'list',
  'indent',
  'code-block',
  'blockquote',
  'link',
};

/// Le seul type d'embed d'une note : une pièce jointe (N4).
const String noteAttachmentEmbed = 'nvAttachment';

/// Un fragment de ligne : du texte avec ses attributs en ligne, **ou** une
/// pièce jointe (`nvAttachment`), jamais les deux.
class NoteSpan {
  const NoteSpan.text(this.text, this.attributes) : attachment = null;

  const NoteSpan.attachment(this.attachment)
      : text = '',
        attributes = const {};

  final String text;
  final Map<String, dynamic> attributes;

  /// Les données de l'embed `nvAttachment` (`kind`, `key`, `name`, …), ou
  /// `null` pour un fragment de texte.
  final Map<String, dynamic>? attachment;

  bool get isAttachment => attachment != null;

  /// Le nom de la pièce jointe, ou une chaîne vide.
  String get attachmentName => (attachment?['name'] as String?) ?? '';

  bool get bold => attributes['bold'] == true;
  bool get italic => attributes['italic'] == true;
  bool get underline => attributes['underline'] == true;
  bool get strike => attributes['strike'] == true;
  String? get color => attributes['color'] as String?;
  String? get background => attributes['background'] as String?;
  String? get link => attributes['link'] as String?;
}

/// Une ligne du Delta : ses fragments et ses attributs de bloc.
class NoteLine {
  const NoteLine(this.spans, this.attributes);

  final List<NoteSpan> spans;
  final Map<String, dynamic> attributes;

  /// `1`, `2` ou `3` pour un titre, `null` pour un corps.
  int? get header => switch (attributes['header']) {
        final int h when h >= 1 && h <= 3 => h,
        _ => null,
      };

  /// `bullet`, `ordered`, `checked`, `unchecked` ou `null`.
  String? get list => attributes['list'] as String?;

  /// Niveau de retrait, borné à 0–3.
  int get indent => switch (attributes['indent']) {
        final int i => i.clamp(0, 3),
        _ => 0,
      };

  bool get codeBlock => attributes['code-block'] == true;
  bool get blockQuote => attributes['blockquote'] == true;

  /// Le texte de la ligne, embeds compris sous la forme
  /// `[Pièce jointe : nom]`.
  String get plainText => spans
      .map((s) => s.isAttachment ? attachmentLabel(s.attachmentName) : s.text)
      .join();

  bool get isEmpty => spans.isEmpty;
}

/// Le libellé d'une pièce jointe dans le texte aplati et dans le PDF.
///
/// Du texte de **donnée** (il part dans `body`, qui sert la recherche), pas
/// d'interface : il reste en français, comme le contenu que l'utilisateur
/// tape autour.
String attachmentLabel(String name) => '[Pièce jointe : $name]';

/// Découpe un Delta JSON en lignes. Un JSON illisible, ou qui n'est pas un
/// Delta, rend une liste vide plutôt qu'une exception : une note corrompue ne
/// doit pas faire rougir une liste entière.
List<NoteLine> parseNoteLines(String? contentJson) {
  if (contentJson == null || contentJson.trim().isEmpty) return const [];

  final List<dynamic> ops;
  try {
    final decoded = jsonDecode(contentJson);
    ops = switch (decoded) {
      {'ops': final List<dynamic> list} => list,
      final List<dynamic> list => list,
      _ => const [],
    };
  } on FormatException {
    return const [];
  }

  final lines = <NoteLine>[];
  var spans = <NoteSpan>[];

  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    final attributes = switch (op['attributes']) {
      final Map m => Map<String, dynamic>.from(m),
      _ => <String, dynamic>{},
    };

    if (insert is String) {
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          spans.add(NoteSpan.text(parts[i], attributes));
        }
        if (i < parts.length - 1) {
          // Le `\n` porte les attributs de bloc de la ligne qu'il termine.
          lines.add(NoteLine(spans, attributes));
          spans = <NoteSpan>[];
        }
      }
    } else if (insert is Map && insert[noteAttachmentEmbed] is Map) {
      spans.add(
        NoteSpan.attachment(
          Map<String, dynamic>.from(insert[noteAttachmentEmbed] as Map),
        ),
      );
    }
    // Tout autre embed (image, vidéo de flutter_quill…) n'existe pas dans une
    // note : il est ignoré, comme le serveur le refuserait.
  }
  if (spans.isNotEmpty) lines.add(NoteLine(spans, const {}));
  return lines;
}

/// Le texte aplati d'un Delta — ce que la liste montre et ce que `body`
/// envoie au serveur.
///
/// Cases rendues `☐ ` / `☑ `, puces `• `, numéros `1. ` (recommencés à chaque
/// liste et à chaque niveau), retrait par deux espaces par niveau, titres sur
/// leur ligne, pièces jointes `[Pièce jointe : nom]`. Sans retour à la ligne
/// final.
String deltaToPlainText(String? contentJson) {
  final lines = parseNoteLines(contentJson);
  final counters = List<int>.filled(4, 0);
  final out = <String>[];

  for (final line in lines) {
    final list = line.list;
    if (list == 'ordered') {
      counters[line.indent]++;
      for (var i = line.indent + 1; i < counters.length; i++) {
        counters[i] = 0;
      }
    } else {
      counters.fillRange(0, counters.length, 0);
    }
    final marker = switch (list) {
      'bullet' => '• ',
      'ordered' => '${counters[line.indent]}. ',
      'checked' => '☑ ',
      'unchecked' => '☐ ',
      _ => '',
    };
    out.add('${'  ' * line.indent}$marker${line.plainText}');
  }
  return out.join('\n');
}

/// Le Delta d'un texte brut : une seule opération, terminée par `\n` comme
/// Quill l'exige. Même signature que la copie minimale de N2
/// (`lib/screens/notes/note_content.dart`), que celle-ci remplace à
/// l'intégration.
String plainToDeltaJson(String plainText) {
  final text = plainText.endsWith('\n') ? plainText : '$plainText\n';
  return jsonEncode({
    'ops': [
      {'insert': text},
    ],
  });
}

/// L'aperçu d'une carte de la liste.
abstract final class NotePreview {
  /// Les [count] premières lignes **non vides** du texte aplati.
  static String firstLines(String? contentJson, int count) {
    return deltaToPlainText(contentJson)
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(count)
        .join('\n');
  }
}
