/// **La précédence, et ses trois chemins vers le mot du dépôt** (#81).
///
/// À ne pas confondre avec `test/utils/i18n_text_test.dart`, qui garde le repli
/// `fr/en/ee` du **contenu** servi par le back (`LocalizedText`). Ici il s'agit
/// de l'**interface** : la surcharge réglée au portail recouvre le `.arb`
/// compilé dans le binaire.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/l10n_extension.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/l10n/vocabulary.dart';
import 'package:maison_du_miracle/models/vocabulary.dart';

void main() {
  /// Monte un arbre minimal et rend `context.words` tel qu'un widget le lit.
  Future<AppWords> wordsUnder(
    WidgetTester tester, {
    VocabularyOverrides overrides = VocabularyOverrides.empty,
    Locale locale = const Locale('fr'),
    bool withScope = true,
  }) async {
    late AppWords words;
    final probe = Builder(builder: (context) {
      words = context.words;
      return const SizedBox.shrink();
    });

    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: withScope
          ? VocabularyScope(overrides: overrides, child: probe)
          : probe,
    ));
    // `pump()` puis `pump(1s)` — jamais `pumpAndSettle`.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return words;
  }

  group('La surcharge du portail l\'emporte', () {
    testWidgets('sur le `.arb` compilé', (tester) async {
      final words = await wordsUnder(
        tester,
        overrides: const VocabularyOverrides(labels: {
          'sectionLatestTeachings': {
            'fr': 'Derniers messages',
            'en': 'Latest messages',
          },
        }),
      );

      // C'est tout l'intérêt du réglage : sans cette précédence, il ne sert à
      // rien.
      expect(words.sectionLatestTeachings, 'Derniers messages');
    });

    testWidgets('dans la langue de l\'interface, pas dans une autre',
        (tester) async {
      final words = await wordsUnder(
        tester,
        locale: const Locale('en'),
        overrides: const VocabularyOverrides(labels: {
          'sectionLatestTeachings': {
            'fr': 'Derniers messages',
            'en': 'Latest messages',
          },
        }),
      );

      expect(words.sectionLatestTeachings, 'Latest messages');
    });

    testWidgets('et se replie sur le français comme le reste du dépôt',
        (tester) async {
      // La carte n'a que du français, l'interface est en éwé : `pick` replie,
      // exactement comme pour un contenu servi. La règle de repli est écrite
      // **une fois**, dans `utils/i18n_text.dart`.
      final words = await wordsUnder(
        tester,
        locale: const Locale('ee'),
        overrides: const VocabularyOverrides(labels: {
          'sectionLatestTeachings': {'fr': 'Derniers messages'},
        }),
      );

      expect(words.sectionLatestTeachings, 'Derniers messages');
    });
  });

  group('Trois chemins vers le mot du dépôt, et ce sont trois cas normaux', () {
    testWidgets('aucun cycle encore passé', (tester) async {
      // L'état de la toute première ouverture : le `.arb` n'est pas un repli
      // honteux, c'est l'état de départ légitime.
      final words = await wordsUnder(tester);

      expect(words.sectionLatestTeachings, 'Dernières publications');
    });

    testWidgets('aucune surcharge pour cette clé', (tester) async {
      final words = await wordsUnder(
        tester,
        overrides: const VocabularyOverrides(labels: {
          'filterTeachings': {'fr': 'Prêches'},
        }),
      );

      // Le portail surcharge une clé ; toutes les autres restent la vérité du
      // dépôt, et c'est le cas de la grande majorité d'entre elles.
      expect(words.filterTeachings, 'Prêches');
      expect(words.sectionLatestTeachings, 'Dernières publications');
    });

    testWidgets('une surcharge **vide** ne produit pas une chaîne vide',
        (tester) async {
      // Le piège : le serveur écrit `null` plutôt que de supprimer la ligne, et
      // une carte sans aucune langue remplie veut dire « garde le mot du
      // dépôt », jamais « affiche rien ». Un écran au titre blanc ne ressemble
      // pas à un bug — il ressemble à une donnée perdue.
      final words = await wordsUnder(
        tester,
        overrides: const VocabularyOverrides(labels: {
          'sectionLatestTeachings': <String, String>{},
          'filterTeachings': {'fr': '   ', 'en': ''},
        }),
      );

      expect(words.sectionLatestTeachings, 'Dernières publications');
      expect(words.filterTeachings, 'Messages');
    });
  });

  group('Sans scope, tout se lit sur le `.arb`', () {
    testWidgets('un arbre sans VocabularyScope ne casse pas', (tester) async {
      // C'est l'état d'un test d'écran monté sans frontière, et c'est le même
      // que la toute première ouverture : rien à décider, rien à surcharger.
      final words = await wordsUnder(tester, withScope: false);

      expect(words.overrides, VocabularyOverrides.empty);
      expect(words.sectionLatestTeachings, 'Dernières publications');
    });
  });

  group('Les termes', () {
    testWidgets('portent leurs deux formes, et aucune n\'est calculée',
        (tester) async {
      final words = await wordsUnder(
        tester,
        overrides: const VocabularyOverrides(terms: {
          'teaching': VocabularyTerm(
            singular: {'fr': 'message'},
            plural: {'fr': 'messages'},
          ),
        }),
      );

      // Le pluriel est **écrit à la main** au portail : aucun `+ 's'` nulle
      // part, et une phrase composée serait sa propre clé.
      expect(words.termSingular('teaching', 'enseignement'), 'message');
      expect(words.termPlural('teaching', 'enseignements'), 'messages');
    });

    testWidgets('une forme réglée seule laisse l\'autre au dépôt',
        (tester) async {
      final words = await wordsUnder(
        tester,
        overrides: const VocabularyOverrides(terms: {
          'teaching': VocabularyTerm(singular: {'fr': 'message'}),
        }),
      );

      expect(words.termSingular('teaching', 'enseignement'), 'message');
      expect(words.termPlural('teaching', 'enseignements'), 'enseignements');
    });

    testWidgets('un terme inconnu laisse le mot de l\'appelant',
        (tester) async {
      final words = await wordsUnder(tester);

      expect(words.termSingular('rubric', 'rubrique'), 'rubrique');
    });
  });
}
