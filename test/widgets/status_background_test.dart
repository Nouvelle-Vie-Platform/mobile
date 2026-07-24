import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/theme/app_colors.dart';
import 'package:maison_du_miracle/theme/status_palette.dart';
import 'package:maison_du_miracle/widgets/status/status_background.dart';

const _imageUrl = 'https://example.invalid/statut.jpg';

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

    testWidgets('couleur seule : la couleur du back pilote le dégradé', (
      tester,
    ) async {
      const custom = 0xFF3355AA;
      await _pump(
        tester,
        const StatusBackground(
          id: 'ann-2',
          backgroundColor: custom,
          child: SizedBox.shrink(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(_firstGradient(tester).colors, contains(const Color(custom)));
      expect(find.byType(Image), findsNothing);
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

    testWidgets('couleur et image ensemble', (tester) async {
      await _pump(
        tester,
        const StatusBackground(
          id: 'ann-4',
          backgroundColor: 0xFF884422,
          imageUrl: _imageUrl,
          child: Text('Contenu'),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Contenu'), findsOneWidget);
      expect(_firstGradient(tester).colors, contains(const Color(0xFF884422)));
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
    test('sans image, délègue à la garantie de contraste', () {
      expect(
        StatusBackground.foregroundFor('ann-1', backgroundColor: 0xFFFFFFFF),
        AppColors.textPrimary,
      );
      expect(
        StatusBackground.foregroundFor('ann-1', backgroundColor: 0xFF000000),
        AppColors.textOnPrimary,
      );
      expect(
        StatusBackground.foregroundFor('ann-1'),
        statusForegroundOn(statusBaseColor('ann-1')),
      );
    });

    test('avec une image, le texte est toujours clair', () {
      expect(
        StatusBackground.foregroundFor(
          'ann-1',
          backgroundColor: 0xFFFFFFFF, // fond blanc… mais couvert par l'image
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
