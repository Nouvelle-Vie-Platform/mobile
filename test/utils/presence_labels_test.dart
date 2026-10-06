/// **« écrit… », « en ligne », « vu à »** (#142, tranche M3) — ce que disent
/// l'en-tête d'un fil et la tuile d'une conversation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maison_du_miracle/data/messaging/messaging_channel.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/utils/presence_labels.dart';

void main() {
  final l = AppLocalizationsFr();
  setUpAll(() => initializeDateFormatting('fr'));

  group('« écrit… »', () {
    test('personne n\'écrit : rien', () {
      expect(typingLabel(l, typers: const [], isDirect: true), isNull);
    });

    test('tête-à-tête : « écrit… », sans nom', () {
      expect(typingLabel(l, typers: const ['u-1'], isDirect: true), 'écrit…');
    });

    test('groupe : le prénom de celui qui écrit', () {
      expect(
        typingLabel(
          l,
          typers: const ['u-1'],
          isDirect: false,
          nameOf: (_) => 'Ama Mensah',
        ),
        'Ama écrit…',
      );
    });

    test('groupe, nom pas encore arrivé : « écrit… », jamais un nom inventé',
        () {
      expect(
        typingLabel(l, typers: const ['u-1'], isDirect: false),
        'écrit…',
      );
    });

    test('groupe, plusieurs : leur nombre', () {
      expect(
        typingLabel(l, typers: const ['u-1', 'u-2'], isDirect: false),
        '2 personnes écrivent…',
      );
    });
  });

  group('« en ligne » / « vu à »', () {
    final now = DateTime(2026, 10, 6, 18);

    MessagingPresenceEvent seen(DateTime at) => MessagingPresenceEvent(
          userId: 'u-1',
          visible: true,
          online: false,
          lastSeenAt: at.toUtc(),
        );

    test('en ligne', () {
      expect(
        presenceLabel(
          l,
          const MessagingPresenceEvent(
            userId: 'u-1',
            visible: true,
            online: true,
          ),
          now: now,
        ),
        'en ligne',
      );
    });

    test('vu aujourd\'hui, hier, ou à une date', () {
      expect(
        presenceLabel(l, seen(DateTime(2026, 10, 6, 14, 5)), now: now),
        'vu aujourd\'hui à 14:05',
      );
      expect(
        presenceLabel(l, seen(DateTime(2026, 10, 5, 9, 30)), now: now),
        'vu hier à 09:30',
      );
      expect(
        presenceLabel(l, seen(DateTime(2026, 10, 1, 20, 0)), now: now),
        startsWith('vu le 1'),
      );
    });

    test('cachée par la réciprocité, ou inconnue : rien', () {
      expect(
        presenceLabel(
          l,
          const MessagingPresenceEvent(
            userId: 'u-1',
            visible: false,
            online: false,
          ),
          now: now,
        ),
        isNull,
      );
      expect(presenceLabel(l, null, now: now), isNull);
      expect(
        presenceLabel(
          l,
          const MessagingPresenceEvent(
            userId: 'u-1',
            visible: true,
            online: false,
          ),
          now: now,
        ),
        isNull,
        reason: '« vu à » perdu au redémarrage du serveur : pas de date '
            'inventée',
      );
    });
  });
}
