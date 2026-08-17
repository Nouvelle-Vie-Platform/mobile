// Les règles d'écriture d'un groupe, décidées **à la lecture** sur la
// [Conversation] : diffusion (`post_policy = admins`), verrou d'écriture
// temporaire, désactivation, appartenance. Un confort d'affichage — le serveur
// revérifie —, mais qui doit choisir le bon bandeau et masquer le composeur au
// bon moment.

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/models.dart';

Conversation _group({
  GroupRole? role,
  GroupPostPolicy postPolicy = GroupPostPolicy.all,
  bool isWriteLocked = false,
  bool isActive = true,
}) =>
    Conversation(
      id: 'g1',
      kind: ConversationKind.group,
      name: 'Chorale',
      lastMessagePreview: '',
      time: '',
      role: role,
      postPolicy: postPolicy,
      isWriteLocked: isWriteLocked,
      isActive: isActive,
    );

void main() {
  group('canPost', () {
    test('un membre écrit en discussion libre', () {
      expect(_group(role: GroupRole.member).canPost, isTrue);
    });

    test('en diffusion, seuls les admins écrivent', () {
      expect(
        _group(role: GroupRole.member, postPolicy: GroupPostPolicy.admins)
            .canPost,
        isFalse,
      );
      expect(
        _group(role: GroupRole.moderator, postPolicy: GroupPostPolicy.admins)
            .canPost,
        isTrue,
      );
      expect(
        _group(role: GroupRole.leader, postPolicy: GroupPostPolicy.admins)
            .canPost,
        isTrue,
      );
    });

    test('sous verrou, seuls les admins écrivent — quel que soit post_policy',
        () {
      expect(
          _group(role: GroupRole.member, isWriteLocked: true).canPost, isFalse);
      expect(
          _group(role: GroupRole.leader, isWriteLocked: true).canPost, isTrue);
    });

    test('un groupe désactivé est en lecture seule pour tous', () {
      expect(_group(role: GroupRole.leader, isActive: false).canPost, isFalse);
    });

    test('un non-membre n\'écrit pas', () {
      expect(_group(role: null).canPost, isFalse);
    });

    test('une discussion directe est toujours ouverte', () {
      const dm = Conversation(
        id: 'dm',
        kind: ConversationKind.direct,
        name: 'Jean',
        lastMessagePreview: '',
        time: '',
      );
      expect(dm.canPost, isTrue);
    });
  });

  group('readOnlyReason — choisit le bandeau', () {
    test('diffusion', () {
      expect(
        _group(role: GroupRole.member, postPolicy: GroupPostPolicy.admins)
            .readOnlyReason,
        GroupReadOnlyReason.broadcast,
      );
    });

    test('verrou (prioritaire sur la diffusion)', () {
      expect(
        _group(
          role: GroupRole.member,
          postPolicy: GroupPostPolicy.admins,
          isWriteLocked: true,
        ).readOnlyReason,
        GroupReadOnlyReason.writeLocked,
      );
    });

    test('désactivation (prioritaire sur tout)', () {
      expect(
        _group(role: GroupRole.leader, isActive: false).readOnlyReason,
        GroupReadOnlyReason.deactivated,
      );
    });

    test('null quand je peux écrire', () {
      expect(_group(role: GroupRole.member).readOnlyReason, isNull);
    });
  });
}
