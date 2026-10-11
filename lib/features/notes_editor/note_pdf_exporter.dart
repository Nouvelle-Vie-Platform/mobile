/// **Le partage d'une note en PDF** (N3, #191 ; décision 14 du plan).
///
/// Un Delta rendu en widgets du paquet `pdf` : titre, corps, titres 1–3,
/// listes et cases, couleurs, surlignage, citation, monostyle, photos. Police
/// Atkinson Hyperlegible embarquée depuis les actifs du dépôt (quatre
/// graisses) ; le monostyle sort en Courier, la seule chasse fixe que le
/// paquet embarque sans fichier de plus.
///
/// **Les images ne sont pas téléchargées ici** : [NotePdfExporter.build]
/// reçoit un `loadImage(key)` — N4 le branchera sur l'URL signée — et ne
/// l'appelle que pour les **vingt premières** photos ; les suivantes, comme les
/// vidéos, audios et fichiers, deviennent une ligne « Pièce jointe : nom »
/// (piège 8 du plan). Le rendu lui-même tourne **hors de l'isolate principal**
/// (`Isolate.run`), sauf sur le web qui n'en a pas.
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show BuildContext, Offset, RenderBox;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'note_content.dart';

class NotePdfExporter {
  const NotePdfExporter();

  /// Au-delà, une photo devient une ligne « Pièce jointe : nom ».
  static const int maxImages = 20;

  static const String _fontDir = 'assets/fonts/Atkinson_Hyperlegible';

  /// Les octets du PDF. [loadImage] rend les octets d'une photo (`key` de
  /// l'embed), ou `null` si elle est hors de portée — elle sort alors en
  /// ligne de texte.
  Future<Uint8List> build({
    required String title,
    required String contentJson,
    required Future<Uint8List?> Function(String key) loadImage,
  }) async {
    final images = <String, Uint8List>{};
    var seen = 0;
    for (final line in parseNoteLines(contentJson)) {
      for (final span in line.spans) {
        final key = _imageKey(span);
        if (key == null) continue;
        if (++seen > maxImages) break;
        if (images.containsKey(key)) continue;
        final bytes = await loadImage(key);
        if (bytes != null) images[key] = bytes;
      }
    }

    final fonts = await Future.wait([
      for (final file in const [
        'Regular',
        'Bold',
        'Italic',
        'BoldItalic',
      ])
        rootBundle.load('$_fontDir/AtkinsonHyperlegible-$file.ttf').then(
            (d) => d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes)),
    ]);

    final input = _RenderInput(
      title: title,
      contentJson: contentJson,
      images: images,
      regular: fonts[0],
      bold: fonts[1],
      italic: fonts[2],
      boldItalic: fonts[3],
    );
    return kIsWeb
        ? _renderNotePdf(input)
        : Isolate.run(() => _renderNotePdf(input));
  }

  static String? _imageKey(NoteSpan span) {
    final a = span.attachment;
    if (a == null || a['kind'] != 'image') return null;
    return a['key'] as String?;
  }
}

/// Envoie le PDF à la feuille de partage du système, sous le nom
/// `<titre-slug>.pdf` ; share_plus écrit lui-même le fichier temporaire.
Future<void> shareNoteAsPdf(
  BuildContext context,
  String title,
  Uint8List bytes,
) async {
  final name = '${noteFileSlug(title)}.pdf';
  // L'iPad exige l'origine du popover ; ailleurs elle est ignorée.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: 'application/pdf')],
      fileNameOverrides: [name],
      subject: title,
      sharePositionOrigin: origin,
    ),
  );
}

/// `Réunion d'équipe — été` → `reunion-d-equipe-ete` ; `note` si rien ne reste.
String noteFileSlug(String title) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'õ': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ɖ': 'd',
    'ɛ': 'e',
    'ɔ': 'o',
    'ŋ': 'n',
    'ƒ': 'f',
  };
  final buffer = StringBuffer();
  for (final rune in title.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(accents[ch] ?? ch);
  }
  final slug = buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) return 'note';
  return slug.length > 60 ? slug.substring(0, 60) : slug;
}

class _RenderInput {
  const _RenderInput({
    required this.title,
    required this.contentJson,
    required this.images,
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  final String title;
  final String contentJson;
  final Map<String, Uint8List> images;
  final Uint8List regular;
  final Uint8List bold;
  final Uint8List italic;
  final Uint8List boldItalic;
}

// Les couleurs de la charte, recopiées : `AppColors` tire `dart:ui`, que
// l'isolate de rendu n'a pas à charger.
final PdfColor _primary = PdfColor.fromHex('#223b8c');
final PdfColor _accent = PdfColor.fromHex('#f8d05e');
final PdfColor _surfaceAlt = PdfColor.fromHex('#f0f0f0');
final PdfColor _textSecondary = PdfColor.fromHex('#6b7280');

/// Le rendu pur Dart, exécutable dans un isolate.
Future<Uint8List> _renderNotePdf(_RenderInput input) async {
  final doc = pw.Document(
    title: input.title,
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(ByteData.sublistView(input.regular)),
      bold: pw.Font.ttf(ByteData.sublistView(input.bold)),
      italic: pw.Font.ttf(ByteData.sublistView(input.italic)),
      boldItalic: pw.Font.ttf(ByteData.sublistView(input.boldItalic)),
    ),
  );

  final renderer = _Renderer(input.images);
  final widgets = <pw.Widget>[
    if (input.title.trim().isNotEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Text(
          input.title,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ...renderer.render(parseNoteLines(input.contentJson)),
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      maxPages: 400,
      build: (_) => widgets,
    ),
  );
  return doc.save();
}

class _Renderer {
  _Renderer(this.images);

  final Map<String, Uint8List> images;
  final List<int> _counters = List<int>.filled(4, 0);
  int _imagesSeen = 0;

  List<pw.Widget> render(List<NoteLine> lines) {
    final out = <pw.Widget>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.codeBlock || line.blockQuote) {
        final isCode = line.codeBlock;
        final group = <NoteLine>[];
        while (i < lines.length &&
            (isCode ? lines[i].codeBlock : lines[i].blockQuote)) {
          group.add(lines[i++]);
        }
        _counters.fillRange(0, _counters.length, 0);
        out.add(isCode ? _codeBlock(group) : _quote(group));
        continue;
      }
      out.addAll(_line(line));
      i++;
    }
    return out;
  }

