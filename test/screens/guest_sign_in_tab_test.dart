/// **Le cul-de-sac de l'iPhone, et les trois choses qui le remplacent.**
///
/// Constaté sur un vrai téléphone : toucher « Échanges » ou « Profil » poussait
/// l'écran de bienvenue plein écran par-dessus la coquille. Cet écran n'avait
/// **ni `appBar`, ni `BackButton`, ni `pop`, ni `PopScope`** — sur Android le
/// bouton système dépilait, sur iPhone il n'y en a pas, et la personne était
/// enfermée. Et quand elle arrivait enfin au formulaire, celui-ci était atteint
/// par un `go`, qui remplace la pile : plus rien à dépiler, donc plus de flèche
/// non plus.
///
/// Trois exigences, et chacune a ici son test :
///
/// 1. **le geste mène au formulaire**, pas à une page de garde devant lui ;
/// 2. **le formulaire dit pourquoi on y est** — « pour accéder aux échanges », et
///    non une invitation passe-partout ;
/// 3. **on revient sur ses pas à chaque étape, sans bouton système.** Dans un
///    onglet, la sortie est la barre du bas ; sur le parcours poussé par
///    `requireSession()`, c'est une flèche de retour **dans l'écran**.
///
/// `pump()` + `pump(1s)`, **jamais `pumpAndSettle`** : l'accueil porte le bouton
/// de l'antenne, qui est animé en continu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/l10n/app_localizations.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/auth_channels.dart';
import 'package:maison_du_miracle/screens/auth/code_screen.dart';
import 'package:maison_du_miracle/screens/auth/identifier_screen.dart';
import 'package:maison_du_miracle/screens/auth/sign_in_tab.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/state/session_gate.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/widgets/home_tab.dart';

import '../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();

/// La flèche de retour **de l'écran**, et non le bouton du téléphone.
///
/// C'est la distinction que tout ce fichier défend : `tester.tap` sur ce widget
/// est un doigt sur l'écran. Un test qui passerait par
/// `tester.binding.handlePopRoute()` prouverait seulement qu'Android s'en sort,
/// c'est-à-dire exactement ce qui marchait déjà.
final _backArrow = find.byType(BackButton);

