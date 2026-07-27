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
      // Le bouton est composé de deux couches superposées (état normal +
      // état rempli) pour l'animation de remplissage : le libellé apparaît
      // donc deux fois dans l'arbre.
      expect(find.text('Commencer'), findsWidgets);
    });

    testWidgets('IdentifierScreen se monte sur le canal email', (tester) async {
      await pumpScreen(tester, const IdentifierScreen());
      expect(find.byType(IdentifierScreen), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      // Email par défaut : c'est le champ email (et non le sélecteur
      // d'indicatif du champ téléphone) qui est affiché.
      expect(find.text('jean.kossi@email.com'), findsOneWidget);
      expect(find.text('90 12 34 56'), findsNothing);
    });

    testWidgets('IdentifierScreen n\'expose plus Google ni Apple',
        (tester) async {
      await pumpScreen(tester, const IdentifierScreen());
      // Ces boutons appelaient `signInWithGoogle` / `signInWithApple`, qui
      // lèvent `UnimplementedError` : non rattrapée (ce n'est pas une
      // `AuthException`), elle ferait planter l'app au tap.
      expect(find.text('Google'), findsNothing);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Ou continuer avec'), findsNothing);
    });

    testWidgets('ProfileFormScreen se monte', (tester) async {
      await pumpScreen(tester, const ProfileFormScreen());
      expect(find.byType(ProfileFormScreen), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });
  });
}
