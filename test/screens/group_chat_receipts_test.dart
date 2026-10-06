/// **Les coches, « écrit… », « en ligne / vu à » et « Infos du message »**
/// dans le fil (#142, tranche M3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/messaging/messaging_channel.dart';
import 'package:maison_du_miracle/data/messaging/messaging_signals_api.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/data/repositories/receipts_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/receipt_view.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/state/receipts_providers.dart';
import 'package:maison_du_miracle/widgets/chat/chat_app_bar.dart';
import 'package:maison_du_miracle/widgets/chat/receipt_mark.dart';

import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

/// `SignedInAuthRepository` : c'est moi.
const String _me = 'u_1';
const String _peer = 'u-peer';
const String _other = 'u-other';
const String _groupId = 'g-1';
final _fr = AppLocalizationsFr();

GroupDetailView _group({bool direct = false}) => GroupDetailView(
      groupId: _groupId,
      title: direct ? 'Ama Mensah' : 'Chorale Harmonie',
      isDirect: direct,
      memberCount: direct ? 2 : 3,
      canWrite: true,
      members: [
        const GroupMemberView(userId: _me, role: 'member', displayName: 'Jean'),
        const GroupMemberView(
          userId: _peer,
          role: 'member',
          displayName: 'Ama Mensah',
        ),
        if (!direct)
          const GroupMemberView(
            userId: _other,
            role: 'member',
            displayName: 'Kofi Agbeko',
          ),
      ],
    );

GroupMessageView _mine(
  String id, {
  MessageDelivery delivery = MessageDelivery.sent,
  int minute = 0,
}) =>
    GroupMessageView(
      id: id,
      groupId: _groupId,
      body: 'Bonjour',
      origin: messageOriginOf(authorId: _me, isSystem: false),
      mine: true,
      delivery: delivery,
      authorId: _me,
      createdAt: DateTime.utc(2026, 10, 6, 10, minute),
    );

/// Un double des six routes : une présence et des infos de message données.
class _FakeSignals extends InertMessagingSignalsApi {
  _FakeSignals({this.presence, this.recipients = const []});

  final MessagingPresenceEvent? presence;
  final List<MessageRecipientReceipt> recipients;
  final List<String> typingSent = [];

  @override
  Future<MessagingPresenceEvent?> presenceIn(String groupId) async => presence;

  @override
  Future<void> signalTyping(String groupId) async => typingSent.add(groupId);

  @override
  Future<List<MessageRecipientReceipt>> messageReceipts({
    required String groupId,
    required String messageId,
  }) async =>
      recipients;
}

Future<void> _pump(
  WidgetTester tester, {
  required List<GroupMessageView> messages,
  bool direct = false,
  Map<String, ReceiptStatus> receipts = const {},
  MessagingSignalsApi? signals,
}) async {
  await pumpScreen(
    tester,
    const GroupChatScreen(groupId: _groupId),
    auth: SignedInAuthRepository(),
    echanges: InMemoryEchangesRepository(
      groups: {_groupId: _group(direct: direct)},
      threads: {_groupId: messages},
    ),
    receipts: InMemoryReceiptsRepository({_groupId: receipts}),
    signals: signals,
  );
  await tester.pump();
  await tester.pump();
}

String? _subtitle(WidgetTester tester) =>
    tester.widget<ChatAppBar>(find.byType(ChatAppBar)).subtitle;

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GroupChatScreen)));

