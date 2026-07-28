import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/utils/i18n_text.dart';

void main() {
  group('pick', () {
    const complet = {'fr': 'Culte', 'en': 'Service', 'ee': 'Subɔsubɔ'};

    test('rend la langue demandée quand elle est présente', () {
      expect(pick(complet, 'fr'), 'Culte');
      expect(pick(complet, 'en'), 'Service');
      expect(pick(complet, 'ee'), 'Subɔsubɔ');
    });

    test('replie sur le français quand la langue est absente', () {
      const sansEwe = {'fr': 'Culte', 'en': 'Service'};
      expect(pick(sansEwe, 'ee'), 'Culte');
      // Une langue que le back ne sert pas du tout se replie pareil.
      expect(pick(sansEwe, 'es'), 'Culte');
    });

    test('replie sur le français quand la traduction éwé est amorcée à vide',
        () {
      // Traduction partielle : la clé existe mais n'est pas remplie. Sans ce
      // repli, l'écran afficherait un blanc.
      const partiel = {'fr': 'Culte', 'en': 'Service', 'ee': '   '};
      expect(pick(partiel, 'ee'), 'Culte');
    });

    test('ignore la sous-étiquette de région', () {
      expect(pick(complet, 'fr_FR'), 'Culte');
      expect(pick(complet, 'en-US'), 'Service');
    });

    test('sans français, retombe sur la première langue remplie', () {
      const sansFr = {'en': 'Service'};
      expect(pick(sansFr, 'ee'), 'Service');
    });

    test('rend une chaîne vide plutôt que null quand rien n\'est exploitable',
        () {
      expect(pick(const {}, 'fr'), '');
      expect(pick(const {'fr': ''}, 'fr'), '');
    });
  });
}
