/// **Discussions et groupes gérés depuis l'application** (#145, tranche M6 :
/// décisions 8 et 9 du plan de messagerie), à l'écran.
///
/// - « Nouvelle discussion » : un sélecteur **borné** à mes contacts de groupe,
///   avec recherche ; « Nouveau groupe » n'existe que pour un responsable ;
/// - la fiche d'un groupe : rejoindre / demander selon la politique, quitter
///   (jamais un tête-à-tête), et administrer selon mon rôle (ADR-0009) ;
/// - le premier message d'un tête-à-tête part sous la clé de la personne.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/data/repositories/group_admin_client.dart';
import 'package:maison_du_miracle/data/repositories/group_message_sender.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/group_management.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/direct_chat_screen.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/screens/group_info_screen.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/screens/member_profile_screen.dart';
import 'package:maison_du_miracle/screens/new_conversation_screen.dart';
import 'package:maison_du_miracle/widgets/community/contact_picker.dart';
import 'package:maison_du_miracle/widgets/community/group_admin_section.dart';
import 'package:maison_du_miracle/widgets/community/join_group_card.dart';
import 'package:maison_du_miracle/widgets/community/new_conversation_entry.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/guest_app.dart';
import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

final _fr = AppLocalizationsFr();

/// Moi, tel que `SignedInAuthRepository` me connecte.
const String _me = 'u_1';
const String _groupId = 'g-1';

/// Un client de gestes qui **note** ce qu'on lui demande, et répond `done`.
class _RecordingAdmin implements GroupAdminClient {
  _RecordingAdmin({
    this.canCreate = false,
    this.requests = const [],
  });

  final bool canCreate;
  final List<PendingJoinRequestView> requests;
  final List<String> calls = [];

  @override
  Future<GroupCapabilities> capabilities() async => canCreate
      ? const GroupCapabilities(canCreateGroup: true, createBranchIds: [3])
      : GroupCapabilities.none;

  @override
  Future<GroupActionOutcome> createGroup({
    required String id,
    required String name,
    String? description,
    required List<int> branchIds,
    required List<String> memberIds,
  }) async {
    calls.add('create $name ${memberIds.join(',')}');
    return GroupActionOutcome.done;
  }

  @override
  Future<GroupActionOutcome> join(String groupId) async {
    calls.add('join $groupId');
    return GroupActionOutcome.done;
  }

  @override
  Future<GroupActionOutcome> requestToJoin(String groupId) async {
    calls.add('request $groupId');
    return GroupActionOutcome.done;
  }

  @override
  Future<GroupActionOutcome> leave(String groupId) async {
    calls.add('leave $groupId');
    return GroupActionOutcome.done;
  }

  @override
  Future<GroupActionOutcome> addMember(String groupId, String userId) async {
    calls.add('add $groupId $userId');
    return GroupActionOutcome.done;
  }

  @override
  Future<GroupActionOutcome> removeMember(
    String groupId,
    String userId,
  ) async {
    calls.add('remove $groupId $userId');
    return GroupActionOutcome.done;
  }

  @override
  Future<GroupActionOutcome> setRole(
    String groupId,
    String userId,
    String role,
  ) async {
    calls.add('role $groupId $userId $role');
    return GroupActionOutcome.done;
  }

  @override
  Future<List<PendingJoinRequestView>?> joinRequests(String groupId) async =>
      requests;

  @override
  Future<GroupActionOutcome> decideJoinRequest(
    String groupId,
    int requestId, {
    required bool approve,
  }) async {
    calls.add('${approve ? 'approve' : 'reject'} $groupId $requestId');
    return GroupActionOutcome.done;
  }
}

const _leader = GroupMemberView(
  userId: 'u-leader',
  role: 'leader',
  displayName: 'Pasteur Amavi',
);
const _moderator = GroupMemberView(
  userId: 'u-mod',
  role: 'moderator',
  displayName: 'Estelle Adjo',
);
const _member = GroupMemberView(
  userId: 'u-member',
  role: 'member',
  displayName: 'Kossi Mensah',
);

/// Le groupe tel que je le vois avec [myRole] (`null` = pas membre).
GroupDetailView _group({
  String? myRole,
  String joinPolicy = 'invite_only',
  bool direct = false,
}) =>
    GroupDetailView(
      groupId: _groupId,
      title: 'Chorale Harmonie',
      isDirect: direct,
      memberCount: 4,
      canWrite: true,
      joinPolicy: joinPolicy,
      myRole: myRole,
      members: [
        _leader,
        _moderator,
        _member,
        if (myRole != null)
          GroupMemberView(userId: _me, role: myRole, displayName: 'Moi'),
      ],
    );

