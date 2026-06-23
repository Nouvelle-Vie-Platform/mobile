import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/screens/login_screen.dart';

Future<void> _pumpInLocale(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('Internationalisation', () {
    testWidgets('Français : libellés en français', (tester) async {
      await _pumpInLocale(tester, const Locale('fr'));
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('Anglais : libellés traduits', (tester) async {
      await _pumpInLocale(tester, const Locale('en'));
      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Se connecter'), findsNothing);
    });

    testWidgets('Éwé : traduit si dispo, sinon repli français', (tester) async {
      await _pumpInLocale(tester, const Locale('ee'));
      // actionLogin est traduit en éwé.
      expect(find.text('Ge ɖe eme'), findsOneWidget);
      // loginTitle n'est PAS traduit en éwé → repli sur le français.
      expect(find.text('Heureux de vous revoir !'), findsOneWidget);
    });
  });
}
