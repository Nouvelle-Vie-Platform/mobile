/// **Le Markdown restreint des documents légaux** — le bout client de la
/// restriction, face à `app/legal/support/restricted_markdown.ts` côté serveur.
///
/// Quatre constructions, et **rien d'autre** :
///
/// | construction | syntaxe | rendu |
/// |---|---|---|
/// | gras | `**texte**` | `FontWeight.w700` |
/// | italique | `*texte*` | `FontStyle.italic` |
/// | lien | `[libellé](url)` | couleur d'accent + soulignement |
/// | liste à puces | ligne commençant par `- ` | puce + retrait |
///
/// Le `heading` d'une section étant un champ à part, le corps n'a plus besoin
/// de titres : ni `#`, ni tableaux, ni images, ni code, ni citations.
///
/// ## Deux règles de conception
///
/// 1. **Ce qui n'est pas reconnu se rend littéralement.** Un `#` en début de
///    ligne s'affiche comme un `#`, un `|` comme un `|`, un `<b>` comme un
///    `<b>` : rien n'est avalé, rien n'est nettoyé. Un texte légal qui perdrait
///    silencieusement un caractère serait pire qu'un texte légal un peu laid —
///    et le rédacteur croirait avoir publié ce qui a disparu. La restriction se
///    tient **aux deux bouts** : le validateur refuse à l'écriture, ce parseur
///    rend littéralement à la lecture.
/// 2. **Aucun HTML n'est interprété**, quelle que soit l'origine du texte.
///
/// ## Pourquoi pas un paquet
///
/// `flutter_markdown` a été **abandonné par l'équipe Flutter**, les reprises
/// sont communautaires, et il faudrait de toute façon recabler entièrement leur
/// thème sur `context.palette` sous peine de texte noir sur fond sombre.
/// Adosser un écran juridique à ça pour économiser cent lignes est un mauvais
/// échange.
///
/// ## Limite assumée : les liens n'ouvrent rien
///
/// `url_launcher` n'est pas une dépendance du dépôt, et l'ajouter pour un
/// `mailto:` dans une CGU ne se justifie pas encore. Les liens se rendent comme
/// des liens — couleur, soulignement — et restent **inertes** : aucun
/// `GestureRecognizer` n'est posé ici (§7 de `docs/documents-legaux.md`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Un **bloc** de corps : un paragraphe, ou une puce.
///
/// C'est la seule structure de niveau ligne que ce Markdown connaisse. Les
/// blocs sortent dans l'ordre du texte, et aucun caractère du corps n'est perdu
/// entre l'entrée et la sortie — hors la marque `- ` d'une puce, qui devient la
/// puce elle-même.
@immutable
class MarkdownBlock {
  const MarkdownBlock({required this.text, required this.isBullet});

  /// Le texte du bloc, marques **en ligne** comprises : c'est
  /// [inlineMarkdownSpan] qui les lit.
  final String text;

  /// `true` = la ligne commençait par `- `. Elle se rend avec une puce et un
  /// retrait, jamais avec le tiret conservé.
  final bool isBullet;

  @override
  bool operator ==(Object other) =>
      other is MarkdownBlock &&
      other.text == text &&
      other.isBullet == isBullet;

  @override
  int get hashCode => Object.hash(text, isBullet);
}

/// Découpe un corps en blocs.
///
/// Les lignes consécutives qui ne sont pas des puces forment **un** paragraphe,
/// jointes par un saut de ligne : un retour à la ligne voulu par le rédacteur
/// se voit, et une ligne blanche sépare deux paragraphes. Chaque puce est un
/// bloc à elle seule.
List<MarkdownBlock> parseMarkdownBlocks(String body) {
  final blocks = <MarkdownBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(
      MarkdownBlock(text: paragraph.join('\n'), isBullet: false),
    );
    paragraph.clear();
  }

  for (final line in body.split(RegExp(r'\r\n|\r|\n'))) {
    final bullet = _bulletContent(line);
    if (bullet != null) {
      flush();
      blocks.add(MarkdownBlock(text: bullet, isBullet: true));
      continue;
    }
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    paragraph.add(line.trimRight());
  }
  flush();

  return List<MarkdownBlock>.unmodifiable(blocks);
}

/// Le texte d'une puce, ou `null` si la ligne n'en est pas une.
///
/// Jusqu'à trois espaces d'indentation, comme le validateur serveur. **Seul
/// `- ` est une puce** : `* ` et `+ ` sont refusés à l'écriture et se rendent
/// donc littéralement ici — et `*italique*` en début de ligne n'est pas touché,
/// la marque exigeant une espace derrière elle.
String? _bulletContent(String line) {
  final match = RegExp(r'^ {0,3}- (.*)$').firstMatch(line);
  return match?.group(1);
}

