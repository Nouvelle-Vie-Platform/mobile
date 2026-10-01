import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Rien ne gardait la parité des trois `.arb`.**
///
/// `test/i18n_test.dart` ne regarde que quatre chaînes et le mécanisme de
/// repli ; `flutter gen-l10n` se contente d'un **avertissement** sur une clé
/// manquante ; `flutter analyze` n'attrape qu'une clé **supprimée mais encore
/// appelée**. Une clé ajoutée au modèle français et oubliée en anglais passe
/// donc les trois filets, et se découvre en production, en anglais, par une
/// phrase française au milieu de l'écran.
///
/// Ce garde-fou lit les trois fichiers **à la source** — pas les
/// `app_localizations*.dart` générés, qui ont déjà appliqué le repli et ne
/// savent donc plus distinguer « traduit » de « rabattu ».
///
/// Trois accords, et une asymétrie assumée :
/// 1. toute clé du modèle `app_fr.arb` existe en anglais ;
/// 2. les placeholders d'une clé sont les mêmes d'une langue à l'autre ;
/// 3. aucune clé orpheline ne traîne en anglais ni en éwé ;
/// 4. **l'éwé est partiel par construction** — ses clés absentes se rabattent
///    sur le français (`lib/l10n/README.md`). Ce n'est pas une faute, et le
///    test l'énonce plutôt que de l'ignorer : il le vérifie comme un fait, et
///    rougit le jour où ce fait cesse d'être vrai.
void main() {
  Map<String, dynamic> readArb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  /// Les clés de **libellés** : ni les métadonnées `@clé`, ni l'entête `@@`.
  Set<String> labelKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// Les noms des placeholders employés par une chaîne ICU.
  ///
  /// `{count, plural, one{…} other{…}}` en rend `count` et pas `one` : un
  /// sélecteur de pluriel est suivi d'une accolade ouvrante, un placeholder
  /// d'une virgule ou d'une accolade fermante.
  Set<String> placeholders(String message) => RegExp(r'\{(\w+)\s*[,}]')
      .allMatches(message)
      .map((m) => m.group(1)!)
      .toSet();

  final fr = readArb('fr');
  final en = readArb('en');
  final ee = readArb('ee');

  final frKeys = labelKeys(fr);
  final enKeys = labelKeys(en);
  final eeKeys = labelKeys(ee);

  group('Parité des trois fichiers de traduction', () {
    test('toute clé du modèle français existe en anglais', () {
      final manquantes = frKeys.difference(enKeys).toList()..sort();
      expect(
        manquantes,
        isEmpty,
        reason: 'app_en.arb est complet par contrat (lib/l10n/README.md). '
            'Ces clés du modèle français y manquent, et s\'afficheraient en '
            'français à un anglophone : ${manquantes.join(', ')}',
      );
    });

    test('aucune clé orpheline en anglais', () {
      final orphelines = enKeys.difference(frKeys).toList()..sort();
      expect(
        orphelines,
        isEmpty,
        reason: 'Ces clés n\'existent plus dans le modèle app_fr.arb : elles '
            'ne seront jamais rendues, et survivent à une suppression mal '
            'propagée — ${orphelines.join(', ')}',
      );
    });

    test('aucune clé orpheline en éwé', () {
      final orphelines = eeKeys.difference(frKeys).toList()..sort();
      expect(
        orphelines,
        isEmpty,
        reason: 'Ces clés n\'existent plus dans le modèle app_fr.arb : '
            '${orphelines.join(', ')}',
      );
    });

    test('les placeholders d\'une clé sont les mêmes dans les trois langues',
        () {
      final ecarts = <String>[];
      for (final cle in frKeys) {
        final attendus = placeholders(fr[cle] as String);
        for (final MapEntry(key: langue, value: arb)
            in {'en': en, 'ee': ee}.entries) {
          if (!arb.containsKey(cle)) continue;
          final trouves = placeholders(arb[cle] as String);
          if (!setEquals(attendus, trouves)) {
            ecarts.add('$cle ($langue) : fr attend {${attendus.join(', ')}}, '
                '$langue emploie {${trouves.join(', ')}}');
          }
        }
      }
      expect(
        ecarts,
        isEmpty,
        reason: 'Un placeholder oublié rend une accolade vide ou lève à '
            'l\'exécution, dans cette langue-là seulement :\n'
            '${ecarts.join('\n')}',
      );
    });

    test('les placeholders employés par le modèle y sont tous déclarés', () {
      final ecarts = <String>[];
      for (final cle in frKeys) {
        final employes = placeholders(fr[cle] as String);
        if (employes.isEmpty) continue;
        final meta = fr['@$cle'] as Map<String, dynamic>?;
        final declares =
            (meta?['placeholders'] as Map<String, dynamic>?)?.keys.toSet() ??
                const <String>{};
        final oublies = employes.difference(declares).toList()..sort();
        if (oublies.isNotEmpty) {
          ecarts.add('$cle : ${oublies.join(', ')}');
        }
      }
      expect(
        ecarts,
        isEmpty,
        reason: 'Sans déclaration dans @clé, gen-l10n type le placeholder au '
            'jugé (Object), et la chaîne se formate autrement qu\'attendu :\n'
            '${ecarts.join('\n')}',
      );
    });

    test(
        'l\'éwé est partiel PAR CONSTRUCTION : ses clés absentes se rabattent '
        'sur le français', () {
      // Ce test ne tolère pas l'absence en silence : il l'affirme. L'éwé est
      // documenté « partiel — à relire par un locuteur natif »
      // (lib/l10n/README.md), et `gen-l10n` rabat les clés manquantes sur le
      // modèle français (délégués de lib/l10n/l10n_setup.dart).
      expect(
        eeKeys,
        isNotEmpty,
        reason: 'app_ee.arb vidé : l\'éwé ne serait plus une langue partielle, '
            'mais une langue absente',
      );
      final absentes = frKeys.difference(eeKeys);
      expect(
        absentes,
        isNotEmpty,
        reason: 'app_ee.arb porte désormais les ${frKeys.length} clés du '
            'modèle. C\'est une bonne nouvelle, et elle périme ce test ET le '
            'tableau de lib/l10n/README.md, qui annonce l\'éwé comme partiel : '
            'mettre les deux à jour, et faire relire la langue par un locuteur '
            'natif avant de la déclarer complète',
      );
    });
  });
}
