// Le **repli en bloc** d'un document légal (ADR-0035).
//
// C'est le troisième des trois garde-fous que l'ADR exige, et le seul qui
// rougisse : la fonction porte le nom du motif, un commentaire renvoie ici, et
// ce fichier prouve qu'**une seule** section manquante bascule le document
// entier — pas « la majorité ».
//
// Sans lui, la règle se perd à la première relecture de bonne foi : un
// document mélangé s'affiche parfaitement, ne lève rien, et ne fait rougir
// aucun autre test du dépôt.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/legal_document_view.dart';

/// Trois sections **complètes** dans les trois langues.
List<LegalSection> completeSections() => [
      LegalSection(
        key: 'objet',
        heading: const {'fr': 'Objet', 'en': 'Purpose', 'ee': 'Taɖodzinu'},
        body: const {
          'fr': 'Le service.',
          'en': 'The service.',
          'ee': 'Dɔwɔna.'
        },
      ),
      LegalSection(
        key: 'compte',
        heading: const {'fr': 'Compte', 'en': 'Account', 'ee': 'Akɔnta'},
        body: const {
          'fr': 'Un compte.',
          'en': 'An account.',
          'ee': 'Akɔnta ɖeka.'
        },
      ),
      LegalSection(
        key: 'contact',
        heading: const {'fr': 'Contact', 'en': 'Contact', 'ee': 'Kadodo'},
        body: const {
          'fr': 'Écrivez-nous.',
          'en': 'Write to us.',
          'ee': 'Ŋlɔ na mí.'
        },
      ),
    ];

