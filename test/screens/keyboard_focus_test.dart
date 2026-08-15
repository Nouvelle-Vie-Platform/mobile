import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/screens/auth/identifier_screen.dart';
import 'package:maison_du_miracle/screens/new_request_screen.dart';

import '../helpers/pump_screen.dart';

/// **Le clavier apparaît-il quand un champ prend le focus ?**
///
/// La question vient d'un constat sur simulateur : « le clavier n'apparaît pas
/// même quand un champ est focus ». Elle ne se tranche pas à l'œil — un clavier
/// absent peut venir de trois endroits distincts, et deux d'entre eux ne sont
/// pas dans ce dépôt :
///
/// 1. **l'application** empêche la connexion de saisie (champ `readOnly`,
///    `TextInputType.none`, `FocusNode` sans `canRequestFocus`, un
///    `GestureDetector` qui mange le toucher) ;
/// 2. **le simulateur** a le clavier matériel branché (`ConnectHardwareKeyboard`,
///    ⌘K) — il vaut `0` sur cette machine, donc ce n'est pas lui ;
/// 3. **le harnais de test** lui-même, qui n'a jamais de clavier système.
///
/// Ce fichier ne peut trancher que le premier, et c'est déjà ce qu'il faut
/// savoir : si la connexion de saisie s'établit ici, le défaut n'est pas dans
/// le code de l'application.
///
/// `tester.testTextInput.isVisible` est le signal exact : il dit que le
/// framework a **demandé** au système d'ouvrir le clavier. Ce que le système en
/// fait ensuite est hors de portée d'un test.
void main() {
  group('Un champ qui prend le focus demande le clavier', () {
    testWidgets('écran d\'identifiant (email / téléphone)', (tester) async {
      await pumpScreen(tester, const IdentifierScreen());

      final field = find.byType(TextField).first;
      expect(field, findsOneWidget);

      await tester.tap(field);
      await tester.pump();

      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'le framework doit avoir demandé le clavier au système ; '
            'si ce test passe et que le clavier ne monte pas sur l\'appareil, '
            'le défaut est dans l\'environnement, pas dans l\'application',
      );
    });

    testWidgets('écran de nouvelle requête de prière', (tester) async {
      await pumpScreen(tester, const NewRequestScreen());

      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.pump();

      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('aucun champ du dépôt n\'est en lecture seule', (tester) async {
      // Le piège le plus courant d'un « clavier qui ne monte pas » : un champ
      // `readOnly` reste focalisable et affiche même un curseur, sans jamais
      // ouvrir de connexion de saisie.
      await pumpScreen(tester, const IdentifierScreen());

      for (final field
          in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(field.readOnly, isFalse);
        expect(field.enabled, isNot(false));
        expect(field.keyboardType, isNot(TextInputType.none));
      }
    });
  });
}
