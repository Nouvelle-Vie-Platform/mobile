import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/app_localizations.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/utils/branch_label.dart';

/// **Le libellé et l'ordre des branches dans un sélecteur.**
///
/// Deux règles s'y jouent, et aucune ne se signale quand elle casse :
///
/// - le **repli** quand `city` est nulle — une ligne vide serait inchoisissable,
///   et rien ne planterait ;
/// - le **tri**, qui ignore les accents. `compareTo` compare des unités de
///   code : « Tsévié » passe après « Zanzibar », et la ville accentuée se
///   retrouve reléguée en fin de liste sans qu'aucun test d'écran ne rougisse.
Branch _branch(
  int id, {
  String? city,
  String? name,
  bool isMotherChurch = false,
}) =>
    Branch(
      id: id,
      name: name ?? 'Eglise Evangélique Nouvelle Vie ${city ?? ''}'.trim(),
      city: city,
      isMotherChurch: isMotherChurch,
    );

void main() {
  late AppLocalizations fr;
  late AppLocalizations en;

  setUpAll(() async {
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('branchSelectionLabel', () {
    test('rend la ville seule, jamais le nom de l’église', () {
      final label = branchSelectionLabel(_branch(2, city: 'Kpalimé'), fr);

      expect(label, 'Kpalimé');
      expect(label, isNot(contains('Eglise')));
    });

    test(
        'L’ÉGLISE MÈRE PORTE SA MENTION : sans elle, rien ne dirait pourquoi '
        'elle est en tête', () {
      expect(
        branchSelectionLabel(
            _branch(1, city: 'Lomé', isMotherChurch: true), fr),
        'Lomé · Église Mère',
      );
    });

    test('la mention se traduit — elle ne vit pas en dur dans l’utilitaire',
        () {
      expect(
        branchSelectionLabel(
            _branch(1, city: 'Lomé', isMotherChurch: true), en),
        'Lomé · Mother Church',
      );
    });

    test('VILLE NULLE : repli sur le nom composé, long mais jamais faux', () {
      // Le portail permet de vider `city` ; une ligne vide serait une branche
      // impossible à choisir, sans que rien ne le signale.
      final orphan = _branch(3, name: 'Assemblée de Bè', city: null);

      expect(branchSelectionLabel(orphan, fr), 'Assemblée de Bè');
    });

    test('l’adresse n’entre JAMAIS dans le libellé', () {
      // Régression historique : « … Lomé · Nyekonakpoè Togbato, Lomé »
      // (commit 84bb6c6). L'adresse est une donnée de contact, pas un nom.
      const withAddress = Branch(
        id: 1,
        name: 'Eglise Evangélique Nouvelle Vie Lomé',
        city: 'Lomé',
        address: 'Nyekonakpoè Togbato, Lomé',
      );

      expect(branchSelectionLabel(withAddress, fr), 'Lomé');
    });
  });

  group('branchesForSelection', () {
    test('l’Église Mère passe en tête, le reste par ordre alphabétique', () {
      final sorted = branchesForSelection([
        _branch(9, city: 'Accra'),
        _branch(2, city: 'Kpalimé'),
        _branch(1, city: 'Lomé', isMotherChurch: true),
        _branch(3, city: 'Blakpa'),
      ], fr);

      expect(
        sorted.map((b) => b.city),
        ['Lomé', 'Accra', 'Blakpa', 'Kpalimé'],
      );
    });

    test('LE TRI IGNORE LES ACCENTS : « Tsévié » se range à T, pas après Z',
        () {
      final sorted = branchesForSelection([
        _branch(4, city: 'Vogan'),
        _branch(3, city: 'Tsévié'),
        _branch(2, city: 'Atakpamé'),
      ], fr);

      // Avec un `compareTo` brut, « Tsévié » (é > z en unités de code) serait
      // sorti **après** « Vogan ».
      expect(sorted.map((b) => b.city), ['Atakpamé', 'Tsévié', 'Vogan']);
    });

    test('l’ordre du serveur n’est pas conservé', () {
      // `/sync/branches` rend ses lignes par curseur `(updated_at, id)` : la
      // prochaine branche corrigée au portail changerait de place dans la liste.
      final input = [
        _branch(1, city: 'Tsévié'),
        _branch(2, city: 'Accra'),
      ];

      expect(branchesForSelection(input, fr).map((b) => b.city),
          ['Accra', 'Tsévié']);
      // La liste reçue n'est pas modifiée en place : elle appartient au provider.
      expect(input.map((b) => b.city), ['Tsévié', 'Accra']);
    });

    test('une branche sans ville se trie sur son libellé de repli', () {
      final sorted = branchesForSelection([
        _branch(2, city: 'Zanzibar'),
        _branch(3, name: 'Assemblée de Bè', city: null),
      ], fr);

      expect(sorted.first.name, 'Assemblée de Bè');
    });

    test('une liste vide reste vide — le référentiel peut ne rien rendre', () {
      expect(branchesForSelection(const [], fr), isEmpty);
    });
  });
}