void main() {
  group('resolveLegalLocale — la locale se décide une fois, pour tout', () {
    test('un document complet en éwé sort intégralement en éwé', () {
      expect(resolveLegalLocale(completeSections(), 'ee'), 'ee');
    });

    test('une SEULE section manquante bascule le document ENTIER', () {
      // Deux sections sur trois portent l'éwé. Le document sort en français —
      // pas « majoritairement en éwé ». C'est le point que cet ADR protège.
      final sections = completeSections();
      sections[1] = LegalSection(
        key: 'compte',
        heading: const {'fr': 'Compte', 'en': 'Account', 'ee': 'Akɔnta'},
        body: const {'fr': 'Un compte.', 'en': 'An account.'},
      );

      expect(resolveLegalLocale(sections, 'ee'), 'fr');
    });

    test('un heading manquant suffit, autant qu\'un body', () {
      final sections = completeSections();
      sections[2] = LegalSection(
        key: 'contact',
        heading: const {'fr': 'Contact', 'en': 'Contact'},
        body: const {'fr': 'Écrivez-nous.', 'ee': 'Ŋlɔ na mí.'},
      );

      expect(resolveLegalLocale(sections, 'ee'), 'fr');
    });

    test('une traduction amorcée mais blanche compte comme absente', () {
      // Le trou que cet ADR ferme : un article vide se lit comme un article
      // qu'on n'a pas le droit d'accepter, pas comme une traduction.
      final sections = completeSections();
      sections[0] = LegalSection(
        key: 'objet',
        heading: const {'fr': 'Objet', 'ee': 'Taɖodzinu'},
        body: const {'fr': 'Le service.', 'ee': '   '},
      );

      expect(resolveLegalLocale(sections, 'ee'), 'fr');
    });

    test('le français demandé rend le français, sans rien parcourir', () {
      // Aucune section n'a besoin d'être complète : `fr` est la langue de repli
      // et la seule que le serveur exige.
      expect(resolveLegalLocale(const [], 'fr'), 'fr');
      expect(resolveLegalLocale(completeSections(), 'fr_FR'), 'fr');
    });

    test('la sous-étiquette suffit : `ee_TG` vaut `ee`', () {
      expect(resolveLegalLocale(completeSections(), 'ee_TG'), 'ee');
    });

    test('une locale vide retombe sur le français', () {
      expect(resolveLegalLocale(completeSections(), ''), 'fr');
    });
  });

  group('LegalDocumentView.resolve — un document déjà replié', () {
    test('en éwé, toutes les sections sortent en éwé', () {
      final document = LegalDocumentView.resolve(
        kind: LegalDocumentKind.terms,
        version: 3,
        sections: completeSections(),
        locale: 'ee',
      );

      expect(document.locale, 'ee');
      expect(document.sections.map((s) => s.heading),
          ['Taɖodzinu', 'Akɔnta', 'Kadodo']);
      expect(document.sections.first.body, 'Dɔwɔna.');
    });

    test('un trou en éwé fait sortir les TROIS sections en français', () {
      final sections = completeSections();
      sections[1] = LegalSection(
        key: 'compte',
        heading: const {'fr': 'Compte', 'ee': 'Akɔnta'},
        body: const {'fr': 'Un compte.'},
      );

      final document = LegalDocumentView.resolve(
        kind: LegalDocumentKind.terms,
        version: 3,
        sections: sections,
        locale: 'ee',
      );

      expect(document.locale, 'fr');
      // Y compris celles qui étaient traduites : le résultat est binaire.
      expect(document.sections.map((s) => s.heading),
          ['Objet', 'Compte', 'Contact']);
    });

    test('l\'ordre des sections est celui du document, jamais retrié', () {
      final document = LegalDocumentView.resolve(
        kind: LegalDocumentKind.privacy,
        version: 1,
        sections: completeSections(),
        locale: 'fr',
      );

      expect(
          document.sections.map((s) => s.key), ['objet', 'compte', 'contact']);
    });

    test('un champ absent jusqu\'en français se rend comme une absence', () {
      final document = LegalDocumentView.resolve(
        kind: LegalDocumentKind.about,
        version: 1,
        sections: [
          const LegalSection(key: 'vide', heading: {}, body: {}),
        ],
        locale: 'fr',
      );

      expect(document.sections.single.heading, isEmpty);
      expect(document.sections.single.body, isEmpty);
    });

    test('le pied préfère la mise à jour à la publication', () {
      final published = DateTime.utc(2026, 1, 4);
      final updated = DateTime.utc(2026, 3, 9);

      expect(
        LegalDocumentView.resolve(
          kind: LegalDocumentKind.terms,
          version: 2,
          sections: const [],
          locale: 'fr',
          publishedAt: published,
          updatedAt: updated,
        ).footerDate,
        updated,
      );
      expect(
        LegalDocumentView.resolve(
          kind: LegalDocumentKind.terms,
          version: 2,
          sections: const [],
          locale: 'fr',
          publishedAt: published,
        ).footerDate,
        published,
      );
      // Ni l'une ni l'autre : rien à afficher, et surtout pas une date inventée.
      expect(
        LegalDocumentView.resolve(
          kind: LegalDocumentKind.terms,
          version: 2,
          sections: const [],
          locale: 'fr',
        ).footerDate,
        isNull,
      );
    });
  });

  test('aucun fichier du domaine légal n\'appelle `pick`', () {
    // Garde-fou de **source**, comme celui qui interdit `just_audio` hors du
    // lecteur : un `pick(section.heading, locale)` glissé dans le rendu ne
    // casserait aucun test de comportement — il afficherait un document
    // mélangé, parfaitement, en silence. C'est exactement le piège d'ADR-0035.
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.path.contains('legal'));

    expect(sources, isNotEmpty);
    final coupables = <String>[];
    for (final source in sources) {
      // Les commentaires de documentation **parlent** de `pick` — c'est même
      // leur travail : dire qu'on ne s'en sert pas ici, et pourquoi.
      final code = source
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('///'))
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      if (RegExp(r'\bpick\s*\(').hasMatch(code)) coupables.add(source.path);
    }

    expect(
      coupables,
      isEmpty,
      reason: 'le repli d\'un document légal est en bloc (ADR-0035) : il passe '
          'par resolveLegalLocale, une fois, jamais par pick champ par champ',
    );
  });
}
