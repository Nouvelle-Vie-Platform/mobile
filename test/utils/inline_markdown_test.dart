// Le **Markdown restreint** des documents légaux.
//
// Quatre constructions, et rien d'autre. Ce qui compte autant que les quatre :
// **ce qui n'est pas reconnu se rend littéralement**. Un `#` s'affiche comme
// un `#`, une balise HTML comme une balise HTML. Un texte légal qui perdrait
// silencieusement un caractère serait pire qu'un texte légal un peu laid — et
// le rédacteur croirait avoir publié ce qui a disparu.
//
// La restriction se tient aux **deux bouts** : le validateur serveur
// (`app/legal/support/restricted_markdown.ts`) refuse à l'écriture, ce parseur
// rend littéralement à la lecture. Les cas refusés là-bas sont donc exactement
// ceux qu'on vérifie ici comme rendus tels quels.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/utils/inline_markdown.dart';

const _body = TextStyle(fontSize: 16);
const _link =
    TextStyle(color: Color(0xFFF8D05E), decoration: TextDecoration.underline);

/// Le texte rendu, marques comprises ou non — c'est ce qu'un fidèle lit.
String rendered(String source) =>
    inlineMarkdownSpan(source, style: _body, linkStyle: _link).toPlainText();

/// Les fragments d'un texte, avec le style que chacun porte.
List<(String, TextStyle?)> fragments(String source) {
  final span = inlineMarkdownSpan(source, style: _body, linkStyle: _link);
  return [
    for (final child in span.children!.cast<TextSpan>())
      (child.text ?? '', child.style),
  ];
}

