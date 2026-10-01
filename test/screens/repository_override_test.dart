/// **Le hub « Échanges » affiche ce que son repository lui donne**, et rien
/// d'autre.
///
/// ⚠️ Ce fichier testait l'injection d'un `ChurchRepository` fictif (#96 l'a vidé
/// de ses groupes, de ses conversations et de son fil). Ce qu'il vérifie n'a pas
/// changé — que l'écran lit bien sa source et non une fixture en dur —, mais la
/// source a changé : c'est `EchangesRepository`, et il se pose par le **paramètre
/// nommé** `echanges:` de `pumpScreen`, Riverpod 3 refusant deux surcharges du même
/// provider.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';

import '../helpers/pump_screen.dart';

void main() {
  testWidgets(
    'GroupsScreen affiche les conversations du repository injecté',
    (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        echanges: InMemoryEchangesRepository(
          conversations: const [
            ConversationView(
              groupId: 'g-test',
              title: 'Groupe de Test',
              isDirect: false,
              memberCount: 4,
              canWrite: true,
              lastMessagePreview: 'Bonjour',
            ),
          ],
        ),
      );

      // La donnée provient du repository injecté.
      expect(find.text('Groupe de Test'), findsOneWidget);
      expect(find.text('Bonjour'), findsOneWidget);
      // Et plus aucune fixture ne traîne : « Jeunesse Nouvelle Vie » était l'un des
      // quatre groupes que `SampleData` servait **en production**, sans condition.
      expect(find.textContaining('Jeunesse Nouvelle Vie'), findsNothing);
    },
  );

  testWidgets(
    'un magasin vide se dit, et n\'est pas une erreur',
    (tester) async {
      // L'état **le plus fréquent au premier lancement** : la synchronisation n'a
      // pas encore ramené mes groupes. C'est une absence, et l'écran doit nommer le
      // geste de rattrapage — le réveil push est de la tranche 2.
      await pumpScreen(tester, const Scaffold(body: GroupsScreen()));

      expect(find.text('Aucune conversation'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
