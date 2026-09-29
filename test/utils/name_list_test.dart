import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/utils/name_list.dart';

/// **La jonction d'une liste de noms** (#77).
///
/// Elle est en Dart et non dans l'ARB : un fichier de traduction sait accueillir
/// une liste (« Avec {names} »), il ne sait pas l'énumérer — les formes
/// `{plural}` de l'ICU comptent des éléments, elles ne les assemblent pas. Une
/// clé par cardinalité plafonnerait le nombre d'invités à ce que le traducteur a
/// prévu.
void main() {
  group('joinNames', () {
    test('un seul nom sort seul : ni virgule, ni conjonction', () {
      expect(joinNames(const ['Pasteur Kossi'], and: 'et'), 'Pasteur Kossi');
    });

    test('deux noms : la conjonction seule', () {
      expect(
        joinNames(const ['Pasteur Kossi', 'Sœur Afi'], and: 'et'),
        'Pasteur Kossi et Sœur Afi',
      );
    });

    test('trois noms : virgules, puis la conjonction', () {
      // Pas de virgule avant la conjonction — elle est fautive en français, et
      // c'est la forme que le dépôt a retenue pour les deux langues servies.
      expect(
        joinNames(
          const ['Pasteur Kossi', 'Sœur Afi', 'Frère Yao'],
          and: 'et',
        ),
        'Pasteur Kossi, Sœur Afi et Frère Yao',
      );
    });

    test('la conjonction est celle qu\'on passe, jamais « et » en dur', () {
      // C'est un mot de la langue de l'interface. Le coder ici donnerait un
      // « et » français au milieu d'une phrase anglaise.
      expect(
        joinNames(const ['Pastor Kossi', 'Sister Afi'], and: 'and'),
        'Pastor Kossi and Sister Afi',
      );
    });

    test('l\'ordre reçu est l\'ordre rendu', () {
      // L'ordre vient de `position`, saisi au portail. Le retrier remplacerait
      // une donnée par une convention.
      expect(
        joinNames(const ['Zoé Abalo', 'Ami Bodjona'], and: 'et'),
        'Zoé Abalo et Ami Bodjona',
      );
    });

    test('une liste vide rend une chaîne vide, à l\'appelant d\'en conclure',
        () {
      // La fonction n'a pas à inventer un libellé d'absence : c'est l'appelant
      // qui décide de ne rien rendre du tout (règle du dépôt — l'absence
      // s'affiche comme une absence).
      expect(joinNames(const [], and: 'et'), isEmpty);
    });
  });
}