void main() {
  group('Les coches de mes messages', () {
    testWidgets('✓ envoyé, ✓✓ distribué, ✓✓ bleu lu', (tester) async {
      await _pump(
        tester,
        messages: [
          _mine('m-sent'),
          _mine('m-delivered', minute: 1),
          _mine('m-read', minute: 2),
        ],
        receipts: const {
          'm-delivered': ReceiptStatus.delivered,
          'm-read': ReceiptStatus.read,
        },
      );

      Finder markIn(String id, String key) => find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byKey(Key(key)),
          );
      expect(markIn('m-sent', 'receipt_sent'), findsOneWidget);
      expect(markIn('m-delivered', 'receipt_delivered'), findsOneWidget);
      expect(markIn('m-read', 'receipt_read'), findsOneWidget);
      expect(
        tester.widget<Icon>(markIn('m-read', 'receipt_read')).color,
        kReceiptReadColor,
      );
      expect(
        tester.widget<Icon>(markIn('m-delivered', 'receipt_delivered')).color,
        isNot(kReceiptReadColor),
      );
    });

    testWidgets('un message en cours d\'envoi garde son horloge, sans coche',
        (tester) async {
      await _pump(
        tester,
        messages: [_mine('m-pending', delivery: MessageDelivery.sending)],
      );

      expect(find.byType(ReceiptMark), findsNothing);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });
  });

  group('« écrit… »', () {
    testWidgets(
        'dans un groupe, l\'en-tête dit qui écrit, puis revient à l\'effectif '
        'quand le signal expire', (tester) async {
      await _pump(tester, messages: [_mine('m-1')]);
      expect(_subtitle(tester), _fr.groupMembers(3));

      _container(tester)
          .read(messagingEphemeralStoreProvider)
          .typingStarted(_groupId, _peer);
      await tester.pump();
      expect(_subtitle(tester), 'Ama écrit…');

      await tester.pump(const Duration(seconds: 6));
      expect(_subtitle(tester), _fr.groupMembers(3));
    });

    testWidgets('écrire dans le champ envoie « j\'écris », à intervalle borné',
        (tester) async {
      final signals = _FakeSignals();
      await _pump(tester, messages: [_mine('m-1')], signals: signals);

      await tester.enterText(find.byType(TextField), 'B');
      await tester.enterText(find.byType(TextField), 'Bo');
      await tester.pump();

      expect(signals.typingSent, [_groupId]);
    });
  });

  group('« en ligne / vu à »', () {
    testWidgets('tête-à-tête : la présence lue à l\'ouverture', (tester) async {
      await _pump(
        tester,
        direct: true,
        messages: [_mine('m-1')],
        signals: _FakeSignals(
          presence: const MessagingPresenceEvent(
            userId: _peer,
            visible: true,
            online: true,
          ),
        ),
      );

      expect(_subtitle(tester), 'en ligne');
    });

    testWidgets('tête-à-tête : « vu à » quand l\'autre est parti',
        (tester) async {
      final seen = DateTime.now().subtract(const Duration(minutes: 1));
      await _pump(
        tester,
        direct: true,
        messages: [_mine('m-1')],
        signals: _FakeSignals(
          presence: MessagingPresenceEvent(
            userId: _peer,
            visible: true,
            online: false,
            lastSeenAt: seen.toUtc(),
          ),
        ),
      );

      expect(_subtitle(tester), startsWith('vu '));
    });

    testWidgets('présence cachée par la réciprocité : rien sous le nom',
        (tester) async {
      await _pump(
        tester,
        direct: true,
        messages: [_mine('m-1')],
        signals: _FakeSignals(
          presence: const MessagingPresenceEvent(
            userId: _peer,
            visible: false,
            online: false,
          ),
        ),
      );

      expect(_subtitle(tester), isNull);
    });

    testWidgets('« écrit… » l\'emporte sur la présence', (tester) async {
      await _pump(
        tester,
        direct: true,
        messages: [_mine('m-1')],
        signals: _FakeSignals(
          presence: const MessagingPresenceEvent(
            userId: _peer,
            visible: true,
            online: true,
          ),
        ),
      );

      _container(tester)
          .read(messagingEphemeralStoreProvider)
          .typingStarted(_groupId, _peer);
      await tester.pump();

      expect(_subtitle(tester), 'écrit…');
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('« Infos du message »', () {
    testWidgets(
        'appui long sur un de mes messages → Infos : qui a lu, qui a reçu, '
        'qui attend', (tester) async {
      await _pump(
        tester,
        messages: [_mine('m-1')],
        signals: _FakeSignals(
          recipients: [
            MessageRecipientReceipt(
              userId: _peer,
              deliveredAt: DateTime.now().toUtc(),
              readAt: DateTime.now().toUtc(),
            ),
            const MessageRecipientReceipt(userId: _other),
          ],
        ),
      );

      await tester.longPress(find.byKey(const ValueKey('m-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('message_action_info')));
      await tester.pumpAndSettle();

      expect(find.text(_fr.messageInfoTitle), findsOneWidget);
      expect(find.text(_fr.messageInfoReadBy), findsOneWidget);
      expect(find.text('Ama Mensah'), findsWidgets);
      expect(find.text(_fr.messageInfoPending), findsOneWidget);
      expect(find.text('Kofi Agbeko'), findsOneWidget);
      expect(find.text(_fr.messageInfoDeliveredTo), findsNothing);
    });

    testWidgets('un message qui n\'est pas à moi n\'offre pas « Infos »',
        (tester) async {
      await _pump(
        tester,
        messages: [
          GroupMessageView(
            id: 'm-peer',
            groupId: _groupId,
            body: 'Amen',
            origin: messageOriginOf(authorId: _peer, isSystem: false),
            mine: false,
            delivery: MessageDelivery.sent,
            authorId: _peer,
            authorName: 'Ama Mensah',
            createdAt: DateTime.utc(2026, 10, 6, 10),
          ),
        ],
      );

      await tester.longPress(find.byKey(const ValueKey('m-peer')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message_action_info')), findsNothing);
    });
  });
}
