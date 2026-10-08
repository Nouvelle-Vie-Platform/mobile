import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/utils/message_links.dart';

void main() {
  test('rien sans adresse http(s)', () {
    expect(extractLinks(null), isEmpty);
    expect(extractLinks(''), isEmpty);
    expect(
        extractLinks('Rendez-vous sur eglise.fr ou ecrivez a a@b.fr'), isEmpty);
    expect(extractLinks('le protocole http est ancien'), isEmpty);
    expect(extractLinks('ftp://serveur.fr/fichier'), isEmpty);
    expect(extractLinks('https:// rien'), isEmpty);
    expect(extractLinks('https://pasdedomaine'), isEmpty);
  });

  test('la ponctuation finale ne fait pas partie du lien', () {
    expect(extractLinks('Voir https://a.fr/x.'), ['https://a.fr/x']);
    expect(extractLinks('Lien : https://a.fr/x, merci !'), ['https://a.fr/x']);
    expect(extractLinks('« https://a.fr/x »'), ['https://a.fr/x']);
    expect(extractLinks('vraiment https://a.fr?!'), ['https://a.fr']);
  });

  test('parenthèses : fermante retirée sauf si le lien l’ouvre', () {
    expect(extractLinks('(voir https://a.fr/page)'), ['https://a.fr/page']);
    expect(
      extractLinks('https://fr.wikipedia.org/wiki/Foi_(théologie)'),
      ['https://fr.wikipedia.org/wiki/Foi_(théologie)'],
    );
    expect(
      extractLinks('(https://fr.wikipedia.org/wiki/Foi_(théologie)).'),
      ['https://fr.wikipedia.org/wiki/Foi_(théologie)'],
    );
    expect(extractLinks('[https://a.fr]'), ['https://a.fr']);
  });

  test('plusieurs liens par message, dans l’ordre, requête comprise', () {
    expect(
      extractLinks(
        'Culte : https://youtu.be/abc?t=10 et HTTP://Eglise.fr/agenda\n'
        'puis https://a.fr/x#ancre',
      ),
      [
        'https://youtu.be/abc?t=10',
        'HTTP://Eglise.fr/agenda',
        'https://a.fr/x#ancre',
      ],
    );
  });
}
