import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/utils/event_time.dart';

/// Évènement d'essai : dimanche 26 juillet 2026, 15 h → 17 h heure de Lomé
/// (Lomé étant à UTC+0, l'heure murale togolaise est aussi l'heure UTC).
ChurchEvent _event({
  String timezone = 'Africa/Lome',
  DateTime? startsAt,
  DateTime? endsAt,
}) =>
    ChurchEvent(
      id: 'evt-1',
      startsAt: startsAt ?? DateTime.utc(2026, 7, 26, 15),
      endsAt: endsAt ?? DateTime.utc(2026, 7, 26, 17),
      timezone: timezone,
      title: const {'fr': 'Culte de Gloire'},
    );

void main() {
  // Hors widget, `flutter_localizations` n'a pas chargé les symboles d'`intl`.
  setUpAll(initializeDateFormatting);

  group('formatEventTime — suffixe de fuseau', () {
    test('lecteur au Togo : aucun suffixe', () {
      expect(
        formatEventTime(_event(), 'fr', readerOffset: Duration.zero),
        '15:00 - 17:00',
      );
    });

    test('lecteur à Paris (UTC+2 en été) : suffixe « (GMT) »', () {
      expect(
        formatEventTime(_event(), 'fr', readerOffset: const Duration(hours: 2)),
        '15:00 - 17:00 (GMT)',
      );
    });

    test('l\'heure n\'est jamais convertie dans le fuseau du lecteur', () {
      // Vu de Paris, 15:00 UTC c'est 17:00 locales — et pourtant l'affichage
      // reste « 15:00 » : le rendez-vous est physique, l'heure vaut sur place.
      final vuDeParis = formatEventTime(_event(), 'fr',
          readerOffset: const Duration(hours: 2));
      expect(vuDeParis, startsWith('15:00'));
    });

    test('branche à Lagos vue du Togo : suffixe « (GMT+1) »', () {
      final event = _event(
        timezone: 'Africa/Lagos',
        startsAt: DateTime.utc(2026, 7, 26, 14),
        endsAt: DateTime.utc(2026, 7, 26, 16),
      );
      // 14:00 UTC = 15:00 à Lagos.
      expect(
        formatEventTime(event, 'fr', readerOffset: Duration.zero),
        '15:00 - 17:00 (GMT+1)',
      );
    });

    test('sans heure de fin, une seule heure est rendue', () {
      final event = ChurchEvent(
        id: 'evt-2',
        startsAt: DateTime.utc(2026, 7, 26, 20),
        timezone: 'Africa/Lome',
        title: const {'fr': 'Veillée'},
      );
      expect(
        formatEventTime(event, 'fr', readerOffset: Duration.zero),
        '20:00',
      );
    });

    test('startOnly omet la fin mais garde le suffixe', () {
      expect(
        formatEventTime(_event(), 'fr',
            readerOffset: const Duration(hours: 2), startOnly: true),
        '15:00 (GMT)',
      );
    });
  });

  group('offsetLabel — décalage en chiffres, jamais d\'abréviation', () {
    test('rend « GMT » à décalage nul', () {
      expect(offsetLabel(Duration.zero), 'GMT');
    });

    test('rend le signe et les heures', () {
      expect(offsetLabel(const Duration(hours: 1)), 'GMT+1');
      expect(offsetLabel(const Duration(hours: -3)), 'GMT-3');
    });

    test('rend les minutes quand le décalage n\'est pas rond', () {
      expect(offsetLabel(const Duration(hours: 5, minutes: 30)), 'GMT+5:30');
      expect(offsetLabel(const Duration(hours: -3, minutes: -30)), 'GMT-3:30');
    });
  });

  group('branchOffset', () {
    test('connaît les fuseaux à décalage fixe de la sous-région', () {
      expect(branchOffset('Africa/Lome'), Duration.zero);
      expect(branchOffset('Africa/Lagos'), const Duration(hours: 1));
      expect(branchOffset('UTC'), Duration.zero);
    });

    test('accepte un décalage explicite', () {
      expect(branchOffset('+01:00'), const Duration(hours: 1));
      expect(branchOffset('UTC-3'), const Duration(hours: -3));
      expect(branchOffset('GMT+05:30'), const Duration(hours: 5, minutes: 30));
    });

    test('traite un fuseau inconnu comme UTC', () {
      // Limite assumée : sans base IANA (aucun plugin natif autorisé), les
      // fuseaux à heure d'été ne sont pas résolus.
      expect(branchOffset('Europe/Paris'), Duration.zero);
      expect(branchOffset('n\'importe quoi'), Duration.zero);
    });
  });

  group('date rendue dans le fuseau de la branche', () {
    test('quantième, mois et jour de semaine en français', () {
      final event = _event();
      expect(formatEventDay(event, 'fr'), '26');
      expect(formatEventMonth(event, 'fr'), 'juil.');
      expect(formatEventWeekday(event, 'fr'), 'Dimanche');
    });

    test('la date suit le fuseau de la branche, pas UTC', () {
      // 23:30 UTC le 26 = 00:30 le 27 à Lagos : c'est un autre jour.
      final event = ChurchEvent(
        id: 'evt-3',
        startsAt: DateTime.utc(2026, 7, 26, 23, 30),
        timezone: 'Africa/Lagos',
        title: const {'fr': 'Veillée'},
      );
      expect(formatEventDay(event, 'fr'), '27');
      expect(formatEventWeekday(event, 'fr'), 'Lundi');
    });
  });
}
