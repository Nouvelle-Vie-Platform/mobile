import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/screens/auth/identifier_screen.dart';
import 'package:maison_du_miracle/screens/auth/profile_form_screen.dart';
import 'package:maison_du_miracle/screens/auth/welcome_screen.dart';
import 'package:maison_du_miracle/screens/splash_screen.dart';

import '../helpers/pump_screen.dart';

void main() {
  group('Écrans d\'authentification (smoke)', () {
    testWidgets('SplashScreen se monte et affiche le nom', (tester) async {
      await pumpScreen(tester, const SplashScreen());
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Maison du Miracle'), findsWidgets);
    });

    testWidgets('WelcomeScreen se monte', (tester) async {
      await pumpScreen(tester, const WelcomeScreen());
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('IdentifierScreen se monte', (tester) async {
      await pumpScreen(tester, const IdentifierScreen());
      expect(find.byType(IdentifierScreen), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('ProfileFormScreen se monte', (tester) async {
      await pumpScreen(tester, const ProfileFormScreen());
      expect(find.byType(ProfileFormScreen), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });
  });
}
