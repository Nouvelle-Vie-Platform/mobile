import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/group_dao.dart';
import 'package:maison_du_miracle/data/push/conversation_notification.dart';

import 'notification_doubles.dart';

/// **La règle de la notification d'une conversation** (M5) — une fonction pure,
/// vérifiée sans canal de greffon : ce qui s'affiche, ligne par ligne, et ce
/// que l'aperçu masqué en retire.
void main() {
  final t0 = DateTime.utc(2026, 9, 3, 10, 30);

  DigestMessage message(
    String id,
    String? body, {
    String? authorId = 'u-ama',
    String? authorName = 'Ama',
    int minutes = 0,
  }) =>
      DigestMessage(
        id: id,
        body: body,
        authorId: authorId,
        authorName: authorName,
        createdAt: t0.add(Duration(minutes: minutes)),
      );

  ConversationDigest groupDigest(List<DigestMessage> messages, {int? unread}) =>
      ConversationDigest(
        groupId: 'grp-1',
        groupName: 'Chorale Harmonie',
        isDirect: false,
        unreadCount: unread ?? messages.length,
        messages: messages,
      );

  ConversationDigest direct(List<DigestMessage> messages, {String? peer}) =>
      ConversationDigest(
        groupId: 'dm-1',
        groupName: 'direct:019a…',
        isDirect: true,
        peerName: peer,
        unreadCount: messages.length,
        messages: messages,
      );

  group('Une conversation de groupe', () {
    test('empile les non-lus avec leurs auteurs, sous le nom du groupe', () {
      final n = conversationNotification(
        groupDigest([
          message('m1', 'Répétition samedi'),
          message('m2', 'Amen', authorId: 'u-kofi', authorName: 'Kofi'),
        ], unread: 5),
        showPreview: true,
        texts: kTestNotificationTexts,
      )!;

      expect(n.title, 'Chorale Harmonie');
      expect(n.isGroup, isTrue);
      expect(n.groupId, 'grp-1');
      expect(n.lines.map((l) => (l.authorName, l.text)), [
        ('Ama', 'Répétition samedi'),
        ('Kofi', 'Amen'),
      ]);
      // Le compteur est celui de **tous** mes non-lus, pas des lignes montrées.
      expect(n.unreadCount, 5);
      // Le corps d'une ligne (écran verrouillé, anciens appareils) : le dernier
      // message, préfixé de son auteur.
      expect(n.body, 'Kofi : Amen');
      expect(n.id, conversationNotificationId('grp-1'));
    });

    test('un auteur retiré est dit comme dans le fil, sans nom inventé', () {
      final n = conversationNotification(
        groupDigest([message('m1', 'Paix', authorId: null, authorName: null)]),
        showPreview: true,
        texts: kTestNotificationTexts,
      )!;

      expect(n.lines.single.authorKey, 'removed');
      expect(n.lines.single.authorName, isNull);
      expect(n.body, 'Paix');
    });

    test('un média se dit « Pièce jointe », jamais par un vide', () {
      final n = conversationNotification(
        groupDigest([message('m1', null)]),
        showPreview: true,
        texts: kTestNotificationTexts,
      )!;

      expect(n.lines.single.text, 'Pièce jointe');
    });

    test('un groupe que le magasin ne nomme pas ne s\'annonce pas', () {
      final unnamed = ConversationDigest(
        groupId: 'g',
        groupName: '  ',
        isDirect: false,
        unreadCount: 1,
        messages: [message('m1', 'Amen')],
      );

      expect(
        conversationNotification(
          unnamed,
          showPreview: true,
          texts: kTestNotificationTexts,
        ),
        isNull,
      );
    });

    test('rien de non lu, rien à annoncer', () {
      expect(
        conversationNotification(
          groupDigest(const [], unread: 0),
          showPreview: true,
          texts: kTestNotificationTexts,
        ),
        isNull,
      );
    });
  });

  group('Un tête-à-tête', () {
    test('porte le nom de la personne, et chaque ligne est d\'elle', () {
      final n = conversationNotification(
        direct([message('m1', 'Bonsoir')], peer: 'Estelle Adjo'),
        showPreview: true,
        texts: kTestNotificationTexts,
      )!;

      expect(n.title, 'Estelle Adjo');
      expect(n.isGroup, isFalse);
      expect(n.lines.single.authorName, 'Estelle Adjo');
      // Pas de préfixe : le titre dit déjà qui écrit.
      expect(n.body, 'Bonsoir');
    });

    test('sans profil, il retombe sur le nom du groupe', () {
      final n = conversationNotification(
        direct([message('m1', 'Paix')]),
        showPreview: true,
        texts: kTestNotificationTexts,
      )!;

      expect(n.title, 'direct:019a…');
    });
  });

  group('L\'aperçu masqué', () {
    test('un groupe : une seule ligne, « Nouveau message de Ama »', () {
      final n = conversationNotification(
        groupDigest([
          message('m1', 'Secret de prière'),
          message('m2', 'Autre secret', minutes: 1),
        ]),
        showPreview: false,
        texts: kTestNotificationTexts,
      )!;

      expect(n.lines, hasLength(1));
      expect(n.lines.single.text, 'Nouveau message de Ama');
      expect(n.body, 'Nouveau message de Ama');
      // Rien du texte, nulle part.
      expect(n.body, isNot(contains('secret')));
      expect(n.lines.single.text, isNot(contains('secret')));
      expect(n.title, 'Chorale Harmonie');
    });

    test('un tête-à-tête : « Nouveau message »', () {
      final n = conversationNotification(
        direct([message('m1', 'Secret')], peer: 'Ama'),
        showPreview: false,
        texts: kTestNotificationTexts,
      )!;

      expect(n.lines.single.text, 'Nouveau message');
      expect(n.title, 'Ama');
    });

    test('un auteur sans nom : « Nouveau message »', () {
      final n = conversationNotification(
        groupDigest(
            [message('m1', 'Secret', authorId: null, authorName: null)]),
        showPreview: false,
        texts: kTestNotificationTexts,
      )!;

      expect(n.lines.single.text, 'Nouveau message');
    });
  });

  group('Le résumé', () {
    final now = DateTime.utc(2026, 9, 10);

    ConversationRecord record(
      String id,
      int unread, {
      bool forever = false,
      DateTime? until,
    }) =>
        ConversationRecord(
          groupId: id,
          groupName: 'Groupe $id',
          isDirect: false,
          memberCount: 3,
          postPolicy: 'all',
          isWriteLocked: false,
          isActive: true,
          myRole: 'member',
          unreadCount: unread,
          mutedForever: forever,
          mutedUntil: until,
        );

    test('compte les non-lus et les discussions, hors sourdine', () {
      final summary = notificationSummary(
        [
          record('a', 3),
          record('b', 2),
          record('c', 0),
          record('d', 9, forever: true),
          record('e', 4, until: now.add(const Duration(hours: 1))),
          // Une sourdine échue n'en est plus une.
          record('f', 1, until: now.subtract(const Duration(hours: 1))),
        ],
        texts: kTestNotificationTexts,
        now: now,
      )!;

      expect(summary.totalUnread, 6);
      expect(summary.conversations, 3);
      expect(summary.title, '6 nouveaux messages');
      expect(summary.text, 'dans 3 discussions');
      expect(summary.lines, ['Groupe a', 'Groupe b', 'Groupe f']);
    });

    test('rien à coiffer : pas de résumé', () {
      expect(
        notificationSummary(
          [record('a', 0), record('b', 4, forever: true)],
          texts: kTestNotificationTexts,
          now: now,
        ),
        isNull,
      );
    });
  });
}
