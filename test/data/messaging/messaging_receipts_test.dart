/// **Accusés, frappe et présence côté données** (#142, tranche M3) : le
/// décodage des trois événements neufs du canal, le rangement de l'accusé par
/// le registre, la confirmation de distribution (une fois, par lot, sans les
/// miens), et l'état éphémère qui s'efface seul.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/delivery_acknowledger.dart';
import 'package:maison_du_miracle/data/messaging/messaging_channel.dart';
import 'package:maison_du_miracle/data/messaging/messaging_ephemeral.dart';
import 'package:maison_du_miracle/data/messaging/messaging_signals_api.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/repositories/receipts_repository.dart';
import 'package:maison_du_miracle/models/receipt_view.dart';

import '../local/local_database_fixtures.dart';
import '../../helpers/sync_fixtures.dart';

const String _channel = 'users/$kMeId';

String _frame(Map<String, Object?> payload) =>
    jsonEncode({'channel': _channel, 'payload': payload});

/// Un double qui retient les lots confirmés, et répond ce qu'on lui dit.
class _RecordingApi extends InertMessagingSignalsApi {
  _RecordingApi([this.outcome = DeliveryOutcome.confirmed]);

  DeliveryOutcome outcome;
  final List<List<String>> batches = [];

  @override
  Future<DeliveryOutcome> confirmDeliveries(List<String> messageIds) async {
    batches.add(List.of(messageIds));
    return outcome;
  }
}

