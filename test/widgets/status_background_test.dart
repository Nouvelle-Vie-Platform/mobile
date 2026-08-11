import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/announcement_view.dart';
import 'package:maison_du_miracle/theme/app_colors.dart';
import 'package:maison_du_miracle/theme/status_palette.dart';
import 'package:maison_du_miracle/widgets/status/status_background.dart';

const _imageUrl = 'https://example.invalid/statut.jpg';

/// Un fond **servi** : trois arrêts dérivés par le serveur et une encre claire.
const _servedBackdrop = StatusBackdrop(
  baseColor: 0xFF3355AA,
  topColor: 0xFF5474E6,
  bottomColor: 0xFF26409B,
  ink: StatusInk.light,
);

/// Un fond clair, dont le serveur a décidé qu'il portait une encre sombre.
const _paleBackdrop = StatusBackdrop(
  baseColor: 0xFFF8D05E,
  topColor: 0xFFFBE08F,
  bottomColor: 0xFFD6A92F,
  ink: StatusInk.dark,
);

Future<void> _pump(WidgetTester tester, Widget background) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: background)));
  await tester.pumpAndSettle();
}

void main() {
  group('StatusBackground — montage', () {
    testWidgets('ni couleur ni image : repli déterministe sur le dégradé', (
      tester,
    ) async {
      await _pump(
        tester,
        const StatusBackground(id: 'ann-1', child: Text('Bonjour')),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      final gradient = _firstGradient(tester);
      expect(gradient.colors, contains(statusBaseColor('ann-1')));
    });

    testWidgets('fond servi : les trois arrêts partent tels quels', (
      tester,
    ) async {
      // Le serveur a dérivé la variation à l'écriture (ADR-0030) : le widget
      // peint ce qu'on lui donne, il ne recalcule rien. C'est ce qui garantit
      // qu'une même annonce a le même fond sur deux versions de l'application.
      await _pump(
        tester,
        const StatusBackground(
          id: 'ann-2',
          backdrop: _servedBackdrop,
          child: SizedBox.shrink(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(_firstGradient(tester).colors, const [
        Color(0xFF5474E6),
        Color(0xFF3355AA),
        Color(0xFF26409B),
      ]);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('fond servi : aucune teinte de repli ne s\'y glisse', (
      tester,
    ) async {
      await _pump(
        tester,
        const StatusBackground(
          id: 'ann-2',
          backdrop: _servedBackdrop,
          child: SizedBox.shrink(),
        ),
      );

      expect(
        _firstGradient(tester).colors,
        isNot(contains(statusBaseColor('ann-2'))),
      );
    });

    testWidgets('image seule : l\'Image.network est bien montée', (
      tester,
    ) async {
      await _pump(
        tester,
        const StatusBackground(
          id: 'ann-3',
          imageUrl: _imageUrl,
          child: SizedBox.shrink(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('fond servi et image ensemble', (tester) async {
      await _pump(
        tester,
        const StatusBackground(
          id: 'ann-4',
          backdrop: _servedBackdrop,
          imageUrl: _imageUrl,
          child: Text('Contenu'),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Contenu'), findsOneWidget);
      expect(
        _firstGradient(tester).colors,
        contains(const Color(0xFF3355AA)),
      );
    });

    testWidgets('sans voile, le fond reste peint', (tester) async {
      await _pump(
        tester,
        const StatusBackground(
          id: 'ann-5',
          scrim: false,
          child: SizedBox.shrink(),
        ),
      );

      expect(tester.takeException(), isNull);
      // Un seul DecoratedBox à dégradé : le fond, sans le voile.
      expect(_gradients(tester).length, 1);
    });

    testWidgets('le voile est peint par défaut', (tester) async {
      await _pump(
        tester,
        const StatusBackground(id: 'ann-5', child: SizedBox.shrink()),
      );

      expect(_gradients(tester).length, 2);
    });
  });

  group('StatusBackground — repli image', () {
    // Le test qui compte le plus : sous `flutter test` le réseau renvoie 400,
    // donc le chemin `errorBuilder` s'exécute réellement ici.
    testWidgets('l\'échec réseau retombe sur le dégradé sans lever', (
      tester,
    ) async {
      await _pump(
        tester,
        const StatusBackground(
          id: 'ann-6',
          imageUrl: _imageUrl,
          child: Text('Toujours là'),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(StatusBackground.imageErrorKey),
        findsOneWidget,
        reason: 'le errorBuilder doit avoir été appelé',
      );
      // Le dégradé de repli est toujours peint, et le contenu reste visible.
      expect(_gradients(tester), isNotEmpty);
      expect(find.text('Toujours là'), findsOneWidget);
    });

    testWidgets('pumpAndSettle se termine malgré le fondu', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBackground(
              id: 'ann-7',
              imageUrl: _imageUrl,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Ne doit pas expirer : le fondu est borné.
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    });
  });

  group('StatusBackground.foregroundFor', () {
    test('l\'encre vient du serveur quand un fond est servi', () {
      // **Le contraste a été tranché à l'écriture** (ADR-0030). Le déduire ici
      // de la luminance serait refaire un calcul déjà fait — et le refaire
      // différemment un jour, sur un fond pâle, sans que personne le voie
      // avant les utilisateurs.
      expect(
        StatusBackground.foregroundFor('ann-1', backdrop: _servedBackdrop),
        AppColors.textOnPrimary,
      );
      expect(
        StatusBackground.foregroundFor('ann-1', backdrop: _paleBackdrop),
        AppColors.textPrimary,
      );
    });

    test('l\'encre servie prime sur ce que la luminance suggérerait', () {
      // Un fond très clair déclaré `ink: light` : incohérent, mais c'est la
      // décision du serveur, et le client ne la corrige pas en silence.
      const contrarian = StatusBackdrop(
        baseColor: 0xFFFFFFFF,
        topColor: 0xFFFFFFFF,
        bottomColor: 0xFFFFFFFF,
        ink: StatusInk.light,
      );
      expect(
        StatusBackground.foregroundFor('ann-1', backdrop: contrarian),
        AppColors.textOnPrimary,
      );
    });

    test('sans fond servi, la luminance du repli tranche', () {
      expect(
        StatusBackground.foregroundFor('ann-1'),
        statusForegroundOn(statusBaseColor('ann-1')),
      );
    });

    test('avec une image, le texte est toujours clair', () {
      expect(
        StatusBackground.foregroundFor(
          'ann-1',
          backdrop: _paleBackdrop, // fond pâle… mais couvert par l'image
          imageUrl: _imageUrl,
        ),
        AppColors.textOnPrimary,
      );
      expect(
        StatusBackground.foregroundFor('ann-1', imageUrl: _imageUrl),
        AppColors.textOnPrimary,
      );
    });

    group('teinte du voile', () {
      // Le voile suit le texte : posé en noir sous un texte sombre (fond
      // clair), il détruirait le contraste qu'il est censé garantir.
      test('texte clair ⇒ voile sombre', () {
        final gradient = StatusBackground.scrimGradient(Colors.white);
        expect(gradient.colors.last.r, lessThan(0.1));
        expect(gradient.colors.last.g, lessThan(0.1));
        expect(gradient.colors.last.b, lessThan(0.1));
      });

      test('texte sombre ⇒ voile clair', () {
        final gradient = StatusBackground.scrimGradient(Colors.black);
        expect(gradient.colors.last.r, greaterThan(0.9));
        expect(gradient.colors.last.g, greaterThan(0.9));
        expect(gradient.colors.last.b, greaterThan(0.9));
      });
    });
  });
}

List<Gradient> _gradients(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(StatusBackground),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .map((decoration) => decoration.gradient)
    .whereType<Gradient>()
    .toList();

Gradient _firstGradient(WidgetTester tester) => _gradients(tester).first;