Future<void> _pumpInfo(
  WidgetTester tester,
  GroupDetailView group,
  _RecordingAdmin admin,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpScreen(
    tester,
    const GroupInfoScreen(groupId: _groupId),
    auth: SignedInAuthRepository(),
    echanges: InMemoryEchangesRepository(groups: {_groupId: group}),
    groupAdmin: admin,
  );
}

void main() {
  group('« Nouvelle discussion » dans l\'onglet Messages', () {
    testWidgets('un membre a le bouton', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        auth: SignedInAuthRepository(),
      );
      expect(find.byKey(NewConversationEntry.buttonKey), findsOneWidget);
    });

    testWidgets('un invité ne l\'a pas', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        auth: GuestAuthRepository(),
      );
      expect(find.byKey(NewConversationEntry.buttonKey), findsNothing);
    });
  });

  group('Le sélecteur, borné à mes contacts de groupe', () {
    const contacts = [
      ContactView(userId: 'u-a', displayName: 'Afi Mensah'),
      ContactView(userId: 'u-b', displayName: 'Élodie Kpodar'),
    ];

    testWidgets('ne propose que mes contacts, et cherche par nom',
        (tester) async {
      await pumpScreen(
        tester,
        const NewConversationScreen(),
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(contacts: contacts),
      );

      expect(find.text('Afi Mensah'), findsOneWidget);
      expect(find.text('Élodie Kpodar'), findsOneWidget);

      await tester.enterText(find.byKey(ContactPicker.searchFieldKey), 'elo');
      await tester.pump();
      expect(find.text('Afi Mensah'), findsNothing);
      expect(find.text('Élodie Kpodar'), findsOneWidget);

      await tester.enterText(find.byKey(ContactPicker.searchFieldKey), 'zz');
      await tester.pump();
      expect(find.text(_fr.m6NoContactMatch), findsOneWidget);
    });

    testWidgets('personne dans mes groupes : on le dit', (tester) async {
      await pumpScreen(
        tester,
        const NewConversationScreen(),
        auth: SignedInAuthRepository(),
      );
      expect(find.text(_fr.m6NoContacts), findsOneWidget);
    });

    testWidgets('toucher une personne ouvre la discussion avec elle',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const NewConversationScreen()),
          GoRoute(
            name: AppRoute.directChat,
            path: '/direct-chat/:id',
            builder: (_, state) => Text('direct ${state.pathParameters['id']}'),
          ),
        ],
      );
      await pumpRouter(
        tester,
        router,
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(contacts: contacts),
      );

      await tester.tap(find.text('Afi Mensah'));
      await tester.pumpAndSettle();
      expect(find.text('direct u-a'), findsOneWidget);
    });

    testWidgets('« Nouveau groupe » n\'existe pas pour un fidèle',
        (tester) async {
      await pumpScreen(
        tester,
        const NewConversationScreen(),
        auth: SignedInAuthRepository(),
        groupAdmin: _RecordingAdmin(canCreate: false),
      );
      expect(find.byKey(NewConversationScreen.newGroupKey), findsNothing);
      expect(find.text(_fr.m6NewGroup), findsNothing);
    });

    testWidgets('« Nouveau groupe » existe pour un responsable',
        (tester) async {
      await pumpScreen(
        tester,
        const NewConversationScreen(),
        auth: SignedInAuthRepository(),
        groupAdmin: _RecordingAdmin(canCreate: true),
      );
      expect(find.byKey(NewConversationScreen.newGroupKey), findsOneWidget);
    });
  });

  group('Rejoindre ou demander, selon la politique', () {
    testWidgets('groupe ouvert : « Rejoindre » rejoint', (tester) async {
      final admin = _RecordingAdmin();
      await _pumpInfo(tester, _group(joinPolicy: 'open'), admin);

      expect(find.byKey(GroupMembershipActions.requestKey), findsNothing);
      await tester.tap(find.byKey(GroupMembershipActions.joinKey));
      await tester.pump();
      expect(admin.calls, ['join $_groupId']);
    });

    testWidgets('groupe sur demande : « Demander », puis la demande se dit',
        (tester) async {
      final admin = _RecordingAdmin();
      await _pumpInfo(tester, _group(joinPolicy: 'request'), admin);

      expect(find.byKey(GroupMembershipActions.joinKey), findsNothing);
      await tester.tap(find.byKey(GroupMembershipActions.requestKey));
      await tester.pump();
      expect(admin.calls, ['request $_groupId']);
      expect(find.byKey(GroupMembershipActions.requestKey), findsNothing);
      expect(find.text(_fr.echangesJoinPending), findsOneWidget);
    });

    testWidgets('sur invitation : aucun geste', (tester) async {
      await _pumpInfo(tester, _group(), _RecordingAdmin());
      expect(find.byKey(GroupMembershipActions.joinKey), findsNothing);
      expect(find.byKey(GroupMembershipActions.requestKey), findsNothing);
      expect(find.byKey(GroupMembershipActions.leaveKey), findsNothing);
    });

    testWidgets('la carte « à rejoindre » porte le geste', (tester) async {
      final admin = _RecordingAdmin();
      await pumpScreen(
        tester,
        const Scaffold(body: GroupsScreen()),
        auth: SignedInAuthRepository(),
        groupAdmin: admin,
        echanges: InMemoryEchangesRepository(
          discoverGroups: const [
            DiscoverGroupView(
              groupId: 'g-open',
              title: 'Étude biblique',
              joinPolicy: 'open',
              memberCount: 24,
            ),
            DiscoverGroupView(
              groupId: 'g-pending',
              title: 'Chorale',
              joinPolicy: 'request',
              memberCount: 8,
              requestStatus: 'pending',
            ),
          ],
        ),
      );

      // Ma demande attend : la carte le dit, sans offrir le geste de nouveau.
      expect(find.byKey(JoinGroupCard.joinKey('g-pending')), findsNothing);
      await tester.tap(find.byKey(JoinGroupCard.joinKey('g-open')));
      await tester.pump();
      expect(admin.calls, ['join g-open']);
    });
  });

  group('Quitter', () {
    testWidgets('un membre quitte, après confirmation', (tester) async {
      final admin = _RecordingAdmin();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const GroupInfoScreen(groupId: _groupId),
          ),
          GoRoute(
            name: AppRoute.home,
            path: '/home',
            builder: (_, __) => const Text('accueil'),
          ),
        ],
      );
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpRouter(
        tester,
        router,
        auth: SignedInAuthRepository(),
        groupAdmin: admin,
        echanges: InMemoryEchangesRepository(
          groups: {_groupId: _group(myRole: 'member')},
        ),
      );

      await tester.tap(find.byKey(GroupMembershipActions.leaveKey));
      await tester.pumpAndSettle();
      expect(admin.calls, isEmpty,
          reason: 'rien ne part avant la confirmation');
      await tester.tap(find.widgetWithText(TextButton, _fr.m6Leave));
      await tester.pumpAndSettle();

      expect(admin.calls, ['leave $_groupId']);
      expect(find.text('accueil'), findsOneWidget);
    });

    testWidgets('on ne quitte pas un tête-à-tête', (tester) async {
      await _pumpInfo(
        tester,
        _group(myRole: 'member', direct: true),
        _RecordingAdmin(),
      );
      expect(find.byKey(GroupMembershipActions.leaveKey), findsNothing);
    });
  });

  group('Administrer selon le rôle (ADR-0009)', () {
    testWidgets('un simple membre : « Message », et aucun menu',
        (tester) async {
      await _pumpInfo(tester, _group(myRole: 'member'), _RecordingAdmin());

      expect(find.byKey(GroupMembershipActions.addMembersKey), findsNothing);
      expect(find.byKey(GroupMemberActions.menuKey('u-member')), findsNothing);
      expect(
        find.byKey(GroupMemberActions.messageKey('u-member')),
        findsOneWidget,
      );
      // Jamais sur ma propre ligne.
      expect(find.byKey(GroupMemberActions.messageKey(_me)), findsNothing);
    });

    testWidgets('l\'animateur nomme un modérateur et retire un membre',
        (tester) async {
      final admin = _RecordingAdmin();
      await _pumpInfo(tester, _group(myRole: 'leader'), admin);

      expect(find.byKey(GroupMembershipActions.addMembersKey), findsOneWidget);
      expect(find.byKey(GroupMemberActions.menuKey('u-leader')), findsNothing);
      expect(find.byKey(GroupMemberActions.menuKey(_me)), findsNothing);

      await tester.tap(find.byKey(GroupMemberActions.menuKey('u-member')));
      await tester.pumpAndSettle();
      expect(find.text(_fr.m6RemoveMember), findsOneWidget);
      await tester.tap(find.text(_fr.m6MakeModerator));
      await tester.pumpAndSettle();
      expect(admin.calls, ['role $_groupId u-member moderator']);

      await tester.tap(find.byKey(GroupMemberActions.menuKey('u-mod')));
      await tester.pumpAndSettle();
      expect(find.text(_fr.m6RemoveModerator), findsOneWidget);
    });

    testWidgets('un modérateur retire, mais ne nomme pas', (tester) async {
      final admin = _RecordingAdmin();
      await _pumpInfo(tester, _group(myRole: 'moderator'), admin);

      // L'animateur est hors d'atteinte.
      expect(find.byKey(GroupMemberActions.menuKey('u-leader')), findsNothing);

      await tester.tap(find.byKey(GroupMemberActions.menuKey('u-member')));
      await tester.pumpAndSettle();
      expect(find.text(_fr.m6MakeModerator), findsNothing);
      await tester.tap(find.text(_fr.m6RemoveMember));
      await tester.pumpAndSettle();
      // Confirmation, puis retrait.
      await tester.tap(find.widgetWithText(TextButton, _fr.m6RemoveMember));
      await tester.pumpAndSettle();
      expect(admin.calls, ['remove $_groupId u-member']);
    });

    testWidgets('la file des demandes, pour un admin, et la décision',
        (tester) async {
      final admin = _RecordingAdmin(
        requests: const [
          PendingJoinRequestView(
            id: 7,
            userId: 'u-7',
            displayName: 'Afi Mensah',
          ),
        ],
      );
      await _pumpInfo(tester, _group(myRole: 'leader'), admin);
      await tester.pump();

      expect(find.text(_fr.m6PendingRequests), findsOneWidget);
      expect(find.text('Afi Mensah'), findsOneWidget);
      await tester.tap(find.text(_fr.m6Approve));
      await tester.pump();
      expect(admin.calls, ['approve $_groupId 7']);
    });

    testWidgets('un simple membre ne voit pas la file', (tester) async {
      await _pumpInfo(
        tester,
        _group(myRole: 'member'),
        _RecordingAdmin(
          requests: const [PendingJoinRequestView(id: 7, userId: 'u-7')],
        ),
      );
      await tester.pump();
      expect(find.text(_fr.m6PendingRequests), findsNothing);
    });
  });

  group('La discussion privée avec une personne', () {
    testWidgets('pas encore commencée : le premier message part sous sa clé',
        (tester) async {
      final AppDatabase db = openTestDatabase();
      addTearDown(db.close);

      // Drift sous `testWidgets` : tout dans **un seul** `runAsync`.
      await tester.runAsync(() async {
        await pumpScreen(
          tester,
          const DirectChatScreen(userId: 'u-a'),
          database: db,
          auth: SignedInAuthRepository(),
          echanges: InMemoryEchangesRepository(
            members: const {
              'u-a': MemberProfileView(userId: 'u-a', displayName: 'Afi'),
            },
          ),
        );

        expect(find.text(_fr.m6DirectFirstMessage), findsOneWidget);
        expect(find.byType(GroupChatScreen), findsNothing);

        await tester.enterText(find.byType(TextField), 'Bonjour Afi');
        await tester.tap(find.byIcon(Icons.send));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // L'écho est rangé sous la clé de la personne : c'est elle que
        // l'envoyeur reconnaît pour poster à la route directe.
        final pending = await db.select(db.pendingGroupMessages).get();
        expect(pending.single.groupId, directThreadKey('u-a'));
        expect(pending.single.body, 'Bonjour Afi');
      });
    });

    testWidgets('déjà commencée : c\'est le fil ordinaire', (tester) async {
      await pumpScreen(
        tester,
        const DirectChatScreen(userId: 'u-a'),
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(
          members: const {
            'u-a': MemberProfileView(
              userId: 'u-a',
              displayName: 'Afi',
              directGroupId: 'g-dm',
            ),
          },
        ),
      );
      expect(find.byType(GroupChatScreen), findsOneWidget);
    });

    testWidgets('la fiche d\'un membre offre « Message » même sans fil',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const MemberProfileScreen(memberId: 'u-a'),
          ),
          GoRoute(
            name: AppRoute.directChat,
            path: '/direct-chat/:id',
            builder: (_, state) => Text('direct ${state.pathParameters['id']}'),
          ),
        ],
      );
      await pumpRouter(
        tester,
        router,
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(
          members: const {
            'u-a': MemberProfileView(userId: 'u-a', displayName: 'Afi'),
          },
        ),
      );

      await tester.tap(find.text(_fr.memberMessage));
      await tester.pumpAndSettle();
      expect(find.text('direct u-a'), findsOneWidget);
    });

    testWidgets('ma propre fiche n\'offre pas « Message »', (tester) async {
      await pumpScreen(
        tester,
        const MemberProfileScreen(memberId: _me),
        auth: SignedInAuthRepository(),
        echanges: InMemoryEchangesRepository(
          members: const {
            _me: MemberProfileView(userId: _me, displayName: 'Moi'),
          },
        ),
      );
      expect(find.text(_fr.memberMessage), findsNothing);
    });

    test('la clé du premier message désigne la personne', () {
      expect(directThreadKey('u-a'), 'direct:u-a');
    });
  });
}
