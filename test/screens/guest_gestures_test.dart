/// **`requireSession()` posé sur les gestes**, vu depuis l'écran.
///
/// La règle est « le geste, pas l'écran » : les écrans réservés sont déjà fermés
/// par la garde du routeur (`memberOnlyRoutes`), et ce que ces tests couvrent est
/// le bouton qui vit **à l'intérieur d'un écran ouvert** et mène à un geste
/// réservé. Sans `requireSession()`, ce bouton-là n'est pas une erreur bruyante :
/// c'est une porte qui renvoie l'invité sur l'accueil sans un mot, c'est-à-dire
/// un cul-de-sac.
///
/// Chaque geste est vérifié deux fois, et les deux comptent autant :
///
/// - **invité** → la connexion s'ouvre, puis le geste part **tout seul** ;
/// - **membre** → le geste part au premier appui, sans détour ni intention en
///   attente.
///
/// **Le profil n'y figure plus.** Il était ici tant qu'il s'ouvrait depuis
/// l'icône de l'en-tête de l'accueil ; il est redescendu dans la barre du bas,
/// et sa garde — toujours un `requireSession()` au geste — se vérifie désormais
/// avec les autres onglets, dans `guest_tabs_test.dart`.
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/announcement_draft.dart';
import 'package:maison_du_miracle/models/announcement_view.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/screens/announcements_screen.dart';
import 'package:maison_du_miracle/screens/auth/identifier_screen.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/widgets/content_player_view.dart';

import '../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();

const _teachingId = '019f7000-0000-7000-8000-000000000001';

const _teaching = TeachingView(
  id: _teachingId,
  title: 'La foi qui déplace',
  color: 0xFF223B8C,
  playlistUrl: 'https://exemple.test/enseignement/master.m3u8',
);

/// Un enseignement posé **sans magasin ni réseau** : la fiche est un écran de la
/// surface invitée, et ce qu'on y teste est son bouton de notes, pas la
/// médiathèque.
List<Override> get _oneTeaching => [
      teachingByIdProvider.overrideWith(
        (ref, id) => Stream.value(id == _teachingId ? _teaching : null),
      ),
    ];

/// Un compte officiel dont cet appareil garde la trace.
///
/// **C'est le cas qui rend le geste d'écriture atteignable par un invité**, et il
/// n'a rien d'exotique : `canCompose` se lit dans le magasin local, et la
/// déconnexion ne vide pas le magasin. Les lignes
/// d'`official_account_memberships` laissées par la session précédente survivent,
/// donc les deux boutons d'écriture s'affichent pour l'invité qui suit.
AnnouncementRepository _withWriteAffordance() => InMemoryAnnouncementRepository(
      announcements: [
        AnnouncementView.resolve(
          id: 'a_1',
          publishedAt: DateTime.utc(2026, 3, 9),
          accountId: 7,
          accountName: 'Diaconat',
          title: 'Répétition de la chorale',
        ),
      ],
      member: true,
      options: const ComposerOptions(
        accounts: [ComposerAccount(id: 7, name: 'Diaconat')],
        backgrounds: [],
      ),
    );

/// Amène la coquille sur l'onglet Annonces.
///
/// Nécessaire avant de toucher les commandes d'écriture : un `IndexedStack` ne
/// **teste les coups** que sur l'onglet affiché, et les trois autres, bien que
/// construits, ne reçoivent aucun `tap`.
Future<void> _showAnnouncements(WidgetTester tester) async {
  await tester.tap(navTab(_fr.navAnnouncements));
  await settle(tester);
}

void main() {
  group('Écrire une note, depuis la fiche d\'un enseignement', () {
    // Le geste cherche dans le magasin Drift une note déjà liée à
    // l'enseignement : tout dans un seul `runAsync`, sans quoi il se fige.
    testWidgets('un invité : la connexion, puis les notes', (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: _oneTeaching);
        final router = await pumpGuestApp(tester, container);

        // La fiche est **ouverte** à un invité : c'est la décision du client,
        // et c'est ce qui rend ce bouton-ci dangereux sans garde de geste.
        router.go('/teaching/$_teachingId');
        await settle(tester);
        expect(router.state.matchedLocation, '/teaching/$_teachingId');

        await tester.tap(find.byKey(ContentPlayerView.notesButtonKey));
        await settle(tester);
        expect(router.state.matchedLocation, '/auth');

        await signIn(container);
        await settle(tester);
        await settle(tester);

        // On revient sur la fiche — l'origine — et l'éditeur s'ouvre dessus,
        // sur un brouillon **pré-lié** à l'enseignement (#190).
        expect(router.state.matchedLocation, startsWith('/notes/'));
        expect(router.state.extra, _teachingId);
      });
    });

    testWidgets('un membre : les notes au premier appui', (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(
          auth: GuestAuthRepository(signedIn: true),
          vault: StartupVault.memberSession,
          extra: _oneTeaching,
        );
        final router = await pumpGuestApp(tester, container);
        await untilSignedIn(tester, container);

        router.go('/teaching/$_teachingId');
        await settle(tester);

        await tester.tap(find.byKey(ContentPlayerView.notesButtonKey));
        await settle(tester);
        await settle(tester);

        expect(router.state.matchedLocation, startsWith('/notes/'));
        expect(router.state.extra, _teachingId);
        expect(find.byType(IdentifierScreen), findsNothing);
      });
    });
  });

  group('Publier et corriger une annonce', () {
    testWidgets('un invité : la connexion, puis le composeur', (tester) async {
      final container = guestContainer(
        announcements: _withWriteAffordance(),
      );
      final router = await pumpGuestApp(tester, container);
      await _showAnnouncements(tester);

      // L'affordance **est là** pour un invité dont l'appareil garde la trace
      // d'un compte officiel. C'est ce que ce test épingle d'abord : si elle
      // disparaissait, les deux assertions suivantes passeraient pour de mauvaises
      // raisons.
      expect(find.byKey(composeActionKey), findsOneWidget);

      await tester.tap(find.byKey(composeActionKey));
      await settle(tester);
      expect(router.state.matchedLocation, '/auth');

      await signIn(container);
      await settle(tester);

      expect(router.state.matchedLocation, '/announcement/compose');
    });

    testWidgets('un invité : corriger passe aussi par la connexion',
        (tester) async {
      final container = guestContainer(
        announcements: _withWriteAffordance(),
      );
      final router = await pumpGuestApp(tester, container);
      await _showAnnouncements(tester);

      expect(find.byKey(editActionKey), findsOneWidget);
      await tester.tap(find.byKey(editActionKey));
      await settle(tester);
      expect(router.state.matchedLocation, '/auth');

      await signIn(container);
      await settle(tester);

      // **L'identifiant survit au détour**, parce que c'est une valeur et non un
      // état d'écran : la reprise ouvre la modification de *cette* annonce.
      expect(router.state.matchedLocation, '/announcement/a_1/edit');
    });

    testWidgets('un membre : le composeur au premier appui', (tester) async {
      final container = guestContainer(
        auth: GuestAuthRepository(signedIn: true),
        vault: StartupVault.memberSession,
        announcements: _withWriteAffordance(),
      );
      final router = await pumpGuestApp(tester, container);
      await untilSignedIn(tester, container);
      await _showAnnouncements(tester);

      await tester.tap(find.byKey(composeActionKey));
      await settle(tester);

      expect(router.state.matchedLocation, '/announcement/compose');
      expect(find.byType(IdentifierScreen), findsNothing);
    });
  });
}
