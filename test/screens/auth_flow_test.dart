import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/screens/login_screen.dart';
import 'package:maison_du_miracle/screens/onboarding_screen.dart';
import 'package:maison_du_miracle/screens/register_screen.dart';
import 'package:maison_du_miracle/screens/splash_screen.dart';

import '../helpers/pump_screen.dart';

void main() {
  group('Écrans d\'authentification (smoke)', () {
    testWidgets('SplashScreen se monte et affiche le nom', (tester) async {
      await pumpScreen(tester, const SplashScreen());
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Maison du Miracle'), findsWidgets);
    });

    testWidgets('OnboardingScreen se monte', (tester) async {
      await pumpScreen(tester, const OnboardingScreen());
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
    });

    testWidgets('LoginScreen se monte', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('RegisterScreen se monte', (tester) async {
      await pumpScreen(tester, const RegisterScreen());
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Créer votre compte'), findsOneWidget);
    });
  });
}
