import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/push/push_wake.dart';

/// **La lecture d'une charge utile de réveil**, et surtout ce qu'elle refuse de
/// lire.
///
/// Aucun canal de greffon n'est touché ici : `readPushWake` ne connaît ni Firebase
/// ni Drift. C'est la démonstration de la couture — le vocabulaire de réveil se
/// vérifie sans transport.
void main() {
  group('Un réveil de groupe', () {
    test('se lit sur ses trois clés', () {
      final wake = readPushWake(const {
        'type': 'group_message',
        'groupId': 'grp-1',
        'messageId': 'msg-1',
      });

      expect(
        wake,
        const GroupMessageWake(groupId: 'grp-1', messageId: 'msg-1'),
      );
    });

    test('nomme les quatre collections dont la notification est faite', () {
      const wake = GroupMessageWake(groupId: 'g', messageId: 'm');

      // Chacune porte un morceau : le texte (`group_messages`), le nom de l'auteur
      // (`profiles`), le nom du fil (`groups`) et le fait que la conversation est
      // mienne (`group_members`, règle 1 de `GroupDao`).
      expect(wake.collections, {
        SyncCollectionKey.profiles,
        SyncCollectionKey.groups,
        SyncCollectionKey.groupMembers,
        SyncCollectionKey.groupMessages,
      });

      // Et pas la cinquième : une demande d'adhésion n'entre dans aucune
      // notification de message, et un réveil n'a pas à payer un tirage dont il ne
      // lira rien.
      expect(
        wake.collections,
        isNot(contains(SyncCollectionKey.groupJoinRequests)),
      );
    });

    test('un identifiant manquant ou vide ne se devine pas', () {
      expect(
        readPushWake(const {'type': 'group_message', 'groupId': 'g'}),
        isNull,
      );
      expect(
        readPushWake(
          const {'type': 'group_message', 'groupId': '  ', 'messageId': 'm'},
        ),
        isNull,
      );
    });
  });

  group('Un nudge de synchronisation', () {
    test('ne nomme que sa collection', () {
      final wake = readPushWake(const {
        'type': 'sync_nudge',
        'collection': 'announcements',
      });

      expect(wake, const SyncNudgeWake('announcements'));
      expect(wake!.collections, {'announcements'});
    });

    test('sans collection, il n\'y a rien à tirer', () {
      expect(readPushWake(const {'type': 'sync_nudge'}), isNull);
    });
  });

  group('Ce qui n\'est pas un réveil silencieux connu', () {
    test('un type inconnu est ignoré, jamais rabattu sur un autre réveil', () {
      // La charge utile d'une **notification visible** (annonce, changement
      // d'événement) : c'est le système qui la dessine, il n'y a rien à faire
      // d'ici. Un repli sur un réveil de substitution serait la faute de
      // `destinationKind` (#82) — mieux vaut muet que faux.
      expect(
        readPushWake(const {
          'type': 'announcement_published',
          'notificationId': 'n-1',
          'subjectType': 'announcement',
          'subjectId': 'a-1',
        }),
        isNull,
      );
      expect(readPushWake(const {}), isNull);
    });

    test('une valeur qui n\'est pas une chaîne ne passe pas', () {
      // FCM ne transporte que des chaînes dans `data`. Un entier ou une carte y
      // arrive d'un intermédiaire, pas du serveur.
      expect(
        readPushWake(const {
          'type': 'group_message',
          'groupId': 42,
          'messageId': 'm',
        }),
        isNull,
      );
    });
  });

  group('Le contenu ne peut pas entrer — et c\'est structurel', () {
    test('un corps glissé dans la charge utile n\'a aucun champ où atterrir',
        () {
      // **L'assertion qui défend ADR-0006 au plus bas niveau.** Le serveur n'envoie
      // jamais de contenu, mais un intermédiaire — ou quelqu'un qui pousserait sur
      // un jeton volé — pourrait. `PushWake` n'a aucun champ de texte : il n'y a
      // donc rien à peindre, même par accident, et le handler ne peut pas se mettre
      // à lire le push au lieu du magasin.
      final wake = readPushWake(const {
        'type': 'group_message',
        'groupId': 'grp-1',
        'messageId': 'msg-1',
        'body': 'TEXTE VENU DU PUSH',
        'title': 'TITRE VENU DU PUSH',
        'authorName': 'NOM VENU DU PUSH',
      });

      expect(wake, isA<GroupMessageWake>());
      // Rien de la charge utile ne survit, hormis le type et les deux
      // identifiants : `toString()` est la seule surface du type, et elle ne porte
      // que ce qui a été retenu.
      expect(wake.toString(), 'GroupMessageWake(grp-1, msg-1)');
      expect(wake.toString(), isNot(contains('PUSH')));
    });
  });
}
