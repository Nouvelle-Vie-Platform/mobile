import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';

/// Les **quatre règles de lecture**, vérifiées à leur unique point
/// d'application.
///
/// Elles ne sont pas testées ici par précaution mais parce qu'aucune n'est
/// visible à l'œil nu depuis un écran : une couleur héritée, un libellé replié
/// et une URL préfixée ressemblent tous à « ça marche » tant qu'on ne regarde
/// pas la valeur exacte.
void main() {
  group('Règle 1 — la cascade de couleur se termine ici', () {
    test('la couleur de l\'enseignement l\'emporte sur celle de sa rubrique',
        () {
      final view = _view(color: 0xFF3B5BD0, typeColor: 0xFF1FA971);
      expect(view.color, 0xFF3B5BD0);
    });

    test('sans couleur propre, il hérite de celle de sa rubrique', () {
      // Le cœur de la décision : l'héritage se calcule **à la lecture**.
      // Résolu à l'écriture, changer la couleur d'une rubrique laisserait les
      // téléphones sur l'ancienne teinte — aucune ligne `teachings` n'étant
      // touchée, aucune ne repasserait par le flux delta.
      final view = _view(typeColor: 0xFF1FA971);
      expect(view.color, 0xFF1FA971);
    });

    test('sans l\'une ni l\'autre, c\'est le bleu de marque', () {
      final view = _view();
      expect(view.color, kBrandFallbackColor);
      expect(view.color, 0xFF223B8C);
    });

    test('une rubrique absente ne casse pas la cascade', () {
      // Cas courant : `teaching_types` n'a pas encore livré la rubrique.
      final view = _view(typeLabel: null, typeColor: null, color: 0xFFE53935);
      expect(view.color, 0xFFE53935);
    });
  });

  group('Règle 2 — le libellé se replie par `pick`', () {
    test('rend la langue demandée quand elle est remplie', () {
      final view = _view(
        typeLabel: const {'fr': 'Études bibliques', 'en': 'Bible studies'},
        locale: 'en',
      );
      expect(view.typeLabel, 'Bible studies');
    });

    test('se replie sur le français quand la langue manque', () {
      final view = _view(
        typeLabel: const {'fr': 'Archives', 'en': 'Archives'},
        locale: 'ee',
      );
      expect(view.typeLabel, 'Archives');
    });

    test('une traduction vide compte comme absente', () {
      // Une langue amorcée mais non remplie doit se replier comme une clé
      // manquante, sinon l'écran affiche du blanc.
      final view = _view(
        typeLabel: const {'fr': 'Moments de prière', 'ee': '   '},
        locale: 'ee',
      );
      expect(view.typeLabel, 'Moments de prière');
    });

    test('rubrique absente : chaîne vide, jamais `null`', () {
      // Un trou de contenu, pas une erreur à gérer dans chaque widget.
      expect(_view().typeLabel, '');
    });
  });

  group('Règle 3 — les URL d\'image sont résolues', () {
    test('un chemin relatif est préfixé par la base de l\'API', () {
      final view = _view(
        imageLandscapeUrl: '/uploads/teachings/abc.jpg',
        imagePortraitUrl: 'uploads/teachings/abc-p.jpg',
      );
      expect(view.imageLandscapeUrl,
          'http://localhost:3333/uploads/teachings/abc.jpg');
      expect(
        view.imagePortraitUrl,
        'http://localhost:3333/uploads/teachings/abc-p.jpg',
        reason: 'la barre oblique manquante est ajoutée, jamais doublée',
      );
    });

    test('une URL déjà absolue traverse intacte', () {
      final view = _view(imageLandscapeUrl: 'https://cdn.example.org/a.jpg');
      expect(view.imageLandscapeUrl, 'https://cdn.example.org/a.jpg');
    });

    test('l\'autre cadrage prend le relais quand l\'un manque', () {
      final landscapeOnly = _view(imageLandscapeUrl: '/a.jpg');
      expect(
          landscapeOnly.portraitOrLandscape, landscapeOnly.imageLandscapeUrl);

      final portraitOnly = _view(imagePortraitUrl: '/b.jpg');
      expect(portraitOnly.landscapeOrPortrait, portraitOnly.imagePortraitUrl);

      // Aucun des deux : rien à afficher, c'est la couleur qui habille.
      expect(_view().landscapeOrPortrait, isNull);
    });
  });

  group('Règle 4 — l\'absence s\'affiche comme une absence', () {
    test('un intervenant manquant reste `null`', () {
      // Surtout pas d'« Auteur inconnu » : ça ressemble à une donnée et sera
      // pris pour une erreur de saisie de l'église.
      expect(_view().authorName, isNull);
    });

    test('un nom blanc vaut un nom absent', () {
      expect(_view(contributorName: '   ').authorName, isNull);
    });

    test('un nom présent est conservé, débarrassé de ses blancs', () {
      expect(_view(contributorName: ' Pasteur Kossi ').authorName,
          'Pasteur Kossi');
    });

    test('l\'enseignement lui-même reste affichable sans aucune référence', () {
      final view = _view();
      expect(view.id, 't-1');
      expect(view.title, 'Dieu a le dernier mot');
      expect(view.teachingTypeId, isNull);
    });
  });

  group('HomeSectionView', () {
    test('replie son libellé et termine la cascade de couleur', () {
      final section = HomeSectionView.resolve(
        teachingTypeId: 4,
        label: const {'fr': 'Archives', 'en': 'Archives'},
        slug: 'archives',
        locale: 'ee',
        teachingCount: 3,
      );

      expect(section.label, 'Archives');
      expect(section.color, kBrandFallbackColor);
    });

    test('porte `layout` et `position` bruts — ticket #32', () {
      final section = HomeSectionView.resolve(
        teachingTypeId: 1,
        label: const {'fr': 'Messages du dimanche'},
        slug: 'dimanche',
        locale: 'fr',
        teachingCount: 3,
        layout: 'hero',
        position: 1,
        color: 0xFF223B8C,
      );

      // Jamais un enum : le référentiel est administrable, et une valeur
      // inconnue doit pouvoir arriver jusqu'à l'affichage pour s'y replier.
      expect(section.layout, 'hero');
      expect(section.position, 1);
      expect(section.color, 0xFF223B8C);
    });
  });
}

TeachingView _view({
  String locale = 'fr',
  String? contributorName,
  Map<String, String>? typeLabel,
  int? color,
  int? typeColor,
  String? imageLandscapeUrl,
  String? imagePortraitUrl,
}) =>
    TeachingView.resolve(
      id: 't-1',
      title: 'Dieu a le dernier mot',
      locale: locale,
      contributorName: contributorName,
      typeLabel: typeLabel,
      color: color,
      typeColor: typeColor,
      imageLandscapeUrl: imageLandscapeUrl,
      imagePortraitUrl: imagePortraitUrl,
    );
