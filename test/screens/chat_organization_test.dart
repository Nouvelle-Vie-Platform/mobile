/// **Organiser ses discussions** (#146, tranche M8) — ce que l'écran montre et
/// ce qu'il fait : la rangée « Archivées (N) », les épingles en tête, les gestes
/// de tuile (appui long, glissement) **sans casser le balayage d'onglet**, la
/// recherche locale puis serveur, et l'ouverture d'un fil sur le message trouvé.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/messaging/group_arranger.dart';
import 'package:maison_du_miracle/data/messaging/thread_message_locator.dart';
import 'package:maison_du_miracle/data/repositories/chat_search_repository.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/chat_organization.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/archived_chats_screen.dart';
import 'package:maison_du_miracle/screens/chat_search_screen.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/state/chat_organization_providers.dart';
import 'package:maison_du_miracle/widgets/chat/message_focus_highlight.dart';
import 'package:maison_du_miracle/widgets/community/chat_list_header.dart';
import 'package:maison_du_miracle/widgets/community/my_requests_tab.dart';
import 'package:maison_du_miracle/widgets/community/organizable_conversation_tile.dart';

import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

final _fr = AppLocalizationsFr();

ConversationView _conversation(
  String id,
  String title, {
  bool archived = false,
  DateTime? pinnedAt,
  int unread = 0,
}) =>
    ConversationView(
      groupId: id,
      title: title,
      isDirect: false,
      memberCount: 3,
      canWrite: true,
      lastMessagePreview: 'Dernier message de $title',
      lastMessageAt: DateTime.utc(2026, 10, 6, 9),
      unreadCount: unread,
      archived: archived,
      pinnedAt: pinnedAt,
    );

/// Un rangement qui retient les gestes et répond ce qu'on lui dit — sans base.
class _FakeArranger implements GroupArranger {
  _FakeArranger({this.answer = ArrangeResult.done});

  ArrangeResult answer;
  final List<String> calls = [];

  @override
  Future<ArrangeResult> archive(String groupId, {required bool value}) async {
    calls.add('${value ? 'archive' : 'unarchive'}:$groupId');
    return answer;
  }

  @override
  Future<ArrangeResult> pin(String groupId, {required bool value}) async {
    calls.add('${value ? 'pin' : 'unpin'}:$groupId');
    return answer;
  }

  @override
  Future<void> replay() async {}
}

/// Un localisateur qui connaît d'avance la place du message.
class _FixedLocator implements ThreadMessageLocator {
  _FixedLocator(this.window);

  final int? window;
  final List<String> asked = [];

  @override
  int get maxPages => 0;

  @override
  Future<int?> windowFor(String groupId, String messageId) async {
    asked.add(messageId);
    return window;
  }
}

/// Le texte d'une tuile — son titre — dans la liste.
Finder _tile(String title) => find.descendant(
      of: find.byType(OrganizableConversationTile),
      matching: find.text(title),
    );

