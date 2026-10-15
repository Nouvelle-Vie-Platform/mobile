import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/notes_editor/note_pdf_exporter.dart';

/// L'export PDF : des octets `%PDF` pour un Delta qui couvre chaque style,
/// une borne de vingt photos, et un `loadImage` qui peut rendre `null`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Un PNG de 1 × 1 pixel, valide.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  Map<String, dynamic> image(int i) => {
        'insert': {
          'nvAttachment': {
            'kind': 'image',
            'key': 'note-media/o/$i.png',
            'name': 'photo-$i.png',
          },
        },
      };

  final reference = jsonEncode({
    'ops': [
      {'insert': 'Titre'},
      {
        'insert': '\n',
        'attributes': {'header': 1},
      },
      {'insert': 'Sous-titre'},
      {
        'insert': '\n',
        'attributes': {'header': 2},
      },
      {'insert': 'Titre secondaire'},
      {
        'insert': '\n',
        'attributes': {'header': 3},
      },
      {'insert': 'Corps avec '},
      {
        'insert': 'gras',
        'attributes': {'bold': true},
      },
      {'insert': ', '},
      {
        'insert': 'italique',
        'attributes': {'italic': true},
      },
      {'insert': ', '},
      {
        'insert': 'souligné',
        'attributes': {'underline': true},
      },
      {'insert': ', '},
      {
        'insert': 'barré',
        'attributes': {'strike': true},
      },
      {'insert': ', '},
      {
        'insert': 'rouge',
        'attributes': {'color': '#e53935'},
      },
      {'insert': ', '},
      {
        'insert': 'surligné',
        'attributes': {'background': '#f8d05e'},
      },
      {'insert': ' et '},
      {
        'insert': 'lien',
        'attributes': {'link': 'https://exemple.org'},
      },
      {'insert': '.\n'},
      {'insert': 'Puce'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet'},
      },
      {'insert': 'Puce en retrait'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet', 'indent': 2},
      },
      {'insert': 'Numéro'},
      {
        'insert': '\n',
        'attributes': {'list': 'ordered'},
      },
      {'insert': 'Coché'},
      {
        'insert': '\n',
        'attributes': {'list': 'checked'},
      },
      {'insert': 'À faire'},
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
      {'insert': 'print("mono")'},
      {
        'insert': '\n',
        'attributes': {'code-block': true},
      },
      {'insert': 'ligne 2'},
      {
        'insert': '\n',
        'attributes': {'code-block': true},
      },
      {'insert': 'Une citation'},
      {
        'insert': '\n',
        'attributes': {'blockquote': true},
      },
      image(1),
      {'insert': '\n'},
      {
        'insert': {
          'nvAttachment': {
            'kind': 'video',
            'key': 'note-media/o/v.mp4',
            'name': 'film.mp4',
          },
        },
      },
      {'insert': '\nFin.\n'},
    ],
  });

  test('un Delta de référence produit un PDF', () async {
    final keys = <String>[];
    final bytes = await const NotePdfExporter().build(
      title: 'Note de référence',
      contentJson: reference,
      loadImage: (key) async {
        keys.add(key);
        return png;
      },
    );
    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
    expect(keys, ['note-media/o/1.png'], reason: 'seule la photo est chargée');
  });

  test('une photo introuvable (null) sort en ligne, le PDF se fait quand même',
      () async {
    final bytes = await const NotePdfExporter().build(
      title: '',
      contentJson: reference,
      loadImage: (_) async => null,
    );
    expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('vingt photos au plus sont demandées', () async {
    final ops = <Map<String, dynamic>>[];
    for (var i = 0; i < 25; i++) {
      ops
        ..add(image(i))
        ..add({'insert': '\n'});
    }
    var asked = 0;
    final bytes = await const NotePdfExporter().build(
      title: 'Album',
      contentJson: jsonEncode({'ops': ops}),
      loadImage: (_) async {
        asked++;
        return Uint8List.fromList(png);
      },
    );
    expect(asked, NotePdfExporter.maxImages);
    expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('une note vide produit un PDF', () async {
    final bytes = await const NotePdfExporter().build(
      title: 'Nouvelle note',
      contentJson: '',
      loadImage: (_) async => null,
    );
    expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('noteFileSlug', () {
    expect(noteFileSlug("Réunion d'équipe — été"), 'reunion-d-equipe-ete');
    expect(noteFileSlug('   '), 'note');
    expect(noteFileSlug('Ɖeɖe ŋu'), 'dede-nu');
    expect(noteFileSlug('a' * 100), hasLength(60));
  });
}
