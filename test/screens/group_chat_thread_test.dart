/// **Un fil fiable, comme WhatsApp** (#140) — ce que l'écran montre et ce qu'il
/// fait : s'ouvrir en bas ou sur le premier non-lu, faire avancer la lecture,
/// offrir le geste sur un message non parti, dire l'effectif juste, ne plus
/// mentir (pastille « en ligne », boutons inertes), et ne jamais laisser le
/// retour dans un cul-de-sac.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/messaging/group_read_advancer.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/screens/home_shell.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/theme/app_colors.dart';
import 'package:maison_du_miracle/widgets/app_bottom_nav.dart';
import 'package:maison_du_miracle/widgets/chat/chat_app_bar.dart';
import 'package:maison_du_miracle/widgets/chat/chat_bubble.dart';
import 'package:maison_du_miracle/widgets/chat/message_input_bar.dart';
import 'package:maison_du_miracle/widgets/community/conversation_tile.dart';
import 'package:maison_du_miracle/widgets/home_tab.dart';
import 'package:maison_du_miracle/widgets/unread_badge.dart';

import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

const String _groupId = 'g-1';
final _fr = AppLocalizationsFr();

GroupDetailView _group({int memberCount = 3}) => GroupDetailView(
      groupId: _groupId,
      title: 'Chorale Harmonie',
      isDirect: false,
      memberCount: memberCount,
      canWrite: true,
    );

GroupMessageView _message(
  String id, {
  String? body = 'Bonjour',
  bool unread = false,
  bool mine = false,
  MessageDelivery delivery = MessageDelivery.sent,
  int minute = 0,
}) =>
    GroupMessageView(
      id: id,
      groupId: _groupId,
      body: body,
      origin: messageOriginOf(
        authorId: mine ? 'u-me' : 'u-peer',
        isSystem: false,
      ),
      mine: mine,
      delivery: delivery,
      authorId: mine ? 'u-me' : 'u-peer',
      authorName: mine ? null : 'Estelle Adjo',
      createdAt: DateTime.utc(2026, 10, 5, 10, minute),
      unread: unread,
    );

class _RecordingReadSender implements GroupReadSender {
  final List<String> posted = [];

  @override
  Future<ReadOutcome> send({
    required String groupId,
    required String messageId,
  }) async {
    posted.add(messageId);
    return const ReadUnreachable();
  }
}

Future<void> _pumpThread(
  WidgetTester tester,
  List<GroupMessageView> messages, {
  GroupDetailView? group,
  GroupReadSender? readSender,
  AppDatabase? database,
  AuthRepository? auth,
}) =>
    pumpScreen(
      tester,
      const GroupChatScreen(groupId: _groupId),
      database: database,
      readSender: readSender,
      auth: auth,
      echanges: InMemoryEchangesRepository(
        groups: {_groupId: group ?? _group()},
        threads: {_groupId: messages},
      ),
    );