  pw.TextStyle _baseStyle(NoteLine line) => switch (line.header) {
        1 => pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        2 => pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        3 => pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        _ => const pw.TextStyle(fontSize: 11),
      };

  List<pw.Widget> _line(NoteLine line) {
    final list = line.list;
    if (list == 'ordered') {
      _counters[line.indent]++;
      _counters.fillRange(line.indent + 1, _counters.length, 0);
    } else {
      _counters.fillRange(0, _counters.length, 0);
    }

    final base = _baseStyle(line);
    final out = <pw.Widget>[];
    var run = <pw.InlineSpan>[];
    var first = true;

    void flush() {
      if (run.isEmpty && !first) return;
      final text = pw.RichText(
        text: pw.TextSpan(
          style: base,
          children: run.isEmpty ? [const pw.TextSpan(text: ' ')] : run,
        ),
      );
      out.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            top: line.header != null ? 10 : 2,
            bottom: 2,
            left: line.indent * 14,
          ),
          child: first && list != null
              ? pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 16,
                      padding: const pw.EdgeInsets.only(top: 1),
                      child: _marker(list, line.indent),
                    ),
                    pw.Expanded(child: text),
                  ],
                )
              : text,
        ),
      );
      run = <pw.InlineSpan>[];
      first = false;
    }

    for (final span in line.spans) {
      if (span.isAttachment) {
        flush();
        out.add(_attachment(span));
      } else {
        run.add(pw.TextSpan(text: span.text, style: _inlineStyle(span)));
      }
    }
    flush();
    return out;
  }

  pw.Widget _marker(String list, int indent) => switch (list) {
        'bullet' => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, left: 2),
            child: pw.Container(
              width: 4,
              height: 4,
              decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle),
            ),
          ),
        'ordered' => pw.Text(
            '${_counters[indent]}.',
            style: const pw.TextStyle(fontSize: 11),
          ),
        _ => pw.Container(
            width: 9,
            height: 9,
            margin: const pw.EdgeInsets.only(top: 2),
            padding: const pw.EdgeInsets.all(1.5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.8),
              borderRadius: pw.BorderRadius.circular(1.5),
            ),
            child: list == 'checked'
                ? pw.Container(color: _primary)
                : pw.SizedBox(),
          ),
      };

  pw.TextStyle _inlineStyle(NoteSpan span) {
    final decorations = [
      if (span.underline || span.link != null) pw.TextDecoration.underline,
      if (span.strike) pw.TextDecoration.lineThrough,
    ];
    final color = span.color;
    return pw.TextStyle(
      fontWeight: span.bold ? pw.FontWeight.bold : null,
      fontStyle: span.italic ? pw.FontStyle.italic : null,
      decoration:
          decorations.isEmpty ? null : pw.TextDecoration.combine(decorations),
      color: span.link != null
          ? _primary
          : (color != null ? PdfColor.fromHex(color) : null),
      background:
          span.background != null ? pw.BoxDecoration(color: _accent) : null,
    );
  }

  pw.Widget _attachment(NoteSpan span) {
    final a = span.attachment!;
    final key = a['key'] as String?;
    if (a['kind'] == 'image' && key != null) {
      _imagesSeen++;
      final bytes = images[key];
      if (_imagesSeen <= NotePdfExporter.maxImages && bytes != null) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Image(
            pw.MemoryImage(bytes),
            height: 320,
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.centerLeft,
          ),
        );
      }
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Text(
        attachmentLabel(span.attachmentName),
        style: pw.TextStyle(
          fontSize: 11,
          fontStyle: pw.FontStyle.italic,
          color: _textSecondary,
        ),
      ),
    );
  }

  pw.Widget _codeBlock(List<NoteLine> lines) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _surfaceAlt,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            pw.Text(
              line.plainText,
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10),
            ),
        ],
      ),
    );
  }

  pw.Widget _quote(List<NoteLine> lines) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      padding: const pw.EdgeInsets.only(left: 10, top: 2, bottom: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: _primary, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(fontSize: 11, color: _textSecondary),
                children: [
                  for (final span in line.spans)
                    pw.TextSpan(
                      text: span.isAttachment
                          ? attachmentLabel(span.attachmentName)
                          : span.text,
                      style: _inlineStyle(span),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