/// Laisse la confirmation (SnackBar) expirer : sa minuterie survivrait au test.
Future<void> _drainSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<_FakeArranger> _pumpMessages(
  WidgetTester tester,
  List<ConversationView> conversations, {
  _FakeArranger? arranger,
}) async {
  final fake = arranger ?? _FakeArranger();
  await pumpScreen(
    tester,
    const Scaffold(body: GroupsScreen()),
    auth: SignedInAuthRepository(),
    echanges: InMemoryEchangesRepository(conversations: conversations),
    overrides: [groupArrangerProvider.overrideWith((ref, actor) => fake)],
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('La liste rangée', () {
    testWidgets(
        'les archives quittent la liste pour la rangée « Archivées (N) »',
        (tester) async {
      await _pumpMessages(tester, [
        _conversation('g-1', 'Chorale'),
        _conversation('g-2', 'Jeunesse', archived: true),
        _conversation('g-3', 'Intercession', archived: true, unread: 4),
      ]);

      expect(find.byKey(ArchivedChatsRow.rowKey), findsOneWidget);
      expect(find.text(_fr.chatArchivedRow(2)), findsOneWidget);
      expect(_tile('Chorale'), findsOneWidget);
      expect(_tile('Jeunesse'), findsNothing);
      expect(_tile('Intercession'), findsNothing);
    });

    testWidgets('pas d\'archive, pas de rangée', (tester) async {
      await _pumpMessages(tester, [_conversation('g-1', 'Chorale')]);

      expect(find.byKey(ArchivedChatsRow.rowKey), findsNothing);
    });

    testWidgets('les épingles en tête, la plus récente d\'abord, avec l\'icône',
        (tester) async {
      await _pumpMessages(tester, [
        // L'ordre reçu est la récence ; les épingles passent devant.
        _conversation('g-1', 'Chorale'),
        _conversation('g-2', 'Jeunesse', pinnedAt: DateTime.utc(2026, 10, 1)),
        _conversation('g-3', 'Intercession',
            pinnedAt: DateTime.utc(2026, 10, 5)),
      ]);

      final y = {
        for (final t in ['Chorale', 'Jeunesse', 'Intercession'])
          t: tester.getTopLeft(_tile(t)).dy,
      };
      expect(y['Intercession']!, lessThan(y['Jeunesse']!));
      expect(y['Jeunesse']!, lessThan(y['Chorale']!));
      expect(
          find.byKey(const Key('conversation_pinned_icon')), findsNWidgets(2));
    });

    test('organizeConversations : archive l\'emporte, tri stable des épingles',
        () {
      final same = DateTime.utc(2026, 10, 1);
      final shelves = organizeConversations([
        _conversation('a', 'A', pinnedAt: same),
        _conversation('b', 'B'),
        _conversation('c', 'C', pinnedAt: same),
        _conversation('d', 'D', archived: true, pinnedAt: same),
      ]);
      expect(shelves.main.map((c) => c.groupId), ['a', 'c', 'b']);
      expect(shelves.archived.map((c) => c.groupId), ['d']);
    });

    test('le badge de l\'onglet ignore les archives', () {
      expect(
        totalUnread([
          _conversation('a', 'A', unread: 2),
          _conversation('b', 'B', unread: 5, archived: true),
        ]),
        2,
      );
    });
  });

  group('Les gestes de tuile', () {
    testWidgets('glisser une tuile vers la gauche l\'archive', (tester) async {
      final arranger = await _pumpMessages(tester, [
        _conversation('g-1', 'Chorale'),
        _conversation('g-2', 'Jeunesse'),
      ]);

      await tester.drag(
        find.byKey(OrganizableConversationTile.dismissKeyOf('g-2')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(arranger.calls, ['archive:g-2']);
      // On reste sur l'onglet Messages : le geste était celui de la tuile.
      expect(find.byType(MyRequestsTab), findsNothing);
      expect(find.text(_fr.chatArchivedNotice), findsOneWidget);
      await _drainSnackBar(tester);
    });

    testWidgets(
        'le balayage d\'onglet marche encore hors des tuiles — et ne range rien',
        (tester) async {
      final arranger = await _pumpMessages(tester, [
        _conversation('g-1', 'Chorale'),
      ]);

      // Commencé sous la liste : pas sur une tuile.
      await tester.flingFrom(
        tester.getBottomLeft(find.byType(TabBarView)) + const Offset(200, -40),
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.byType(MyRequestsTab), findsOneWidget);
      expect(arranger.calls, isEmpty);

      // Et retour, depuis l'onglet Requêtes.
      await tester.fling(find.byType(TabBarView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(MyRequestsTab), findsNothing);
    });

    testWidgets('appui long : le menu, puis Épingler', (tester) async {
      final arranger = await _pumpMessages(tester, [
        _conversation('g-1', 'Chorale', unread: 2),
      ]);

      await tester.longPress(_tile('Chorale'));
      await tester.pumpAndSettle();

      expect(find.text(_fr.chatArchive), findsOneWidget);
      expect(find.text(_fr.chatPin), findsOneWidget);
      expect(find.text(_fr.chatMarkRead), findsOneWidget);

      await tester.tap(find.text(_fr.chatPin));
      await tester.pumpAndSettle();
      expect(arranger.calls, ['pin:g-1']);
    });

    testWidgets('une épingle de trop se refuse, et l\'écran le dit',
        (tester) async {
      final arranger = await _pumpMessages(
        tester,
        [_conversation('g-1', 'Chorale')],
        arranger: _FakeArranger(answer: ArrangeResult.pinLimit),
      );

      await tester.longPress(_tile('Chorale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_fr.chatPin));
      await tester.pumpAndSettle();

      expect(arranger.calls, ['pin:g-1']);
      expect(find.text(_fr.chatPinLimit(kMaxPinnedChats)), findsOneWidget);
      await _drainSnackBar(tester);
    });

    testWidgets('une discussion épinglée offre « Désépingler »',
        (tester) async {
      await _pumpMessages(tester, [
        _conversation('g-1', 'Chorale', pinnedAt: DateTime.utc(2026, 10, 1)),
      ]);

      await tester.longPress(_tile('Chorale'));
      await tester.pumpAndSettle();

      expect(find.text(_fr.chatUnpin), findsOneWidget);
      expect(find.text(_fr.chatPin), findsNothing);
      // Rien de non lu : pas de « Marquer comme lu ».
      expect(find.text(_fr.chatMarkRead), findsNothing);
    });
  });

  group('Les archives', () {
    testWidgets('l\'écran des archives les liste, et glisser désarchive',
        (tester) async {
      final arranger = _FakeArranger();
      await pumpScreen(
        tester,
        const ArchivedChatsScreen(),
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(conversations: [
          _conversation('g-1', 'Chorale'),
          _conversation('g-2', 'Jeunesse', archived: true),
        ]),
        overrides: [
          groupArrangerProvider.overrideWith((ref, actor) => arranger),
        ],
      );
      await tester.pumpAndSettle();

      expect(_tile('Jeunesse'), findsOneWidget);
      expect(_tile('Chorale'), findsNothing);

      await tester.drag(
        find.byKey(OrganizableConversationTile.dismissKeyOf('g-2')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(arranger.calls, ['unarchive:g-2']);
    });

    testWidgets('vide : on le dit', (tester) async {
      await pumpScreen(
        tester,
        const ArchivedChatsScreen(),
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(
          conversations: [_conversation('g-1', 'Chorale')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_fr.chatArchivedEmptyTitle), findsOneWidget);
    });
  });

  group('La recherche', () {
    GoRouter searchRouter() => GoRouter(
          initialLocation: '/search',
          routes: [
            GoRoute(
              path: '/search',
              builder: (_, __) => const ChatSearchScreen(),
            ),
            GoRoute(
              name: AppRoute.groupChat,
              path: '/group-chat/:id',
              builder: (_, state) => Scaffold(
                body: Text(
                  'fil ${state.pathParameters['id']} '
                  'sur ${state.uri.queryParameters['message']}',
                ),
              ),
            ),
          ],
        );

    Future<InMemoryChatSearchRepository> pumpSearch(
      WidgetTester tester, {
      List<MessageSearchHit> local = const [],
      List<MessageSearchHit> remote = const [],
    }) async {
      final search = InMemoryChatSearchRepository(local: local, remote: remote);
      await pumpRouter(
        tester,
        searchRouter(),
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(conversations: [
          _conversation('g-1', 'Chorale Harmonie'),
          _conversation('g-2', 'Jeunesse'),
        ]),
        overrides: [
          chatSearchRepositoryProvider.overrideWith((ref, actor) => search),
        ],
      );
      await tester.pumpAndSettle();
      return search;
    }

    const localHit = MessageSearchHit(
      messageId: 'm-local',
      groupId: 'g-2',
      body: 'La chorale chante dimanche',
      authorName: 'Estelle',
    );
    const remoteHit = MessageSearchHit(
      messageId: 'm-old',
      groupId: 'g-1',
      body: 'Première répétition de la chorale',
    );

    testWidgets('locale à la frappe, serveur après la pause, sans doublon',
        (tester) async {
      final search = await pumpSearch(
        tester,
        local: [localHit],
        // Le serveur rend aussi le message déjà trouvé en local.
        remote: [localHit, remoteHit],
      );

      await tester.enterText(find.byKey(ChatSearchScreen.fieldKey), 'chorale');
      await tester.pump();
      await tester.pump();

      // Le nom de discussion, et le message du magasin — tout de suite.
      expect(find.text(_fr.chatSearchChats), findsOneWidget);
      expect(find.text('Chorale Harmonie'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_search_hit_m-local')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('chat_search_hit_m-old')), findsNothing);
      expect(search.remoteQueries, isEmpty);

      // Puis le serveur.
      await tester.pump(ChatSearchScreen.remoteDelay);
      await tester.pumpAndSettle();
      expect(search.remoteQueries, ['chorale']);
      expect(
          find.byKey(const ValueKey('chat_search_hit_m-old')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_search_hit_m-local')),
          findsOneWidget);
    });

    testWidgets('une lettre ne cherche pas', (tester) async {
      final search = await pumpSearch(tester, local: [localHit]);

      await tester.enterText(find.byKey(ChatSearchScreen.fieldKey), 'c');
      await tester.pump(ChatSearchScreen.remoteDelay);
      await tester.pumpAndSettle();

      expect(
          find.text(_fr.chatSearchMinLength(kMinSearchLength)), findsOneWidget);
      expect(search.remoteQueries, isEmpty);
    });

    testWidgets('toucher un message ouvre son fil, sur lui', (tester) async {
      await pumpSearch(tester, local: [localHit]);

      await tester.enterText(find.byKey(ChatSearchScreen.fieldKey), 'chorale');
      await tester.pump(ChatSearchScreen.remoteDelay);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat_search_hit_m-local')));
      await tester.pumpAndSettle();

      expect(find.text('fil g-2 sur m-local'), findsOneWidget);
    });

    test('les noms : accents et casse ignorés', () {
      final hits = conversationsMatching([
        _conversation('g-1', 'Église de Lomé'),
        _conversation('g-2', 'Jeunesse'),
      ], 'eglise');
      expect(hits.map((c) => c.groupId), ['g-1']);
    });
  });

  group('Le fil ouvert sur un message trouvé', () {
    List<GroupMessageView> longThread() => [
          for (var i = 0; i < 80; i++)
            GroupMessageView(
              id: 'm-$i',
              groupId: 'g-1',
              body: 'Message numéro $i',
              origin: MessageOrigin.member,
              mine: false,
              delivery: MessageDelivery.sent,
              authorId: 'u-peer',
              authorName: 'Estelle',
              createdAt: DateTime.utc(2026, 10, 6, 8).add(Duration(minutes: i)),
            ),
        ];

    testWidgets(
        'le fil élargit sa fenêtre, se rend au message et le met en évidence',
        (tester) async {
      final locator = _FixedLocator(70);
      await pumpScreen(
        tester,
        const GroupChatScreen(groupId: 'g-1', focusMessageId: 'm-10'),
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(
          groups: {
            'g-1': const GroupDetailView(
              groupId: 'g-1',
              title: 'Chorale',
              isDirect: false,
              memberCount: 3,
              canWrite: true,
            ),
          },
          threads: {'g-1': longThread()},
        ),
        overrides: [threadMessageLocatorProvider.overrideWithValue(locator)],
      );
      await tester.pumpAndSettle();

      expect(locator.asked, ['m-10']);
      // Hors de la fenêtre par défaut (30), le message est pourtant à l'écran.
      final target = find.byKey(const ValueKey('m-10'));
      expect(target, findsOneWidget);
      final screen = tester.getRect(find.byType(GroupChatScreen));
      expect(screen.contains(tester.getCenter(target)), isTrue);
      expect(find.byKey(MessageFocusHighlight.tintKey), findsOneWidget);

      // La mise en évidence s'efface d'elle-même.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(MessageFocusHighlight.tintKey), findsNothing);

      // Et elle ne se rallume pas quand la liste recrée la bulle : on descend
      // tout en bas (la bulle quitte l'arbre), puis on revient sur elle.
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final there = position.pixels;
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(target, findsNothing);
      position.jumpTo(there);
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      expect(find.byKey(MessageFocusHighlight.tintKey), findsNothing);
    });

    testWidgets('introuvable : le fil s\'ouvre comme d\'habitude, en bas',
        (tester) async {
      await pumpScreen(
        tester,
        const GroupChatScreen(groupId: 'g-1', focusMessageId: 'disparu'),
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(
          groups: {
            'g-1': const GroupDetailView(
              groupId: 'g-1',
              title: 'Chorale',
              isDirect: false,
              memberCount: 3,
              canWrite: true,
            ),
          },
          threads: {'g-1': longThread()},
        ),
        overrides: [
          threadMessageLocatorProvider.overrideWithValue(_FixedLocator(null)),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('m-79')), findsOneWidget);
      expect(find.byKey(MessageFocusHighlight.tintKey), findsNothing);
    });
  });
}
