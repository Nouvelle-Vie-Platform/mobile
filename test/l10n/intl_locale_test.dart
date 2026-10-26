/// **La locale donnée à `intl` n'est pas celle de l'application** (#247).
///
/// `package:intl` ne connaît pas l'éwé. `DateFormat.Hm('ee')` lève, et l'écran
/// affiche un bloc rouge à la place de sa date — constaté sur l'émulateur le
/// 26/10/2026, où l'accueil perdait sa section « À venir » entière.
///
/// Le premier test prouve la prémisse : sans lui, les deux suivants pourraient
/// rester verts parce qu'`intl` aurait appris l'éwé entre-temps, et personne
/// ne saurait que la garde ne garde plus rien.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('la prémisse : intl refuse toujours l’éwé', () {
    expect(() => DateFormat.yMMMMd('ee').format(DateTime(2026, 10, 26)),
        throwsA(isA<ArgumentError>()));
    // Et le repli, lui, formate sans broncher.
    expect(DateFormat.yMMMMd('fr').format(DateTime(2026, 10, 26)), isNotEmpty);
  });

  test('intlLocale renvoie le français pour l’éwé, et rien d’autre', () {
    // La règle est trop petite pour mériter un widget : on la relit à la source,
    // ce qui évite de monter un `BuildContext` pour une ligne.
    final source = File('lib/l10n/l10n_extension.dart').readAsStringSync();
    expect(
      source,
      contains(
          "String get intlLocale => localeName == 'ee' ? 'fr' : localeName;"),
      reason: 'La règle a changé de forme : ce test et son commentaire aussi.',
    );
  });

  /// Le vrai garde-fou. Il ne vérifie pas un comportement mais une **discipline** :
  /// aucune date ne doit être formatée avec `localeName`. Sans lui, la règle se
  /// perdrait au premier écran ajouté — et elle s'était déjà perdue partout avant
  /// cette tranche.
  test('aucune fonction de date n’est appelée avec localeName', () {
    // Les fonctions de date se **découvrent** plutôt que de s'énumérer à la main :
    // une liste écrite en dur cesserait d'être vraie à la première ajoutée, et le
    // dépôt reproche déjà ça ailleurs (« un nombre écrit à la main ne se met pas
    // à jour tout seul »).
    //
    // ⚠️ Les fonctions **privées** comptent autant que les publiques : le défaut
    // d'origine vivait dans `_monthTitle` de l'agenda, et une première version de
    // ce test les écartait — elle laissait donc passer précisément ce qu'elle
    // devait attraper. Mesuré par contre-épreuve.
    final fichiers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
            (f) => f.path.endsWith('.dart') && !f.path.startsWith('lib/l10n'))
        .toList();

    final dateHelpers = <String>{};
    for (final f in fichiers) {
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final def = RegExp(r'^\s*String _?(\w+)\(').firstMatch(lignes[i]);
        if (def == null) continue;
        // Le corps, jusqu'à la prochaine définition ou dix lignes plus loin.
        final fin = (i + 10).clamp(0, lignes.length);
        if (lignes.sublist(i, fin).any((l) => l.contains('DateFormat'))) {
          dateHelpers.add(
              RegExp(r'^\s*String (_?\w+)\(').firstMatch(lignes[i])!.group(1)!);
        }
      }
    }
    expect(dateHelpers, isNotEmpty,
        reason:
            'Aucune fonction de date trouvée : le motif de détection est à revoir.');

    final fautes = <String>[];
    for (final f in fichiers) {
      final lignes = f.readAsLinesSync();
      for (var i = 0; i < lignes.length; i++) {
        final l = lignes[i];
        if (!l.contains('localeName')) continue;
        final estDate = l.contains('DateFormat') ||
            dateHelpers.any((h) => l.contains('$h('));
        if (estDate) fautes.add('${f.path}:${i + 1}  ${l.trim()}');
      }
    }
    expect(fautes, isEmpty,
        reason:
            'Ces lignes formatent une date avec localeName : elles lèveront '
            'sous la locale « ee ». Employer intlLocale.\n${fautes.join('\n')}');
  });
}
