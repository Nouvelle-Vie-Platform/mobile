import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/theme/app_colors.dart';
import 'package:maison_du_miracle/theme/status_palette.dart';

void main() {
  // `statusPalette` a disparu avec la refonte des annonces (#35) : l'habillage
  // d'un statut est **servi** par le référentiel `status_backgrounds`, et une
  // palette codée en dur est une décision figée à la livraison. Ce qui reste
  // ici ne sert qu'au repli — aucun fond choisi, ou fond pas encore
  // synchronisé — et c'est ce que vérifient les tests ci-dessous.

  group('statusBaseColor', () {
    test('est déterministe : même id ⇒ même couleur', () {
      for (final id in const ['a', 'ann-1', 'ann-42', 'statut-très-long-id']) {
        expect(statusBaseColor(id), statusBaseColor(id));
      }
    });

    test('reste dans un jeu fermé de 4 à 6 teintes distinctes', () {
      final seen = <Color>{
        for (var i = 0; i < 200; i++) statusBaseColor('ann-$i'),
      };
      expect(seen.length, inInclusiveRange(4, 6));
    });

    test('ne puise que dans les teintes de la charte', () {
      final seen = <Color>{
        for (var i = 0; i < 200; i++) statusBaseColor('ann-$i'),
      };
      expect(
        seen,
        everyElement(isIn(<Color>[
          AppColors.primary,
          AppColors.secondary,
          AppColors.accent,
          AppColors.gradientPrimary.colors.last,
          AppColors.gradientAppDark.colors.first,
        ])),
      );
    });

    test('accepte un id vide sans lever', () {
      expect(statusBaseColor(''), isA<Color>());
    });
  });

  group('statusGradient', () {
    test('n\'est jamais un aplat et conserve la teinte de base', () {
      final gradient = statusGradient(AppColors.primary);
      expect(gradient.colors.length, greaterThanOrEqualTo(2));
      expect(gradient.colors, contains(AppColors.primary));
      expect(gradient.colors.toSet().length, greaterThan(1));
    });

    test('éclaircit le haut et assombrit le bas', () {
      final gradient = statusGradient(AppColors.primary);
      final first = gradient.colors.first.computeLuminance();
      final last = gradient.colors.last.computeLuminance();
      expect(first, greaterThan(last));
    });

    test('supporte les extrêmes (noir et blanc) sans déborder', () {
      for (final base in const [Colors.black, Colors.white]) {
        final gradient = statusGradient(base);
        expect(gradient.colors.length, greaterThanOrEqualTo(2));
        for (final color in gradient.colors) {
          expect(color.computeLuminance(), inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('statusForegroundOn', () {
    test('couleur très claire ⇒ texte sombre', () {
      expect(statusForegroundOn(Colors.white), AppColors.textPrimary);
      // Le cas qui motive tout le §8 : un jaune pâle envoyé par le back.
      expect(
          statusForegroundOn(const Color(0xFFF8D05E)), AppColors.textPrimary);
      expect(statusForegroundOn(AppColors.accent), AppColors.textPrimary);
    });

    test('couleur très foncée ⇒ texte clair', () {
      expect(statusForegroundOn(Colors.black), AppColors.textOnPrimary);
      expect(statusForegroundOn(AppColors.primary), AppColors.textOnPrimary);
      expect(
        statusForegroundOn(AppColors.gradientAppDark.colors.first),
        AppColors.textOnPrimary,
      );
    });

    test('chaque teinte de repli obtient un contraste ≥ 4.5:1', () {
      final tints = <Color>{
        for (var i = 0; i < 200; i++) statusBaseColor('ann-$i'),
      };
      for (final base in tints) {
        final ratio = _contrast(base, statusForegroundOn(base));
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'contraste insuffisant sur $base',
        );
      }
    });

    test('ne renvoie que les deux encres de la charte', () {
      for (var i = 0; i < 64; i++) {
        final base = Color(0xFF000000 | (i * 0x040404));
        expect(
          statusForegroundOn(base),
          anyOf(AppColors.textPrimary, AppColors.textOnPrimary),
        );
      }
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
