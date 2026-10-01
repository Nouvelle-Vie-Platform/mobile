/// **Le sélecteur de canal disparaît quand il n'y a rien à choisir** (#83).
///
/// Ce fichier vérifie ce que l'écran *propose*, pas ce que le magasin contient :
/// l'offre y entre par le paramètre nommé `authChannels:` de `pumpScreen`
/// (Riverpod 3 refuse deux surcharges du même provider), et le flux est nu — un
/// flux Drift attendu sous l'horloge factice du harnais figerait le montage.
///
/// `pump()` puis `pump(1s)`, **jamais `pumpAndSettle`** : l'écran monte sous un
/// `authProvider` qui résout sa session par une minuterie.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/auth_channels.dart';
import 'package:maison_du_miracle/screens/auth/identifier_screen.dart';

import '../helpers/pump_screen.dart';

void main() {
  const bothOpen = AuthChannelOffer(emailOpen: true, phoneOpen: true);
  const phoneOnly = AuthChannelOffer(emailOpen: false, phoneOpen: true);

  /// Le sélecteur, **sous toutes ses formes** : un grisage reste un sélecteur.
  final selector = find.byWidgetPredicate((w) => w is SegmentedButton<bool>);

  group('Deux canaux ouverts : le sélecteur paraît', () {
    testWidgets('les deux segments sont là, l\'email reste présélectionné',
        (tester) async {
      await pumpScreen(
        tester,
        const IdentifierScreen(),
        authChannels: bothOpen,
      );

      expect(selector, findsOneWidget);
      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      // Email par défaut, comme avant cette tranche : c'est le canal qui envoie
      // réellement un code.
      expect(find.text('jean.kossi@email.com'), findsOneWidget);
      expect(find.text('90 12 34 56'), findsNothing);
    });

    testWidgets('le sous-titre du dépôt nomme bien les deux canaux',
        (tester) async {
      await pumpScreen(
        tester,
        const IdentifierScreen(),
        authChannels: bothOpen,
      );

      expect(
        find.text('Entrez votre numéro ou votre email pour continuer.'),
        findsOneWidget,
      );
    });

    testWidgets('choisir le téléphone donne le champ et le clavier du canal',
        (tester) async {
      await pumpScreen(
        tester,
        const IdentifierScreen(),
        authChannels: bothOpen,
      );

      await tester.tap(find.text('Téléphone'));
      await tester.pump();

      expect(find.text('90 12 34 56'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.phone);
    });
  });

  group('Un seul canal : il n\'y a rien à choisir', () {
    testWidgets('le sélecteur disparaît, et ce n\'est pas un grisage',
        (tester) async {
      await pumpScreen(
        tester,
        const IdentifierScreen(),
        authChannels: AuthChannelOffer.emailOnly,
      );

      // **On ne grise pas une option, on ne la propose pas** : ni sélecteur
      // désactivé, ni segment « Téléphone » quelque part dans l'arbre.
      expect(selector, findsNothing);
      expect(find.text('Téléphone'), findsNothing);
      expect(find.text('Email'), findsNothing);

      // Le champ du canal ouvert, et lui seul.
      expect(find.text('jean.kossi@email.com'), findsOneWidget);
      expect(find.text('90 12 34 56'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('le libellé du dépôt dit par où le code arrive',
        (tester) async {
      await pumpScreen(
        tester,
        const IdentifierScreen(),
        authChannels: AuthChannelOffer.emailOnly,
      );

      expect(
        find.text('Votre code de connexion vous sera envoyé par email.'),
        findsOneWidget,
      );
      // Le sous-titre du dépôt nommerait « votre numéro ou votre email », donc
      // un canal que l'écran ne propose pas : c'est l'annonce qui parle à sa
      // place.
      expect(
        find.text('Entrez votre numéro ou votre email pour continuer.'),
        findsNothing,
      );
    });

    testWidgets('le téléphone seul : son champ, son indicatif, son libellé',
        (tester) async {
      await pumpScreen(
        tester,
        const IdentifierScreen(),
        authChannels: phoneOnly,
      );

      expect(selector, findsNothing);
      expect(find.text('90 12 34 56'), findsOneWidget);
      expect(find.text('jean.kossi@email.com'), findsNothing);
      // L'indicatif précède le champ, comme en mode téléphone aujourd'hui. Sa
      // valeur suit le locale de l'appareil (repli +228) : on vérifie qu'il est
      // là, pas lequel il est.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').startsWith('+'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
            'Votre code de connexion vous sera envoyé sur votre téléphone.'),
        findsOneWidget,
      );
    });
  });

  group('L\'annonce du portail', () {
    testWidgets('elle remplace le libellé du dépôt', (tester) async {
      await pumpScreen(
        tester,
        const IdentifierScreen(),
        authChannels: const AuthChannelOffer(
          emailOpen: true,
          phoneOpen: false,
          notice: {
            'fr': 'La connexion par téléphone rouvrira bientôt.',
            'en': 'Phone sign-in will reopen soon.',
          },
        ),
      );

      expect(
        find.text('La connexion par téléphone rouvrira bientôt.'),
        findsOneWidget,
      );
      expect(
        find.text('Votre code de connexion vous sera envoyé par email.'),
        findsNothing,
      );
    });

    testWidgets('vide, elle retombe sur le `.arb`', (tester) async {
      // Une carte sans aucune langue remplie — ou remplie de blancs — veut dire
      // « garde le libellé du dépôt », jamais « affiche rien ». Un bandeau blanc
      // ne ressemble pas à un bug, il ressemble à une donnée perdue.
      await pumpScreen(
        tester,
        const IdentifierScreen(),
        authChannels: const AuthChannelOffer(
          emailOpen: true,
          phoneOpen: false,
          notice: {'fr': '   ', 'en': ''},
        ),
      );

      expect(
        find.text('Votre code de connexion vous sera envoyé par email.'),
        findsOneWidget,
      );
    });
  });

  group('Avant toute synchronisation', () {
    testWidgets('l\'écran propose l\'email, et rien d\'autre', (tester) async {
      // Aucun `authChannels:` : c'est le repli, et c'est le moment où quelqu'un
      // ouvre l'application pour la première fois. **Jamais « tous les
      // canaux »** — un repli permissif remettrait exactement le sélecteur
      // menteur que cette tranche retire.
      await pumpScreen(tester, const IdentifierScreen());

      expect(selector, findsNothing);
      expect(find.text('Téléphone'), findsNothing);
      expect(find.text('jean.kossi@email.com'), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
    });

    testWidgets('et aucun bouton social ne se réveille', (tester) async {
      // Hors périmètre par décision écrite (`docs/auth-contract.md`). Et
      // n'offrir que l'email ne déclenche pas la règle App Store 4.8 : c'est
      // *ajouter* Google qui *crée* l'obligation d'offrir « Sign in with Apple ».
      await pumpScreen(tester, const IdentifierScreen());

      expect(find.text('Ou continuer avec'), findsNothing);
      expect(find.text('Google'), findsNothing);
      expect(find.text('Apple'), findsNothing);
    });
  });
}