void main() {
  group('1. Le geste mène au formulaire', () {
    testWidgets('Échanges : le formulaire, dans l\'onglet, sans rien pousser',
        (tester) async {
      final router = await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      // Le formulaire, et **le vrai** : celui que `/auth` sert aussi.
      expect(find.byType(SignInTab), findsOneWidget);
      expect(find.byType(IdentifierForm), findsOneWidget);
      expect(find.text(_fr.authContinue), findsOneWidget);
      // Et rien n'a été poussé : on est toujours sur `/home`.
      expect(router.state.matchedLocation, '/home');
    });

    testWidgets(
        'requireSession pousse le formulaire, jamais un écran d\'accueil',
        (tester) async {
      // Le second chemin, celui qui reste : un geste qui n'est **pas** un onglet.
      // `requireSession()` pousse toujours le parcours, mais sa première page est
      // désormais le formulaire.
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);

      container.read(sessionGateProvider.notifier).require(action: () {});
      await settle(tester);

      expect(router.state.matchedLocation, '/auth');
      expect(find.byType(IdentifierScreen), findsOneWidget);
      expect(find.text(_fr.authContinue), findsOneWidget);
    });
  });

  group('2. Le formulaire dit pourquoi on y est', () {
    testWidgets('Échanges : « pour accéder aux échanges »', (tester) async {
      await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      expect(find.text(_fr.authReasonCommunity), findsOneWidget);
      // Et pas celle de l'autre onglet : la phrase vient de l'endroit, elle n'est
      // pas une invitation unique recopiée partout.
      expect(find.text(_fr.authReasonProfile), findsNothing);
    });

    testWidgets('Profil : « pour accéder à votre profil »', (tester) async {
      await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navProfile));
      await settle(tester);

      expect(find.text(_fr.authReasonProfile), findsOneWidget);
      expect(find.text(_fr.authReasonCommunity), findsNothing);
    });

    testWidgets('l\'annonce de canal reste à côté de la raison',
        (tester) async {
      // ⚠️ **Le piège de cette tranche** : la raison prend la place du sous-titre
      // générique, et il serait facile de lui faire prendre aussi celle de
      // l'annonce de canal (#83). Les deux ne répondent pas à la même question —
      // *pourquoi on est là* et *par où le code arrive* —, et l'offre par défaut
      // est l'e-mail seul.
      await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      expect(find.text(_fr.authReasonCommunity), findsOneWidget);
      expect(find.text(_fr.authNoticeEmailOnly), findsOneWidget);
    });

    testWidgets('deux canaux ouverts : la raison remplace le sous-titre',
        (tester) async {
      // **C'est ici que « elle prend la place du sous-titre » se mesure.** Avec un
      // seul canal, l'annonce occupait déjà cette ligne (#83) et l'assertion
      // passerait sans rien prouver ; les deux canaux ouverts sont le seul état où
      // le sous-titre du dépôt paraîtrait.
      await pumpGuestApp(
        tester,
        guestContainer(
          authChannels:
              const AuthChannelOffer(emailOpen: true, phoneOpen: true),
        ),
      );

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      expect(find.text(_fr.authReasonCommunity), findsOneWidget);
      expect(find.text(_fr.authIdentifierSubtitle), findsNothing);
      // Et le sélecteur est bien là : sans lui, le test ci-dessus passerait pour
      // la mauvaise raison — une offre qui n'aurait pas pris.
      expect(find.text(_fr.authPhone), findsOneWidget);
    });

    testWidgets('sur `/auth`, poussé par un geste, l\'invitation est générique',
        (tester) async {
      // La raison vient de l'**onglet**. Un geste qui a poussé le parcours a
      // laissé l'écran d'origine sous la pile ; il n'y a pas d'onglet pour
      // parler, et aucun appelant n'a à transporter une phrase.
      final container = guestContainer();
      await pumpGuestApp(tester, container);

      container.read(sessionGateProvider.notifier).require(action: () {});
      await settle(tester);

      expect(find.text(_fr.authReasonCommunity), findsNothing);
      expect(find.text(_fr.authReasonProfile), findsNothing);
    });

    test('chaque onglet qui exige une session porte une phrase', () {
      // **Le lien entre les deux, vérifié et non espéré.** Un onglet réservé
      // ajouté demain sans phrase afficherait un formulaire muet — exactement
      // l'invitation passe-partout qu'on retire —, et aucun test d'écran ne le
      // dirait.
      final AppLocalizations l = AppLocalizationsFr();
      for (final tab in HomeTab.values) {
        expect(
          signInReasonFor(tab, l),
          tab.requiresSession ? isNotNull : isNull,
          reason: '$tab',
        );
      }
    });
  });

  group('3. On revient sur ses pas, sans bouton système', () {
    testWidgets('dans l\'onglet : la barre du bas est la porte de sortie',
        (tester) async {
      await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);
      expect(find.byType(SignInTab), findsOneWidget);

      // **La barre est là, et elle répond.** C'est ce que le parcours poussé
      // masquait : plein écran, il n'y avait plus d'onglets à toucher.
      await tester.tap(navTab(_fr.navHome));
      await settle(tester);

      expect(shellTab(tester), HomeTab.home);
      expect(shellScreen(tester), isA<HomeScreen>());
    });

    testWidgets('le formulaire poussé porte sa flèche de retour',
        (tester) async {
      final container = guestContainer();
      final router = await pumpGuestApp(tester, container);
      router.go('/media');
      await settle(tester);

      var gestes = 0;
      container
          .read(sessionGateProvider.notifier)
          .require(action: () => gestes++);
      await settle(tester);
      expect(router.state.matchedLocation, '/auth');

      // **La flèche existe, et c'est elle qu'on touche.** L'écran de bienvenue
      // n'en avait pas, et c'est très exactement la panne constatée.
      expect(_backArrow, findsOneWidget);
      await tester.tap(_backArrow);
      await settle(tester);

      // Retour à **l'origine**, pas à l'accueil : le parcours est poussé
      // par-dessus l'écran d'où l'on vient.
      expect(router.state.matchedLocation, '/media');
      expect(gestes, 0);
      expect(
        container.read(sessionGateProvider),
        isNull,
        reason: 'une intention abandonnée ne traîne pas',
      );
    });

    testWidgets('l\'écran du code porte la sienne, et ramène au formulaire',
        (tester) async {
      // **L'étape la plus facile à oublier.** Le formulaire atteignait l'écran du
      // code par un `go`, qui remplace la pile : plus rien à dépiler, donc plus
      // de flèche — et sur iPhone, qui s'était trompé d'adresse n'avait aucun
      // moyen de revenir la corriger.
      await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      // **Une adresse qui n'est pas celle de l'indication** (`authEmailHint` vaut
      // `jean.kossi@email.com`) : sinon l'assertion finale serait satisfaite par
      // le champ vide, et ne prouverait plus que la saisie a survécu.
      await tester.enterText(find.byType(TextField), 'jean@eenv.test');
      await tester.tap(find.text(_fr.authContinue));
      await settle(tester);

      expect(find.byType(CodeScreen), findsOneWidget);
      expect(_backArrow, findsOneWidget);

      await tester.tap(_backArrow);
      await settle(tester);

      // On retrouve l'onglet **et** sa saisie : la coquille n'a jamais été
      // démontée, elle attendait dessous.
      expect(find.byType(CodeScreen), findsNothing);
      expect(shellTab(tester), HomeTab.community);
      expect(find.byType(SignInTab), findsOneWidget);
      expect(find.text('jean@eenv.test'), findsOneWidget);
    });
  });

  group('4. La connexion menée dans l\'onglet, de bout en bout', () {
    testWidgets('le code validé, et l\'onglet montre son contenu',
        (tester) async {
      // **Le seul test qui parcoure le chemin entier au doigt**, et il couvre une
      // propriété qu'aucune lecture du code ne donne : l'écran du code revient à
      // l'accueil (`go('/home')`, plus la garde qui l'y renvoie de toute façon),
      // donc la pile se reconstruit — et c'est la **clé de la page `/home`** qui
      // fait survivre l'état de la coquille, donc l'onglet demandé. Si elle
      // changeait un jour, la personne retomberait sur l'accueil après s'être
      // connectée depuis Échanges, et rien d'autre ne le dirait.
      final router = await pumpGuestApp(tester, guestContainer());

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'jean@eenv.test');
      await tester.tap(find.text(_fr.authContinue));
      await settle(tester);
      expect(find.byType(CodeScreen), findsOneWidget);

      // Les six cases se remplissent d'un coup, comme un code collé.
      await tester.enterText(find.byType(TextField).first, '123456');
      await settle(tester);

      expect(router.state.matchedLocation, '/home');
      expect(find.byType(CodeScreen), findsNothing);
      // **L'onglet demandé, avec son écran** — pas l'accueil, et sans que
      // personne n'ait eu à retoucher la barre du bas.
      expect(shellTab(tester), HomeTab.community);
      expect(shellScreen(tester), isA<GroupsScreen>());
      expect(find.byType(SignInTab, skipOffstage: false), findsNothing);
    });
  });

  group('Le cas « déjà connecté » ne change pas', () {
    testWidgets('aucun formulaire nulle part, et les onglets sont immédiats',
        (tester) async {
      final container = guestContainer(
        auth: GuestAuthRepository(signedIn: true),
        vault: StartupVault.memberSession,
      );
      final router = await pumpGuestApp(tester, container);
      await untilSignedIn(tester, container);

      await tester.tap(navTab(_fr.navGroups));
      await settle(tester);

      expect(shellTab(tester), HomeTab.community);
      expect(shellScreen(tester), isA<GroupsScreen>());
      expect(router.state.matchedLocation, '/home');
      // `skipOffstage: false` : la coquille construit ses quatre onglets, donc un
      // formulaire resté dans l'un d'eux existerait dans l'arbre sans être peint.
      expect(find.byType(SignInTab, skipOffstage: false), findsNothing);
      expect(find.byType(IdentifierForm, skipOffstage: false), findsNothing);
    });
  });
}
