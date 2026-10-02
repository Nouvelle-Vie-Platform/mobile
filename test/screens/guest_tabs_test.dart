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
/// La forme retenue — l'onglet **reste sélectionnable**, et son contenu devient
/// le formulaire de connexion — est justifiée dans l'en-tête de `HomeShell`. Ces
/// tests verrouillent les deux moitiés de ce choix : un invité n'entre pas dans
/// les onglets réservés, et **rien ne change pour un membre**.
///
/// ⚠️ **Ce que ces tests ne couvrent pas** : l'absence de cul-de-sac et la
/// phrase qui dit pourquoi, qui vivent dans
/// `test/screens/guest_sign_in_tab_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/screens/announcements_screen.dart';
import 'package:maison_du_miracle/screens/auth/identifier_screen.dart';
import 'package:maison_du_miracle/screens/auth/sign_in_tab.dart';
import 'package:maison_du_miracle/screens/bible_screen.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/widgets/home_tab.dart';
import 'package:maison_du_miracle/widgets/legal_notice_banner.dart';

import '../helpers/guest_app.dart';

/// Les libellés attendus, **lus dans les traductions** et non recopiés : un test
/// qui recopie la chaîne ne saurait pas dire si la clé est branchée.
final _fr = AppLocalizationsFr();

void main() {
  testWidgets('le bandeau légal se replie sans débordement sur petit écran',
      (tester) async {
    tester.view.physicalSize = const Size(750, 1600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpGuestApp(
      tester,
      guestContainer(legalNotice: InMemoryLegalNoticeStore(seen: false)),
    );

    expect(find.byKey(LegalNoticeBanner.termsKey), findsOneWidget);
    expect(find.byKey(LegalNoticeBanner.privacyKey), findsOneWidget);
    expect(find.byKey(LegalNoticeBanner.dismissKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    testWidgets('Échanges : l\'onglet s\'ouvre sur le formulaire',
        (tester) async {
      final router = await pumpGuestApp(tester, guestContainer());
      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), HomeTab.home);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      // **Rien n'est poussé, et c'est tout le correctif.** La connexion
      // s'affichait jusqu'ici plein écran par-dessus la coquille (`/auth`), sur
      // un écran de bienvenue sans aucune flèche de retour : sur iPhone, qui n'a
      // pas de bouton système, la personne était enfermée.
      expect(router.state.matchedLocation, '/home');
      // L'onglet demandé est bien **l'onglet courant** — il n'est plus refusé —,
      // et c'est le formulaire qui y paraît à la place du hub.
      expect(shellTab(tester), HomeTab.community);
      expect(shellScreen(tester), isA<SignInTab>());
      expect(find.byType(GroupsScreen, skipOffstage: false), findsNothing);
    });

    testWidgets('Profil : l\'onglet s\'ouvre sur le formulaire',
        (tester) async {
      // **Le cas que le chantier crée.** Le profil était protégé par la garde du
      // routeur tant qu'il était une route ; redevenu onglet, il ne l'est plus,
      // et c'est son contenu qui le ferme.
      final router = await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navProfile));
      await settle(tester);

      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), HomeTab.profile);
      expect(shellScreen(tester), isA<SignInTab>());
      expect(find.byType(ProfileScreen, skipOffstage: false), findsNothing);
    });

    testWidgets('la connexion aboutit : le hub prend la place du formulaire',
        (tester) async {
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);
      expect(shellScreen(tester), isA<SignInTab>());

      await signIn(container);
      await settle(tester);

      // **Personne n'y retouche** : la coquille lit l'état d'authentification et
      // rend l'écran de l'onglet. Il n'y a pas de geste à rejouer, donc pas
      // d'intention à mettre de côté — c'est ce que la forme précédente devait
      // faire, et c'est désormais gratuit.
      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), HomeTab.community);
      expect(shellScreen(tester), isA<GroupsScreen>());
      expect(find.byType(IdentifierForm, skipOffstage: false), findsNothing);
    });

    testWidgets('la connexion aboutit : le profil prend la place du formulaire',
        (tester) async {
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);

      await tester.tap(navTab(_fr.navProfile));
      await settle(tester);
      expect(shellScreen(tester), isA<SignInTab>());

      await signIn(container);
      await settle(tester);

      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), HomeTab.profile);
      expect(shellScreen(tester), isA<ProfileScreen>());
    });

    testWidgets('il renonce : un autre onglet, et rien n\'est resté en route',
        (tester) async {
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      // **La porte de sortie est la barre du bas**, et il n'y en a pas d'autre à
      // apprendre : on n'a jamais quitté la coquille.
      await tester.tap(navTab(_fr.navHome));
      await settle(tester);

      expect(router.state.matchedLocation, '/home');
      expect(shellTab(tester), HomeTab.home);
      expect(shellScreen(tester), isA<HomeScreen>());

      // Et une connexion faite plus tard, pour une autre raison, ne ramène
      // personne sur Échanges : aucun geste n'a été mis de côté.
      await signIn(container);
      await settle(tester);
      expect(shellTab(tester), HomeTab.home);
    });

    testWidgets('les onglets ouverts restent immédiats', (tester) async {
      // Le risque de la forme retenue est d'avoir posé la garde sur le mauvais
      // onglet, ou sur tous : un invité qui verrait un formulaire de connexion à
      // la place des annonces serait une régression que personne ne
      // signalerait.
      await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navAnnouncements));
      await tester.pump();
      expect(shellTab(tester), HomeTab.announcements);
      expect(shellScreen(tester), isA<AnnouncementsScreen>());

      await tester.tap(navTab(_fr.navHome));
      await tester.pump();
      expect(shellTab(tester), HomeTab.home);
      expect(shellScreen(tester), isA<HomeScreen>());
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

      // **Transparent** : aucun détour, aucun formulaire, l'onglet montre son
      // écran au premier appui. C'est la contrainte du client — « quand la
      // personne s'est déjà connectée, tout se passe exactement comme
      // présentement ».
      expect(shellTab(tester), HomeTab.community);
      expect(shellScreen(tester), isA<GroupsScreen>());
      expect(router.state.matchedLocation, '/home');
      expect(find.byType(IdentifierForm, skipOffstage: false), findsNothing);

      await tester.tap(navTab(_fr.navProfile));
      await settle(tester);

      expect(shellTab(tester), HomeTab.profile);
      expect(shellScreen(tester), isA<ProfileScreen>());
      expect(router.state.matchedLocation, '/home');
      expect(find.byType(IdentifierForm, skipOffstage: false), findsNothing);
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
      expect(find.byType(IdentifierScreen), findsNothing);
      expect(shellTab(tester), HomeTab.home);
    });
  });
}
