import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:maison_du_miracle/l10n/app_localizations.dart';
import 'package:maison_du_miracle/utils/relative_time.dart';

void main() {
  late AppLocalizations fr;
  late AppLocalizations en;

  // Hors widget, les symboles de date d'`intl` ne sont pas chargés par
  // `flutter_localizations` : on les initialise explicitement.
  setUpAll(() async {
    initializeDateFormatting();
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // Horloge figée : les paliers doivent être déterministes.
  final now = DateTime(2026, 7, 24, 12, 0);
  String ago(AppLocalizations l10n, Duration since) =>
      relativeTime(l10n, now.subtract(since), now: now);

  group('relativeTime (fr)', () {
    test('moins d\'une minute', () {
      expect(ago(fr, const Duration(seconds: 30)), 'À l\'instant');
      expect(ago(fr, Duration.zero), 'À l\'instant');
    });

    test('date future traitée comme « à l\'instant »', () {
      expect(
        relativeTime(fr, now.add(const Duration(minutes: 5)), now: now),
        'À l\'instant',
      );
    });

    test('minutes (pluriel ICU)', () {
      expect(ago(fr, const Duration(minutes: 1)), 'Il y a 1 minute');
      expect(ago(fr, const Duration(minutes: 42)), 'Il y a 42 minutes');
      expect(ago(fr, const Duration(minutes: 59)), 'Il y a 59 minutes');
    });

    test('heures', () {
      expect(ago(fr, const Duration(hours: 1)), 'Il y a 1 heure');
      expect(ago(fr, const Duration(hours: 23)), 'Il y a 23 heures');
    });

    test('hier entre 24 h et 48 h', () {
      expect(ago(fr, const Duration(hours: 24)), 'Hier');
      expect(ago(fr, const Duration(hours: 47)), 'Hier');
    });

    test('jours jusqu\'à une semaine', () {
      expect(ago(fr, const Duration(hours: 48)), 'Il y a 2 jours');
      expect(ago(fr, const Duration(days: 6)), 'Il y a 6 jours');
    });

    test('au-delà d\'une semaine : date courte localisée', () {
      final when = now.subtract(const Duration(days: 12));
      expect(ago(fr, const Duration(days: 12)),
          DateFormat.yMMMd('fr').format(when));
      expect(ago(fr, const Duration(days: 7)),
          DateFormat.yMMMd('fr').format(now.subtract(const Duration(days: 7))));
    });
  });

  group('relativeTime (en)', () {
    test('libellés traduits', () {
      expect(ago(en, const Duration(seconds: 10)), 'Just now');
      expect(ago(en, const Duration(minutes: 1)), '1 minute ago');
      expect(ago(en, const Duration(minutes: 5)), '5 minutes ago');
      expect(ago(en, const Duration(hours: 2)), '2 hours ago');
      expect(ago(en, const Duration(hours: 30)), 'Yesterday');
      expect(ago(en, const Duration(days: 4)), '4 days ago');
    });
  });

  test('une date UTC est comparée correctement à une référence locale', () {
    final when = now.subtract(const Duration(hours: 3)).toUtc();
    expect(relativeTime(fr, when, now: now), 'Il y a 3 heures');
  });
}
