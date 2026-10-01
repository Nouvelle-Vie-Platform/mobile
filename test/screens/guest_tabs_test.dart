/// **Les onglets réservés, qu'une garde de route ne peut pas fermer.**
///
/// Les quatre onglets vivent dans un `IndexedStack` : ce ne sont pas des routes,
/// et `memberOnlyRoutes` n'a aucune prise sur eux. La décision du client met
/// pourtant la communauté derrière la connexion, et le profil n'a aucun sens
/// sans compte. La fermeture est donc dans la coquille, et c'est ici qu'elle se
/// vérifie.
///
/// **Deux onglets gardés, et c'est le point le plus silencieux du chantier** :
/// le profil a quitté la barre du bas en septembre pour devenir une route, ce
/// qui le faisait protéger par `memberOnlyRoutes` ; en redevenant un onglet, il
/// perd cette protection. Une garde posée sur le mauvais onglet, ou oubliée, ne
/// lève rien : elle ouvre simplement l'écran de profil à un invité — et le
/// magasin local survit à la déconnexion, donc il y verrait des choses.
///
/// La forme retenue — l'onglet **reste** et son appui ouvre la connexion — est
/// justifiée dans l'en-tête de `HomeShell`. Ces tests verrouillent les deux
/// moitiés de ce choix : un invité n'entre pas dans les onglets réservés, et
/// **rien ne change pour un membre**.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/screens/auth/welcome_screen.dart';
import 'package:maison_du_miracle/screens/bible_screen.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/state/session_gate.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/widgets/home_tab.dart';

import '../helpers/guest_app.dart';

/// Les libellés attendus, **lus dans les traductions** et non recopiés : un test
/// qui recopie la chaîne ne saurait pas dire si la clé est branchée.
final _fr = AppLocalizationsFr();

void main() {
  group('La barre du bas', () {
    testWidgets('porte les quatre onglets, traduits, dans l\'ordre',
        (tester) async {
      await pumpGuestApp(tester, guestContainer());

      expect(navTab(_fr.navHome), findsOneWidget);
      expect(navTab(_fr.navAnnouncements), findsOneWidget);
      expect(navTab(_fr.navGroups), findsOneWidget);
      // **Profil a repris sa place**, et porte le même libellé pour tout le
      // monde : la connexion se demande au geste, jamais par un libellé qui
      // change selon l'état.
      expect(navTab(_fr.navProfile), findsOneWidget);

      // Et la Bible a quitté la barre : elle vit en haut à droite de l'accueil.
      expect(navTab(_fr.navBible), findsNothing);

      // L'ordre, lu de gauche à droite sur ce qui est réellement peint.
      final xs = [
        for (final label in [
          _fr.navHome,
          _fr.navAnnouncements,
          _fr.navGroups,
          _fr.navProfile,
        ])
          tester.getCenter(navTab(label)).dx,
      ];
      expect(xs, orderedEquals(<double>[...xs]..sort()),
          reason: 'Accueil · Annonces · ⊕ · Échanges · Profil');
    });
  });

  group('Un invité et les onglets réservés', () {
    testWidgets('Échanges : l\'appui ouvre la connexion et n\'entre pas',
        (tester) async {
      final router = await pumpGuestApp(tester, guestContainer());
      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), HomeTab.home);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      // **Pas un bouton mort, pas un écran vide** : le parcours de connexion est
      // poussé par-dessus la coquille, et renoncer n'est qu'un retour en arrière.
      expect(router.state.matchedLocation, '/auth');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      // Et l'onglet n'a pas bougé sous le parcours : la coquille attend.
      expect(shellTab(tester), HomeTab.home);
    });

    testWidgets('Profil : l\'appui ouvre la connexion et n\'entre pas',
        (tester) async {
      // **Le cas que le chantier crée.** Le profil était protégé par la garde du
      // routeur tant qu'il était une route ; redevenu onglet, il ne l'est plus,
      // et seule la garde au geste le ferme.
      final router = await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navProfile));
      await settle(tester);

      expect(router.state.matchedLocation, '/auth');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(shellTab(tester), HomeTab.home);
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
      expect(shellTab(tester), HomeTab.community);
    });

    testWidgets('la connexion aboutit : le profil s\'ouvre de lui-même',
        (tester) async {
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);

      await tester.tap(navTab(_fr.navProfile));
      await settle(tester);

      await signIn(container);
      await settle(tester);

      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), HomeTab.profile);
      expect(shellScreen(tester), isA<ProfileScreen>());
      // L'intention a été consommée : elle ne se rejouera pas à la connexion
      // suivante, faite pour une autre raison.
      expect(container.read(sessionGateProvider), isNull);
    });

    testWidgets('il renonce : ni hub, ni geste en attente', (tester) async {
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);
      router.pop();
      await settle(tester);

      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), HomeTab.home);

      // Et le geste ne ressuscite pas à la connexion suivante, faite pour une
      // autre raison : c'est le cas qui rendrait le mécanisme effrayant.
      await signIn(container);
      await settle(tester);
      expect(shellTab(tester), HomeTab.home);
    });

    testWidgets('les onglets ouverts restent immédiats', (tester) async {
      // Le risque de la forme retenue est d'avoir posé la garde sur le mauvais
      // onglet, ou sur tous : un invité qui ne pourrait plus ouvrir les annonces
      // serait une régression que personne ne signalerait.
      await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navAnnouncements));
      await tester.pump();
      expect(shellTab(tester), HomeTab.announcements);

      await tester.tap(navTab(_fr.navHome));
      await tester.pump();
      expect(shellTab(tester), HomeTab.home);
    });
  });

  group('Un membre — rien ne change', () {
    testWidgets('les quatre onglets, et les réservés au premier appui',
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
      expect(navTab(_fr.navProfile), findsOneWidget);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      // **Transparent** : aucune connexion poussée, aucun détour, l'onglet
      // change au premier appui. C'est la contrainte du client — « quand la
      // personne s'est déjà connectée, tout se passe exactement comme
      // présentement ».
      expect(shellTab(tester), HomeTab.community);
      expect(router.state.matchedLocation, '/home');
      expect(find.byType(WelcomeScreen), findsNothing);

      await tester.tap(navTab(_fr.navProfile));
      await settle(tester);

      expect(shellTab(tester), HomeTab.profile);
      expect(shellScreen(tester), isA<ProfileScreen>());
      expect(router.state.matchedLocation, '/home');
      expect(find.byType(WelcomeScreen), findsNothing);
    });
  });

  group('L\'en-tête de l\'accueil', () {
    testWidgets('l\'icône Profil a disparu, la Bible a pris sa place',
        (tester) async {
      final router = await pumpGuestApp(tester, guestContainer());

      // Le profil est redescendu dans la barre ; l'en-tête ne porte plus son
      // icône, et donc plus aucun geste réservé. On vise son **infobulle** :
      // la clé, elle, a disparu du code — c'est le compilateur qui l'atteste.
      expect(find.byTooltip(_fr.navProfile), findsNothing);
      expect(find.byKey(HomeScreen.menuButtonKey), findsOneWidget);
      expect(find.byKey(HomeScreen.bibleButtonKey), findsOneWidget);

      await tester.tap(find.byKey(HomeScreen.bibleButtonKey));
      await settle(tester);

      // **Poussée, et ouverte à tous** : un invité l'ouvre sans qu'on lui
      // demande rien, et la coquille attend dessous.
      expect(router.state.matchedLocation, '/bible');
      expect(find.byType(BibleScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(shellTab(tester), HomeTab.home);
    });
  });
}
