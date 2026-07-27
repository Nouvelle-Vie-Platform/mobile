import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/theme/app_spacing.dart';
import 'package:maison_du_miracle/widgets/auth/otp_field.dart';

import '../helpers/pump_screen.dart';

/// Monte un [OtpField] à six cases, isolé dans un `Scaffold`.
Future<void> _pumpOtp(
  WidgetTester tester, {
  required ValueChanged<String> onCompleted,
}) {
  return pumpScreen(
    tester,
    Scaffold(
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: OtpField(length: 6, onCompleted: onCompleted),
      ),
    ),
  );
}

void main() {
  group('OtpField à six cases', () {
    testWidgets('validation automatique à la 6e case, pas avant',
        (tester) async {
      String? completed;
      await _pumpOtp(tester, onCompleted: (code) => completed = code);

      final boxes = find.byType(TextField);
      expect(boxes, findsNWidgets(6));

      for (var i = 0; i < 6; i++) {
        await tester.enterText(boxes.at(i), '${i + 1}');
        await tester.pump();
        if (i < 5) {
          expect(completed, isNull, reason: 'validé avant la 6e case');
        }
      }
      expect(completed, '123456');
    });

    testWidgets('un code collé remplit les six cases et valide',
        (tester) async {
      String? completed;
      await _pumpOtp(tester, onCompleted: (code) => completed = code);

      // Collage : la saisie arrive d'un coup dans la case focalisée.
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();

      expect(completed, '123456');
      for (var i = 1; i <= 6; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('tient sur un écran étroit sans débordement', (tester) async {
      // 320 pt de large : le plus petit écran encore visé (iPhone SE 1re gén.).
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpOtp(tester, onCompleted: (_) {});

      expect(tester.takeException(), isNull);
      final boxWidth =
          tester.getSize(find.byType(AnimatedContainer).first).width;
      // Six cases + cinq écarts doivent tenir dans la largeur utile
      // (320 - 2 × marge d'écran), en restant lisibles.
      const usable = 320 - AppSpacing.lg * 2;
      expect(boxWidth * 6 + AppSpacing.sm * 5, lessThanOrEqualTo(usable));
      expect(boxWidth, greaterThanOrEqualTo(32));
    });
  });
}
