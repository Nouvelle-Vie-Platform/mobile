import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/features/notes_editor/links/note_link.dart';

/// Le contrat du lien, aligné sur `isValidNoteLink` du serveur.
void main() {
  const uuid = '0192a5b4-7c3d-7e8f-9a0b-1c2d3e4f5a6b';

  group('aller-retour', () {
    for (final url in [
      'https://example.org/page?x=1#a',
      'http://example.org',
      'nv://note/$uuid',
      'nv://teaching/$uuid',
      'nv://bible/John/3',
      'nv://bible/John/3/16',
      'nv://bible/John/3/16-18',
      'nv://bible/1Cor/13/4-7',
    ]) {
      test(url, () => expect(NoteLink.parse(url)!.toUrl(), url));
    }
  });

  test('le bon type pour chaque schéma', () {
    expect(NoteLink.parse('https://a.b'), isA<WebLink>());
    expect(NoteLink.parse('nv://note/$uuid'),
        isA<NoteRefLink>().having((l) => l.noteId, 'noteId', uuid));
    expect(NoteLink.parse('nv://teaching/$uuid'),
        isA<TeachingLink>().having((l) => l.teachingId, 'id', uuid));
    final bible = NoteLink.parse('nv://bible/Ps/23/1-6')! as BibleLink;
    expect((bible.book, bible.chapter, bible.from, bible.to), ('Ps', 23, 1, 6));
  });

  group('refus', () {
    for (final url in [
      'javascript:alert(1)',
      'data:text/html,x',
      'file:///etc/passwd',
      'ftp://example.org',
      'https://',
      'example.org',
      'nv://foo/$uuid',
      'nv://note/pas-un-uuid',
      'nv://note/$uuid/extra',
      'nv://bible/Jean/3',
      'nv://bible/john/3',
      'nv://bible/John/0',
      'nv://bible/John/3/0',
      'nv://bible/John/3/18-16',
      'nv://bible/John/3/-16',
      'nv://bible/John',
      'https://${'a' * 2000}',
    ]) {
      test(url.length > 40 ? '${url.substring(0, 40)}…' : url,
          () => expect(NoteLink.parse(url), isNull));
    }
  });

  test('les 66 livres', () {
    expect(osisBooksFr, hasLength(66));
    expect(osisBooksFr.keys.first, 'Gen');
    expect(osisBooksFr.keys.last, 'Rev');
  });

  group('libellés français', () {
    test('chapitre seul',
        () => expect(const BibleLink('Ps', 23).labelFr, 'Psaumes 23'));
    test(
        'un verset',
        () =>
            expect(const BibleLink('John', 3, from: 16).labelFr, 'Jean 3:16'));
    test(
        'une plage',
        () => expect(const BibleLink('John', 3, from: 16, to: 18).labelFr,
            'Jean 3:16-18'));
    test(
        'plage d\'un verset',
        () => expect(const BibleLink('1Cor', 13, from: 4, to: 4).labelFr,
            '1 Corinthiens 13:4'));
  });

  group('saisie d\'une adresse web', () {
    test('https ajouté', () {
      expect(
          WebLink.fromInput('  example.org/a ')!.url, 'https://example.org/a');
    });
    test('schéma gardé', () {
      expect(
          WebLink.fromInput('http://example.org')!.url, 'http://example.org');
    });
    test('refus', () {
      expect(WebLink.fromInput(''), isNull);
      expect(WebLink.fromInput('deux mots'), isNull);
      expect(WebLink.fromInput('javascript://x%0Aalert(1)'), isNull);
    });
  });
}
