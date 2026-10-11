import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/notes_editor/note_content.dart';

/// Le lecteur pur Dart du Delta : ce que la liste, le `body` serveur et le
/// PDF partagent. Un Delta de référence couvre chaque construction.
void main() {
  String delta(List<Map<String, dynamic>> ops) => jsonEncode({'ops': ops});

  group('deltaToPlainText', () {
    test('titres sur leur ligne, corps, gras aplati', () {
      final json = delta([
        {'insert': 'Mon titre'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {'insert': 'Du '},
        {
          'insert': 'gras',
          'attributes': {'bold': true},
        },
        {'insert': ' et la suite.\n'},
      ]);
      expect(deltaToPlainText(json), 'Mon titre\nDu gras et la suite.');
    });

    test('puces, numéros recommencés, cases cochées ou non, retrait', () {
      final json = delta([
        {'insert': 'Un'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'},
        },
        {'insert': 'Deux'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 1},
        },
        {'insert': 'Premier'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Second'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Pause\n'},
        {'insert': 'Encore premier'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'Fait'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'},
        },
        {'insert': 'À faire'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]);
      expect(
        deltaToPlainText(json),
        '• Un\n'
        '  • Deux\n'
        '1. Premier\n'
        '2. Second\n'
        'Pause\n'
        '1. Encore premier\n'
        '☑ Fait\n'
        '☐ À faire',
      );
    });

    test('un embed nvAttachment devient [Pièce jointe : nom]', () {
      final json = delta([
        {'insert': 'Avant\n'},
        {
          'insert': {
            'nvAttachment': {
              'kind': 'image',
              'key': 'note-media/o/1.jpg',
              'name': 'photo.jpg',
            },
          },
        },
        {'insert': '\nAprès\n'},
      ]);
      expect(
        deltaToPlainText(json),
        'Avant\n[Pièce jointe : photo.jpg]\nAprès',
      );
    });

    test('monostyle et citation gardent leur texte', () {
      final json = delta([
        {'insert': 'code'},
        {
          'insert': '\n',
          'attributes': {'code-block': true},
        },
        {'insert': 'citation'},
        {
          'insert': '\n',
          'attributes': {'blockquote': true},
        },
      ]);
      expect(deltaToPlainText(json), 'code\ncitation');
      final lines = parseNoteLines(json);
      expect(lines[0].codeBlock, isTrue);
      expect(lines[1].blockQuote, isTrue);
    });

    test('null, vide, JSON cassé ou non-Delta rendent une chaîne vide', () {
      expect(deltaToPlainText(null), '');
      expect(deltaToPlainText(''), '');
      expect(deltaToPlainText('{pas du json'), '');
      expect(deltaToPlainText('{"autre": 1}'), '');
      expect(deltaToPlainText('42'), '');
    });

    test('un Delta sans \\n final garde sa dernière ligne', () {
      expect(
        deltaToPlainText(
          delta([
            {'insert': 'sans fin'},
          ]),
        ),
        'sans fin',
      );
    });
  });

  group('plainToDeltaJson', () {
    test('une seule opération terminée par un retour à la ligne', () {
      expect(
        jsonDecode(plainToDeltaJson('a\nb')),
        {
          'ops': [
            {'insert': 'a\nb\n'},
          ],
        },
      );
      expect(
        jsonDecode(plainToDeltaJson('déjà\n')),
        {
          'ops': [
            {'insert': 'déjà\n'},
          ],
        },
      );
    });

    test('aller-retour texte → Delta → texte', () {
      const text = 'Première ligne\n\nTroisième ligne';
      expect(deltaToPlainText(plainToDeltaJson(text)), text);
    });
  });

  group('parseNoteLines', () {
    test('lit les attributs en ligne et de bloc', () {
      final lines = parseNoteLines(
        delta([
          {
            'insert': 'lien',
            'attributes': {
              'link': 'https://e.x',
              'color': '#e53935',
              'background': '#f8d05e',
              'underline': true,
              'strike': true,
              'italic': true,
            },
          },
          {
            'insert': '\n',
            'attributes': {'header': 2, 'indent': 9},
          },
        ]),
      );
      expect(lines, hasLength(1));
      final span = lines.single.spans.single;
      expect(span.link, 'https://e.x');
      expect(span.color, '#e53935');
      expect(span.background, '#f8d05e');
      expect(span.underline, isTrue);
      expect(span.strike, isTrue);
      expect(span.italic, isTrue);
      expect(span.bold, isFalse);
      expect(lines.single.header, 2);
      expect(lines.single.indent, 3, reason: 'borné à 0–3');
    });

    test('accepte aussi la liste d\'opérations nue', () {
      expect(deltaToPlainText('[{"insert":"nu\\n"}]'), 'nu');
    });
  });

  group('NotePreview.firstLines', () {
    test('saute les lignes vides et borne le nombre', () {
      final json = plainToDeltaJson('un\n\n\ndeux\ntrois\nquatre');
      expect(NotePreview.firstLines(json, 3), 'un\ndeux\ntrois');
      expect(NotePreview.firstLines(null, 3), '');
    });
  });

  test('la liste fermée des attributs est celle du serveur', () {
    expect(noteAllowedAttributes, {
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
    });
  });
}