/// Traduit les marques **en ligne** d'un texte en [TextSpan].
///
/// [style] est le style courant du corps ; [linkStyle] celui d'un lien
/// (couleur d'accent et soulignement, décidés par l'appelant à partir de
/// `context.palette` — aucune couleur n'est écrite ici).
///
/// Aucune imbrication : le contenu d'un gras, d'un italique ou d'un libellé de
/// lien est rendu **littéralement**. Une marque non refermée l'est aussi.
TextSpan inlineMarkdownSpan(
  String text, {
  required TextStyle style,
  required TextStyle linkStyle,
}) {
  final children = <InlineSpan>[];
  final literal = StringBuffer();

  void flushLiteral() {
    if (literal.isEmpty) return;
    children.add(TextSpan(text: literal.toString()));
    literal.clear();
  }

  var index = 0;
  while (index < text.length) {
    final rest = text.substring(index);

    // `**` avant `*` : sans cet ordre, un gras se lirait comme deux italiques
    // vides encadrant le texte.
    final strong = _delimited(rest, '**');
    if (strong != null) {
      flushLiteral();
      children.add(
        TextSpan(
          text: strong.content,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      index += strong.length;
      continue;
    }

    final emphasis = _delimited(rest, '*');
    if (emphasis != null) {
      flushLiteral();
      children.add(
        TextSpan(
          text: emphasis.content,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
      index += emphasis.length;
      continue;
    }

    // Un `[` précédé d'un `!` ouvre une **image** — refusée à l'écriture, et
    // qui doit donc se rendre entière, point d'exclamation compris. Sans cette
    // garde, `![alt](/img.png)` s'afficherait « !alt » : le seul cas où ce
    // parseur perdait des caractères en silence.
    final estImage = index > 0 && text[index - 1] == '!';
    final link = estImage ? null : _link(rest);
    if (link != null) {
      flushLiteral();
      // **Aucun `GestureRecognizer`** : le lien se voit, il ne s'ouvre pas.
      children.add(TextSpan(text: link.content, style: linkStyle));
      index += link.length;
      continue;
    }

    // Tout le reste est du texte, y compris `#`, `|`, `<b>`, `` ` `` et un `*`
    // ou un `[` que rien ne referme.
    literal.write(text[index]);
    index++;
  }
  flushLiteral();

  return TextSpan(style: style, children: children);
}

/// Un fragment reconnu : ce qu'il faut rendre, et ce qu'il a consommé.
@immutable
class _Match {
  const _Match(this.content, this.length);

  final String content;
  final int length;
}

/// `**gras**` ou `*italique*` en tête de [rest].
///
/// Trois conditions, et chacune évite d'avaler du texte qui n'était pas une
/// marque :
///
/// 1. le contenu est **non vide** ;
/// 2. la marque se referme **sur la même ligne** — un `*` orphelin ne doit pas
///    emporter le reste du paragraphe ;
/// 3. le contenu ne **commence ni ne finit par une espace**. C'est la règle de
///    flanquement de CommonMark, et elle sert ici un cas concret : « 3 * 4 * 5 »
///    dans un article tarifaire doit garder ses astérisques, pas se transformer
///    en « 3 *4* 5 ». Un texte légal qui perdrait silencieusement un caractère
///    serait pire qu'un texte légal un peu laid.
_Match? _delimited(String rest, String mark) {
  if (!rest.startsWith(mark)) return null;

  final from = mark.length;
  final close = rest.indexOf(mark, from);
  if (close <= from) return null;

  final content = rest.substring(from, close);
  if (content.contains('\n')) return null;
  if (content != content.trim()) return null;

  return _Match(content, close + mark.length);
}

/// `[libellé](url)` en tête de [rest].
///
/// Libellé non vide et sans crochet, URL sans espace ni parenthèse — la même
/// forme que celle qu'accepte le validateur serveur. Tout le reste (liens de
/// référence `[a][b]`, notes `[^1]`, crochets décoratifs) échoue ici et se rend
/// littéralement, crochets compris.
///
/// **Le schéma est celui du validateur serveur**, `ALLOWED_LINK_SCHEMES` de
/// `restricted_markdown.ts` : `http`, `https`, `mailto`, et rien d'autre. Ce
/// n'est pas de la défense en profondeur — un lien inerte n'exécute rien — mais
/// la stricte application de la règle du fichier : reconnaître **exactement**
/// ce que le serveur admet, et rendre littéralement tout le reste. Sans cela,
/// un `[voir](/relatif)` rejeté à l'écriture s'afficherait « voir », son URL
/// disparue en silence.
///
/// Le jour où les liens s'ouvriront (§7), cette vérification est déjà là.
_Match? _link(String rest) {
  final match = RegExp(r'^\[([^\]\n]+)\]\(([^\s()<>]+)\)').firstMatch(rest);
  if (match == null) return null;
  if (!RegExp(r'^(?:https?://|mailto:)', caseSensitive: false)
      .hasMatch(match.group(2)!)) {
    return null;
  }
  return _Match(match.group(1)!, match.group(0)!.length);
}