void main() {
  group('Le canal porte trois événements neufs', () {
    test('receipt.updated → une ligne message_receipts', () {
      final event = decodeMessagingData(
        _frame({
          'type': 'receipt.updated',
          'receipt': {
            'id': 'm-1',
            'groupId': kGroupId,
            'deliveredAt': '2026-10-06T10:00:00.000Z',
            'readAt': null,
            'updatedAt': '2026-10-06T10:00:00.000Z',
          },
        }),
        channel: _channel,
      );

      expect(event, isA<MessagingRowEvent>());
      final row = event! as MessagingRowEvent;
      expect(row.collection, SyncCollectionKey.messageReceipts);
      expect(row.row['id'], 'm-1');
      expect(row.groupId, kGroupId);
    });

    test('typing → un signal éphémère, sans ligne', () {
      final event = decodeMessagingData(
        _frame({
          'type': 'typing',
          'typing': {'groupId': kGroupId, 'userId': kPeerId, 'at': 'x'},
        }),
        channel: _channel,
      );

      expect(event, isA<MessagingTypingEvent>());
      final typing = event! as MessagingTypingEvent;
      expect(typing.groupId, kGroupId);
      expect(typing.userId, kPeerId);
    });

    test('presence.changed → la présence, « vu à » en UTC', () {
      final event = decodeMessagingData(
        _frame({
          'type': 'presence.changed',
          'presence': {
            'userId': kPeerId,
            'visible': true,
            'online': false,
            'lastSeenAt': '2026-10-06T14:05:00.000+00:00',
          },
        }),
        channel: _channel,
      );

      final presence = event! as MessagingPresenceEvent;
      expect(presence.visible, isTrue);
      expect(presence.online, isFalse);
      expect(presence.lastSeenAt, DateTime.utc(2026, 10, 6, 14, 5));
    });

    test('une présence cachée reste cachée', () {
      final presence = MessagingPresenceEvent.fromJson({
        'userId': kPeerId,
        'visible': false,
        'online': false,
        'lastSeenAt': null,
      })!;
      expect(presence.visible, isFalse);
      expect(presence.lastSeenAt, isNull);
    });

    test('un signal mal formé est ignoré', () {
      expect(
        decodeMessagingData(
          _frame({
            'type': 'typing',
            'typing': {'groupId': kGroupId},
          }),
          channel: _channel,
        ),
        isNull,
      );
    });
  });

  group('L\'accusé se range par le registre, et se lit en coches', () {
    late AppDatabase db;
    setUp(() => db = openTestDatabase());
    tearDown(() => db.close());

    test('aucune ligne → ✓ ; distribué → ✓✓ ; lu → ✓✓ bleu', () async {
      final writer = MessagingStoreWriter(db);
      final repository = StoreReceiptsRepository(db.receiptsDao);

      await writer.store(SyncCollectionKey.messageReceipts, {
        'id': 'm-delivered',
        'groupId': kGroupId,
        'deliveredAt': '2026-10-06T10:00:00.000Z',
        'readAt': null,
        'updatedAt': '2026-10-06T10:00:00.000Z',
      });
      await writer.store(SyncCollectionKey.messageReceipts, {
        'id': 'm-read',
        'groupId': kGroupId,
        'deliveredAt': '2026-10-06T10:00:00.000Z',
        'readAt': '2026-10-06T10:01:00.000Z',
        'updatedAt': '2026-10-06T10:01:00.000Z',
      });

      final receipts = await repository.receiptsOf(kGroupId).first;
      expect(receipts['m-delivered'], ReceiptStatus.delivered);
      expect(receipts['m-read'], ReceiptStatus.read);
      expect(receipts['m-sent'], isNull, reason: 'sans ligne : ✓');
      expect(
        receiptStatusOf(deliveredAt: null, readAt: null),
        ReceiptStatus.sent,
      );
    });

    test('une nouvelle ligne remplace l\'ancienne (✓✓ → bleu)', () async {
      final writer = MessagingStoreWriter(db);
      Map<String, Object?> row(String? readAt) => {
            'id': 'm-1',
            'groupId': kGroupId,
            'deliveredAt': '2026-10-06T10:00:00.000Z',
            'readAt': readAt,
            'updatedAt': '2026-10-06T10:00:00.000Z',
          };
      await writer.store(SyncCollectionKey.messageReceipts, row(null));
      await writer.store(
        SyncCollectionKey.messageReceipts,
        row('2026-10-06T10:05:00.000Z'),
      );

      final receipts = await StoreReceiptsRepository(db.receiptsDao)
          .receiptsOf(kGroupId)
          .first;
      expect(receipts['m-1'], ReceiptStatus.read);
    });
  });

  group('La confirmation de distribution', () {
    late AppDatabase db;
    late MessagingStoreWriter writer;
    setUp(() {
      db = openTestDatabase();
      writer = MessagingStoreWriter(db);
    });
    tearDown(() => db.close());

    Future<void> seed() async {
      await writer.store(SyncCollectionKey.groups, myGroupPayload);
      for (final message in const [
        memberMessagePayload,
        myMessagePayload,
        systemMessagePayload,
        removedAuthorMessagePayload,
      ]) {
        await writer.store(SyncCollectionKey.groupMessages, message);
      }
    }

    DeliveryAcknowledger acknowledger(MessagingSignalsApi api) =>
        DeliveryAcknowledger(
          me: kMeId,
          dao: db.receiptsDao,
          api: api,
          now: () => DateTime.utc(2026, 9, 4),
        );

    test(
        'confirme les messages des autres, et eux seuls — ni les miens, ni le '
        'serveur, ni un auteur retiré', () async {
      await seed();
      final api = _RecordingApi();

      await acknowledger(api).flush();

      expect(api.batches, [
        [memberMessagePayload['id']],
      ]);
    });

    test('une fois confirmé, jamais renvoyé', () async {
      await seed();
      final api = _RecordingApi();
      final ack = acknowledger(api);

      await ack.flush();
      await ack.flush();

      expect(api.batches, hasLength(1));
    });

    test('injoignable : rien n\'est noté, le lot repart au passage suivant',
        () async {
      await seed();
      final api = _RecordingApi(DeliveryOutcome.unreachable);
      final ack = acknowledger(api);

      await ack.flush();
      api.outcome = DeliveryOutcome.confirmed;
      await ack.flush();

      expect(api.batches, hasLength(2));
      expect(api.batches.last, [memberMessagePayload['id']]);
    });

    test('refusé (4xx) : noté quand même, pour ne pas tourner en boucle',
        () async {
      await seed();
      final api = _RecordingApi(DeliveryOutcome.rejected);
      final ack = acknowledger(api);

      await ack.flush();
      await ack.flush();

      expect(api.batches, hasLength(1));
    });

    test('au-delà de l\'horizon, l\'historique ne part pas', () async {
      await seed();
      final api = _RecordingApi();

      await DeliveryAcknowledger(
        me: kMeId,
        dao: db.receiptsDao,
        api: api,
        now: () => DateTime.utc(2026, 12, 1),
      ).flush();

      expect(api.batches, isEmpty);
    });
  });

  group('L\'état éphémère', () {
    test('« écrit… » s\'efface seul', () async {
      final store = MessagingEphemeralStore(
        typingVisibleFor: const Duration(milliseconds: 40),
      );
      addTearDown(store.dispose);

      store.apply(
        const MessagingTypingEvent(groupId: kGroupId, userId: kPeerId),
      );
      expect(store.state.typingIn(kGroupId, me: kMeId), [kPeerId]);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(store.state.typingIn(kGroupId, me: kMeId), isEmpty);
    });

    test('un nouveau signal prolonge « écrit… »', () async {
      final store = MessagingEphemeralStore(
        typingVisibleFor: const Duration(milliseconds: 60),
      );
      addTearDown(store.dispose);

      store.typingStarted(kGroupId, kPeerId);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      store.typingStarted(kGroupId, kPeerId);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(store.state.typingIn(kGroupId), [kPeerId]);
    });

    test('un message reçu de la même personne éteint sa frappe', () {
      final store = MessagingEphemeralStore();
      addTearDown(store.dispose);
      store.typingStarted(kGroupId, kPeerId);

      store.apply(
        const MessagingRowEvent(
          type: 'message.created',
          collection: SyncCollectionKey.groupMessages,
          row: memberMessagePayload,
        ),
      );

      expect(store.state.typingIn(kGroupId), isEmpty);
    });

    test('je ne me vois pas écrire', () {
      final store = MessagingEphemeralStore();
      addTearDown(store.dispose);
      store.typingStarted(kGroupId, kMeId);
      expect(store.state.typingIn(kGroupId, me: kMeId), isEmpty);
    });

    test('la présence est remplacée, puis oubliée quand mes réglages changent',
        () {
      final store = MessagingEphemeralStore();
      addTearDown(store.dispose);

      store.apply(
        const MessagingPresenceEvent(
          userId: kPeerId,
          visible: true,
          online: true,
        ),
      );
      expect(store.state.presence[kPeerId]!.online, isTrue);

      store.forgetPresence();
      expect(store.state.presence, isEmpty);
    });
  });

  group('« j\'écris » part à intervalle borné', () {
    test('au plus un signal par intervalle, jamais pour un champ vide', () {
      var now = DateTime.utc(2026, 10, 6, 10);
      var sent = 0;
      final signaler = TypingSignaler(
        send: () async => sent++,
        now: () => now,
      );

      signaler.onTextChanged('B');
      signaler.onTextChanged('Bo');
      now = now.add(const Duration(seconds: 1));
      signaler.onTextChanged('Bon');
      expect(sent, 1);

      now = now.add(kTypingSendInterval);
      signaler.onTextChanged('Bonj');
      expect(sent, 2);

      now = now.add(kTypingSendInterval);
      signaler.onTextChanged('   ');
      expect(sent, 2);
    });

    test('après l\'envoi, la frappe suivante signale aussitôt', () {
      var sent = 0;
      final signaler = TypingSignaler(
        send: () async => sent++,
        now: () => DateTime.utc(2026, 10, 6, 10),
      );
      signaler.onTextChanged('Amen');
      signaler.reset();
      signaler.onTextChanged('A');
      expect(sent, 2);
    });
  });
}
