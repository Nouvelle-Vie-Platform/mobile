/// **L'onglet Communauté, qu'une garde de route ne peut pas fermer.**
///
/// Les quatre onglets vivent dans un `IndexedStack` : ce ne sont pas des routes,
/// et `memberOnlyRoutes` n'a aucune prise sur eux. La décision du client met
/// pourtant la communauté derrière la connexion. La fermeture est donc dans la
/// coquille, et c'est ici qu'elle se vérifie.
///
/// La forme retenue — l'onglet **reste** et son appui ouvre la connexion — est
/// justifiée dans l'en-tête de `HomeShell`. Ces tests verrouillent les deux
/// moitiés de ce choix : un invité n'entre pas dans le hub, et **rien ne change
/// pour un membre**.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/screens/auth/welcome_screen.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';

import '../helpers/guest_app.dart';

/// Les libellés attendus, **lus dans les traductions** et non recopiés : les
/// deux derniers étaient écrits en dur dans la barre, et un test qui recopie la
/// chaîne ne saurait pas dire si la clé est branchée.
final _fr = AppLocalizationsFr();

void main() {
  group('Un invité et l\'onglet Communauté', () {
    testWidgets('la barre porte les quatre onglets, traduits', (tester) async {
      await pumpGuestApp(tester, guestContainer());

      expect(navTab(_fr.navHome), findsOneWidget);
      expect(navTab(_fr.navAnnouncements), findsOneWidget);
      // Les deux qui étaient en dur. Ce n'est pas un test de cosmétique : écrits
      // en littéral, ils ne se traduisaient ni en anglais ni en éwé alors que
      // les clés existaient depuis toujours.
      expect(navTab(_fr.navGroups), findsOneWidget);
      expect(navTab(_fr.navBible), findsOneWidget);
    });

    testWidgets('l\'appui ouvre la connexion et n\'entre pas dans le hub',
        (tester) async {
      final router = await pumpGuestApp(tester, guestContainer());
      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), 0);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      // **Pas un bouton mort, pas un écran vide** : le parcours de connexion est
      // poussé par-dessus la coquille, et renoncer n'est qu'un retour en arrière.
      expect(router.state.matchedLocation, '/auth');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      // Et l'onglet n'a pas bougé sous le parcours : la coquille attend.
      expect(shellTab(tester), 0);
    });

    testWidgets('la connexion aboutit : le hub s\'ouvre de lui-même',
        (tester) async {
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);
      expect(router.state.matchedLocation, '/auth');

      await signIn(container);
      await settle(tester);

      // Le geste est **rejoué** — c'est tout l'intérêt de `requireSession()`.
      // Sans cette reprise, la personne aurait donné son identifiant, reçu un
      // code, et retrouverait l'accueil sans le hub qu'elle demandait.
      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), 2);
    });

    testWidgets('il renonce : ni hub, ni geste en attente', (tester) async {
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);
      router.pop();
      await settle(tester);

      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), 0);

      // Et le geste ne ressuscite pas à la connexion suivante, faite pour une
      // autre raison : c'est le cas qui rendrait le mécanisme effrayant.
      await signIn(container);
      await settle(tester);
      expect(shellTab(tester), 0);
    });
  });

  group('Un membre — rien ne change', () {
    testWidgets('les quatre onglets, et le hub s\'ouvre au premier appui',
        (tester) async {
      final container = guestContainer(
        auth: GuestAuthRepository(signedIn: true),
        vault: StartupVault.memberSession,
      );
      final router = await pumpGuestApp(tester, container);
      await untilSignedIn(tester, container);

      expect(navTab(_fr.navHome), findsOneWidget);
      expect(navTab(_fr.navAnnouncements), findsOneWidget);
      expect(navTab(_fr.navGroups), findsOneWidget);
      expect(navTab(_fr.navBible), findsOneWidget);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      // **Transparent** : aucune connexion poussée, aucun détour, l'onglet
      // change au premier appui. C'est la contrainte du client — « quand la
      // personne s'est déjà connectée, tout se passe exactement comme
      // présentement ».
      expect(shellTab(tester), 2);
      expect(router.state.matchedLocation, '/home');
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('les trois autres onglets restent immédiats, pour tous',
        (tester) async {
      // Le risque de la forme retenue est d'avoir posé la garde sur le mauvais
      // index, ou sur tous : un invité qui ne pourrait plus ouvrir les annonces
      // ni la Bible serait une régression que personne ne signalerait.
      await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navAnnouncements));
      await tester.pump();
      expect(shellTab(tester), 1);

      await tester.tap(navTab(_fr.navBible));
      await tester.pump();
      expect(shellTab(tester), 3);

      await tester.tap(navTab(_fr.navHome));
      await tester.pump();
      expect(shellTab(tester), 0);
    });
  });
}