void main() {
  group('Les blocs — paragraphes et puces', () {
    test('des lignes consécutives font un paragraphe, une ligne blanche sépare',
        () {
      final blocks = parseMarkdownBlocks(
        'Première ligne\nseconde ligne\n\nAutre paragraphe',
      );

      expect(blocks, hasLength(2));
      expect(blocks.first.text, 'Première ligne\nseconde ligne');
      expect(blocks.last.text, 'Autre paragraphe');
      expect(blocks.every((b) => !b.isBullet), isTrue);
    });

    test('chaque puce est un bloc, et le tiret ne survit pas', () {
      final blocks = parseMarkdownBlocks(
        'Nous collectons :\n- votre nom\n- votre adresse',
      );

      expect(blocks.map((b) => b.isBullet), [false, true, true]);
      expect(blocks[1].text, 'votre nom');
      expect(blocks[2].text, 'votre adresse');
    });

    test('jusqu\'à trois espaces d\'indentation, comme le validateur serveur',
        () {
      expect(parseMarkdownBlocks('   - retrait').single.isBullet, isTrue);
      // Quatre espaces : ce n'est plus une puce, et le texte se rend entier.
      final tropLoin = parseMarkdownBlocks('    - retrait').single;
      expect(tropLoin.isBullet, isFalse);
      expect(tropLoin.text, '    - retrait');
    });

    test('`* ` et `+ ` ne sont pas des puces — ils se rendent tels quels', () {
      // Refusés à l'écriture côté serveur. Ici ils ne sont simplement pas
      // reconnus, et le caractère reste à l'écran.
      for (final ligne in ['* item', '+ item']) {
        final bloc = parseMarkdownBlocks(ligne).single;
        expect(bloc.isBullet, isFalse);
        expect(bloc.text, ligne);
      }
    });

    test('les trois orthographes de fin de ligne se découpent pareil', () {
      for (final saut in ['\n', '\r\n', '\r']) {
        expect(parseMarkdownBlocks('- un$saut- deux'), hasLength(2));
      }
    });

    test('un corps vide ne rend aucun bloc', () {
      expect(parseMarkdownBlocks(''), isEmpty);
      expect(parseMarkdownBlocks('\n\n  \n'), isEmpty);
    });
  });

  group('Les quatre constructions en ligne', () {
    test('gras', () {
      expect(
        fragments('Édité par l\'**Église Nouvelle Vie**.'),
        [
          ('Édité par l\'', null),
          ('Église Nouvelle Vie', const TextStyle(fontWeight: FontWeight.w700)),
          ('.', null),
        ],
      );
    });

    test('italique', () {
      expect(
        fragments('conservées *trois ans*'),
        [
          ('conservées ', null),
          ('trois ans', const TextStyle(fontStyle: FontStyle.italic)),
        ],
      );
    });

    test('lien : le libellé se rend, l\'URL ne s\'affiche pas', () {
      expect(
        fragments('Écrivez à [notre adresse](mailto:contact@nouvelle-vie.tg).'),
        [
          ('Écrivez à ', null),
          ('notre adresse', _link),
          ('.', null),
        ],
      );
    });

    test('le gras se lit avant l\'italique', () {
      // Sans cet ordre, `**gras**` se lirait comme deux italiques vides
      // encadrant le texte.
      final parts = fragments('**gras**');
      expect(parts, hasLength(1));
      expect(parts.single.$2!.fontWeight, FontWeight.w700);
      expect(parts.single.$2!.fontStyle, isNot(FontStyle.italic));
    });

    test('aucune imbrication : le contenu d\'une marque est littéral', () {
      // `**a *b* c**` ne rend pas un italique dans un gras : le gras l'emporte
      // et les astérisques intérieures restent à l'écran.
      expect(rendered('**a *b* c**'), 'a *b* c');
    });
  });

  group('Ce qui n\'est pas reconnu se rend LITTÉRALEMENT', () {
    test('un `#` en début de ligne n\'est pas avalé', () {
      expect(rendered('# Article premier'), '# Article premier');
    });

    test('une barre verticale reste une barre verticale', () {
      expect(rendered('| colonne | autre |'), '| colonne | autre |');
    });

    test('aucun HTML n\'est interprété, quelle que soit l\'origine', () {
      const attaque = '<b>gras ?</b> <script>alert(1)</script>';
      expect(rendered(attaque), attaque);
    });

    test('les autres constructions refusées par le serveur traversent', () {
      for (final source in [
        '> citation',
        '1. liste numérotée',
        '---',
        '~~barré~~',
        '`code`',
        '![alt](/image.png)',
        '[libellé][référence]',
        '[^1] note de bas de page',
      ]) {
        expect(rendered(source), source, reason: 'aucun caractère ne se perd');
      }
    });

    test('une marque non refermée se rend telle quelle', () {
      expect(rendered('*jamais refermé'), '*jamais refermé');
      expect(rendered('**non plus'), '**non plus');
      expect(rendered('[libellé](sans-fin'), '[libellé](sans-fin');
    });

    test('une multiplication garde ses astérisques', () {
      // Le contenu d'une marque ne peut ni commencer ni finir par une espace :
      // « 3 * 4 * 5 » n'est pas de l'italique, et personne ne doit découvrir en
      // production qu'un tarif s'est mis en italique.
      expect(rendered('3 * 4 * 5'), '3 * 4 * 5');
    });

    test('une marque vide n\'avale rien', () {
      expect(rendered('****'), '****');
      expect(rendered('**'), '**');
    });

    test('un lien ne traverse pas une fin de ligne', () {
      expect(
        rendered('[libellé\nsuite](https://exemple.tg)'),
        '[libellé\nsuite](https://exemple.tg)',
      );
    });

    test('un schéma hors du jeu du serveur n\'est pas un lien', () {
      // `ALLOWED_LINK_SCHEMES` côté serveur : `http`, `https`, `mailto`. Tout
      // le reste est refusé à l'écriture, et se rend donc entier ici — URL
      // comprise, plutôt que de la voir disparaître.
      for (final source in [
        '[voir](/relatif)',
        '[voir](javascript:alert(1))',
        '[voir](data:text/html;base64,AA)',
      ]) {
        expect(rendered(source), source);
      }
    });
  });

  group('Le rendu porte le style qu\'on lui donne, jamais le sien', () {
    test('le style du corps est celui du span racine', () {
      final span = inlineMarkdownSpan('texte', style: _body, linkStyle: _link);
      expect(span.style, _body);
    });

    test('le style de lien vient de l\'appelant — aucune couleur ici', () {
      // Les couleurs se décident dans le widget, à partir de `context.palette` :
      // c'est ce qui rend le document lisible en thème sombre.
      const autre = TextStyle(color: Color(0xFF00FF00));
      final parts = inlineMarkdownSpan(
        '[a](https://exemple.tg)',
        style: _body,
        linkStyle: autre,
      ).children!.cast<TextSpan>();

      expect(parts.single.style, autre);
    });

    test('un lien reste INERTE — aucun geste n\'y est attaché', () {
      // `url_launcher` n'est pas une dépendance du dépôt (§7 de la
      // spécification) : le lien se voit, il ne s'ouvre pas. Le jour où il
      // s'ouvrira, la vérification du schéma devra revenir avec lui.
      final parts = inlineMarkdownSpan(
        'voir [ici](https://exemple.tg)',
        style: _body,
        linkStyle: _link,
      ).children!.cast<TextSpan>();

      expect(parts.every((p) => p.recognizer == null), isTrue);
    });
  });
}
