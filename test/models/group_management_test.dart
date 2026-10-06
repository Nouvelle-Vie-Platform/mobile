/// **Les droits d'un groupe, et la recherche du sélecteur** (#145).
///
/// `GroupRights` est le miroir des gardes du serveur (ADR-0009) : un geste
/// offert à l'écran doit être un geste accepté. Chaque ligne de la table de son
/// en-tête est vérifiée ici.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/group_management.dart';

GroupRights _rights(
  String? role, {
  bool direct = false,
  String policy = 'invite_only',
  bool active = true,
}) =>
    GroupRights(
      myRole: role,
      isDirect: direct,
      joinPolicy: policy,
      isActive: active,
    );

void main() {
  group('Rejoindre et demander, selon la politique', () {
    test('ouvert : on rejoint, on ne demande pas', () {
      final r = _rights(null, policy: 'open');
      expect(r.canJoin, isTrue);
      expect(r.canRequestToJoin, isFalse);
    });

    test('sur demande : on demande, on ne rejoint pas', () {
      final r = _rights(null, policy: 'request');
      expect(r.canJoin, isFalse);
      expect(r.canRequestToJoin, isTrue);
    });

    test('sur invitation : ni l\'un ni l\'autre', () {
      final r = _rights(null);
      expect(r.canJoin, isFalse);
      expect(r.canRequestToJoin, isFalse);
    });

    test('déjà membre, ou groupe désactivé : rien à rejoindre', () {
      expect(_rights('member', policy: 'open').canJoin, isFalse);
      expect(_rights(null, policy: 'open', active: false).canJoin, isFalse);
    });
  });

  group('Quitter', () {
    test('tout membre quitte un groupe', () {
      for (final role in ['member', 'moderator', 'leader']) {
        expect(_rights(role).canLeave, isTrue, reason: role);
      }
    });

    test('on ne quitte pas un tête-à-tête', () {
      expect(_rights('member', direct: true).canLeave, isFalse);
    });

    test('un non-membre n\'a rien à quitter', () {
      expect(_rights(null).canLeave, isFalse);
    });
  });

  group('Administrer (ADR-0009)', () {
    test('un simple membre n\'administre rien', () {
      final r = _rights('member');
      expect(r.canAddMembers, isFalse);
      expect(r.canDecideRequests, isFalse);
      expect(r.canRemove(targetRole: 'member', targetIsMe: false), isFalse);
      expect(
        r.canChangeRole(targetRole: 'member', targetIsMe: false),
        isFalse,
      );
    });

    test('un modérateur ajoute, retire et décide — mais ne nomme pas', () {
      final r = _rights('moderator');
      expect(r.canAddMembers, isTrue);
      expect(r.canDecideRequests, isTrue);
      expect(r.canRemove(targetRole: 'member', targetIsMe: false), isTrue);
      expect(r.canRemove(targetRole: 'moderator', targetIsMe: false), isTrue);
      expect(
        r.canChangeRole(targetRole: 'member', targetIsMe: false),
        isFalse,
      );
    });

    test('l\'animateur nomme et retire les modérateurs', () {
      final r = _rights('leader');
      expect(r.canChangeRole(targetRole: 'member', targetIsMe: false), isTrue);
      expect(
        r.canChangeRole(targetRole: 'moderator', targetIsMe: false),
        isTrue,
      );
    });

    test('personne ne touche l\'animateur, ni soi-même', () {
      for (final role in ['moderator', 'leader']) {
        final r = _rights(role);
        expect(r.canRemove(targetRole: 'leader', targetIsMe: false), isFalse);
        expect(
          r.canChangeRole(targetRole: 'leader', targetIsMe: false),
          isFalse,
        );
        expect(r.canRemove(targetRole: role, targetIsMe: true), isFalse);
      }
    });

    test('un tête-à-tête n\'a aucune administration', () {
      final r = _rights('leader', direct: true);
      expect(r.isAdmin, isFalse);
      expect(r.canAddMembers, isFalse);
    });

    test('un groupe désactivé ne s\'administre plus', () {
      expect(_rights('leader', active: false).canAddMembers, isFalse);
    });
  });

  group('La recherche du sélecteur', () {
    const contacts = [
      ContactView(userId: 'a', displayName: 'Élodie Amavi'),
      ContactView(userId: 'b', displayName: 'Kossi Mensah'),
      ContactView(userId: 'c'),
    ];

    test('vide : tout le monde', () {
      expect(searchContacts(contacts, '  '), contacts);
    });

    test('sans casse ni accent', () {
      expect(searchContacts(contacts, 'elo').map((c) => c.userId), ['a']);
      expect(searchContacts(contacts, 'MENS').map((c) => c.userId), ['b']);
    });

    test('un contact sans nom ne correspond à aucune recherche', () {
      expect(searchContacts(contacts, 'a').map((c) => c.userId), ['a', 'b']);
    });

    test('les lettres éwé se replient aussi', () {
      expect(foldForSearch('Ɖɔ'), 'do');
    });
  });
}