void main() {
  group('L\'ouverture', () {
    testWidgets('la liste est inversée : le fil s\'ouvre en bas',
        (tester) async {
      await _pumpThread(tester, [_message('m-1'), _message('m-2', minute: 1)]);

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.reverse, isTrue);
      // Le plus récent est le plus bas.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('m-2'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey('m-1'))).dy),
      );
    });

    testWidgets(
        's\'il y a des non-lus, un séparateur « N messages non lus » se pose '
        'au-dessus du premier', (tester) async {
      await _pumpThread(tester, [
        _message('m-1'),
        _message('m-2', unread: true, minute: 1),
        _message('m-3', unread: true, minute: 2),
      ]);

      final separator = find.text(_fr.chatUnreadSeparator(2));
      expect(separator, findsOneWidget);
      expect(
        tester.getTopLeft(separator).dy,
        allOf(
          greaterThan(tester.getTopLeft(find.byKey(const ValueKey('m-1'))).dy),
          lessThan(tester.getTopLeft(find.byKey(const ValueKey('m-2'))).dy),
        ),
      );
    });

    testWidgets(
        'un long fil s\'ouvre SUR le séparateur, hors de vue au départ : '
        'ensureVisible le pose en haut de la liste inversée, les non-lus '
        'dessous', (tester) async {
      // 40 lus puis 30 non-lus : le séparateur est à des écrans du bas, où une
      // liste inversée s'ouvre.
      await _pumpThread(tester, [
        for (var i = 0; i < 40; i++) _message('r-$i', minute: i % 60),
        for (var i = 0; i < 30; i++)
          _message('u-$i', unread: true, minute: i % 60),
      ]);
      await tester.pumpAndSettle();

      final separator = find.text(_fr.chatUnreadSeparator(30));
      expect(separator, findsOneWidget);
      final viewport = tester.getRect(find.byType(ListView));
      final top = tester.getTopLeft(separator).dy;
      expect(top, greaterThanOrEqualTo(viewport.top));
      // Vers le haut de la vue (alignment 0.9 : 1 = le haut d'une liste
      // inversée), pas en bas.
      expect(top, lessThan(viewport.top + viewport.height / 2));
      // Le premier non-lu est juste dessous, visible.
      final firstUnread = tester.getTopLeft(find.byKey(const ValueKey('u-0')));
      expect(firstUnread.dy, greaterThan(top));
      expect(firstUnread.dy, lessThan(viewport.bottom));
      // Le plus récent, lui, n'est plus construit à l'écran.
      expect(find.byKey(const ValueKey('u-29')), findsNothing);
    });

    testWidgets('sans non-lu, aucun séparateur', (tester) async {
      await _pumpThread(tester, [_message('m-1')]);
      expect(find.byKey(const Key('chat_unread_separator')), findsNothing);
    });
  });

  group('La lecture avance', () {
    testWidgets(
        'le fil affiché fait avancer la lecture jusqu\'au plus récent, une '
        'seule fois', (tester) async {
      final sender = _RecordingReadSender();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Drift sous `testWidgets` : tout dans **un seul** `runAsync`. La session
      // est résolue sans délai : le double par défaut répond après une vraie
      // minuterie (~300 ms), qui survivrait au test sous `runAsync` et
      // écrirait dans un `authProvider` déjà jeté.
      await tester.runAsync(() async {
        await _pumpThread(
          tester,
          [
            _message('m-1', unread: true),
            _message('m-2', unread: true, minute: 1),
          ],
          readSender: sender,
          database: db,
          auth: SignedInAuthRepository(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(sender.posted, ['m-2']);
        // La lecture locale est posée — l'outbox la rejouera.
        final pending = await db.groupDao.pendingReads();
        expect(pending.single.messageId, 'm-2');
      });
    });

    testWidgets('tout est lu : rien ne part', (tester) async {
      final sender = _RecordingReadSender();
      await _pumpThread(tester, [_message('m-1')], readSender: sender);
      await tester.pump();
      expect(sender.posted, isEmpty);
    });
  });

  group('Un message qui n\'est pas parti', () {
    testWidgets('il le dit, et le toucher offre Réessayer et Supprimer',
        (tester) async {
      await _pumpThread(tester, [
        _message('c-1', mine: true, delivery: MessageDelivery.failed),
      ]);

      expect(find.text(_fr.chatMessageFailed), findsOneWidget);
      await tester.tap(find.byType(ChatBubble));
      await tester.pumpAndSettle();

      expect(find.text(_fr.chatRetry), findsOneWidget);
      expect(find.text(_fr.chatDiscard), findsOneWidget);
    });

    testWidgets('un message envoyé ne répond pas au toucher', (tester) async {
      await _pumpThread(tester, [_message('m-1', mine: true)]);
      expect(find.text(_fr.chatMessageFailed), findsNothing);
      // Sur le texte de la bulle : son centre géométrique tombe dans le vide
      // de la ligne (bulle alignée à droite), et le toucher n'y prouverait rien.
      await tester.tap(
        find.descendant(
          of: find.byType(ChatBubble),
          matching: find.text('Bonjour'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_fr.chatRetry), findsNothing);
    });
  });

  testWidgets('un message-média (corps nul) le dit, jamais une bulle vide',
      (tester) async {
    await _pumpThread(tester, [_message('m-1', body: null)]);
    expect(find.text(_fr.chatMediaUnsupported), findsOneWidget);
  });

  group('Ce qui ne ment plus', () {
    testWidgets('aucune pastille « en ligne » dans la barre', (tester) async {
      await _pumpThread(tester, [_message('m-1')]);
      final dots = find.descendant(
        of: find.byType(ChatAppBar),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == AppColors.success,
        ),
      );
      expect(dots, findsNothing);
    });

    testWidgets(
        'la barre de saisie : plus d\'emoji inerte, et le trombone et '
        'l\'appareil photo reviennent avec les médias (M4)', (tester) async {
      await _pumpThread(tester, [_message('m-1')]);
      final bar = find.byType(MessageInputBar);
      expect(bar, findsOneWidget);
      expect(
        find.descendant(
          of: bar,
          matching: find.byIcon(Icons.emoji_emotions_outlined),
        ),
        findsNothing,
      );
      // M1b les avait retirés parce qu'inertes ; M4 (#143) les rend utiles.
      expect(
        find.descendant(of: bar, matching: find.byIcon(Icons.attach_file)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: bar,
          matching: find.byIcon(Icons.photo_camera_outlined),
        ),
        findsOneWidget,
      );

      // Le trombone ouvre la feuille des pièces jointes.
      await tester.tap(find.byKey(const Key('m4_attach_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('m4_attach_document')), findsOneWidget);
      expect(find.byKey(const Key('m4_attach_location')), findsOneWidget);
      expect(find.byKey(const Key('m4_attach_contact')), findsOneWidget);
    });

    testWidgets(
        'l\'effectif est celui que sert le serveur, pas un compte du roster '
        'local', (tester) async {
      await _pumpThread(
        tester,
        [_message('m-1')],
        // Le roster local n'a pas (encore) une seule ligne : un compte des
        // lignes dirait « 0 membres ».
        group: _group(memberCount: 12),
      );
      expect(find.text(_fr.groupMembers(12)), findsOneWidget);
      expect(find.text(_fr.groupMembers(0)), findsNothing);
    });
  });

  group('Le retour', () {
    GoRouter router(String initial) => GoRouter(
          initialLocation: initial,
          routes: [
            GoRoute(
              name: AppRoute.home,
              path: '/home',
              builder: (_, state) => Scaffold(
                body: Text('accueil ${state.uri.queryParameters['tab']}'),
              ),
            ),
            GoRoute(
              name: AppRoute.groupChat,
              path: '/group-chat/:id',
              builder: (_, state) =>
                  GroupChatScreen(groupId: state.pathParameters['id']!),
            ),
          ],
        );

    testWidgets(
        'ouvert par une notification (sans pile), le retour mène à la liste '
        'des Échanges', (tester) async {
      await pumpRouter(
        tester,
        router('/group-chat/$_groupId'),
        echanges: InMemoryEchangesRepository(
          groups: {_groupId: _group()},
          threads: {
            _groupId: [_message('m-1')],
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('accueil community'), findsOneWidget);
    });
  });

  group('Les non-lus dans la coquille', () {
    testWidgets('la tuile porte la pastille de sa conversation',
        (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: ConversationTile(
            conversation: ConversationView(
              groupId: _groupId,
              title: 'Chorale Harmonie',
              isDirect: false,
              memberCount: 3,
              canWrite: true,
              unreadCount: 4,
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(UnreadBadge),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('l\'onglet Échanges porte la somme des non-lus',
        (tester) async {
      await pumpScreen(
        tester,
        const HomeShell(),
        auth: SignedInAuthRepository(),
        overrides: [
          calendarRepositoryProvider
              .overrideWithValue(InMemoryCalendarRepository()),
        ],
        echanges: InMemoryEchangesRepository(
          conversations: const [
            ConversationView(
              groupId: 'g-1',
              title: 'Chorale',
              isDirect: false,
              memberCount: 3,
              canWrite: true,
              unreadCount: 2,
            ),
            ConversationView(
              groupId: 'g-2',
              title: 'Jeunesse',
              isDirect: false,
              memberCount: 9,
              canWrite: true,
              unreadCount: 3,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('`/home?tab=community` ouvre la coquille sur Échanges',
        (tester) async {
      await pumpScreen(
        tester,
        const HomeShell(initialTab: HomeTab.community),
        auth: SignedInAuthRepository(),
        overrides: [
          calendarRepositoryProvider
              .overrideWithValue(InMemoryCalendarRepository()),
        ],
      );
      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.current, HomeTab.community);
    });
  });
}
