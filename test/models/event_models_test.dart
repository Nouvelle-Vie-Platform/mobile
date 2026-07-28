import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/utils/i18n_text.dart';

import '../helpers/event_payloads.dart';

void main() {
  group('ChurchEvent.fromJson', () {
    test('lit un item complet, clés en snake_case', () {
      final event = ChurchEvent.fromJson(fullEventPayload);

      expect(event.id, '01920f00-0000-4000-8000-000000000001');
      expect(event.startsAt, DateTime.utc(2026, 8, 3, 17, 30));
      expect(event.endsAt, DateTime.utc(2026, 8, 3, 19));
      // Fuseau de la **branche**, pas celui du lecteur.
      expect(event.timezone, 'Africa/Lome');
      expect(event.branchId, 3);
      expect(event.title['fr'], 'Prière de zone');
      expect(event.title['en'], 'Zone prayer');
      expect(event.body?['fr'], 'Rendez-vous au portail.');
      expect(event.place, 'Temple Central');
      expect(event.category?.id, 2);
      expect(event.category?.label['fr'], 'Prière');
      expect(event.category?.tone, 'culte');
    });

    test('lit un item minimal : fr seul, tout le reste absent', () {
      final event = ChurchEvent.fromJson(minimalEventPayload);

      expect(event.id, '01920f00-0000-4000-8000-000000000002');
      expect(event.startsAt, DateTime.utc(2026, 8, 10, 18));
      // Durée non annoncée : l'écran affiche l'heure de début seule.
      expect(event.endsAt, isNull);
      // `branch_id` nul = portée **nationale**, pas une donnée manquante.
      expect(event.branchId, isNull);
      expect(event.body, isNull);
      expect(event.place, isNull);
      expect(event.category, isNull);
      expect(pick(event.title, 'fr'), 'Veillée');
    });

    test('des clés absentes du JSON valent « non renseigné », pas un plantage',
        () {
      final event = ChurchEvent.fromJson(const {
        'id': 'evt',
        'starts_at': '2026-08-10T18:00:00Z',
        'timezone': 'Africa/Lome',
        'title': {'fr': 'Veillée'},
      });

      expect(event.endsAt, isNull);
      expect(event.branchId, isNull);
      expect(event.category, isNull);
    });

    test('une langue inconnue de l\'app ne fait pas échouer le parsing', () {
      final event = ChurchEvent.fromJson({
        ...minimalEventPayload,
        'title': const {'fr': 'Veillée', 'yo': 'Àìsùn', 'de': 'Nachtwache'},
      });

      // Conservée telle quelle : c'est `pick` qui choisit et qui se replie, le
      // parsing n'a pas à connaître la liste des langues de l'app.
      expect(event.title['yo'], 'Àìsùn');
      expect(pick(event.title, 'fr'), 'Veillée');
      expect(pick(event.title, 'en'), 'Veillée');
    });

    test('une valeur non textuelle dans un champ multilingue est ignorée', () {
      final event = ChurchEvent.fromJson({
        ...minimalEventPayload,
        'title': const {'fr': 'Veillée', 'en': 42},
      });

      expect(event.title, {'fr': 'Veillée'});
    });

    test('les maps multilingues sont non modifiables', () {
      final event = ChurchEvent.fromJson(fullEventPayload);

      expect(
        () => event.title['fr'] = 'autre chose',
        throwsUnsupportedError,
      );
    });
  });

  // C'est le bug le plus probable de toute l'issue : un instant lu en heure
  // locale décale l'agenda entier de plusieurs heures — sans erreur, sans
  // trace, et différemment selon le téléphone du lecteur.
  group('starts_at est un instant UTC', () {
    test('une chaîne suffixée Z reste en UTC, sans glisser vers l\'appareil',
        () {
      final event = ChurchEvent.fromJson(fullEventPayload);

      expect(event.startsAt.isUtc, isTrue);
      expect(event.startsAt, DateTime.utc(2026, 8, 3, 17, 30));
      // Les champs eux-mêmes, pas seulement l'instant : `hour` est ce que lit
      // `wallClockAt` avant d'ajouter le décalage de la branche.
      expect(event.startsAt.year, 2026);
      expect(event.startsAt.month, 8);
      expect(event.startsAt.day, 3);
      expect(event.startsAt.hour, 17);
      expect(event.startsAt.minute, 30);
      // Sérialisation aller-retour : aucune conversion n'a eu lieu.
      expect(event.startsAt.toIso8601String(), '2026-08-03T17:30:00.000Z');
      // Et l'écart avec l'heure locale de la machine de test, quel que soit son
      // fuseau, vaut exactement le décalage de cette machine — donc la valeur
      // parsée n'est pas, elle, en heure locale.
      final local = event.startsAt.toLocal();
      expect(
        local.difference(DateTime(2026, 8, 3, 17, 30)),
        local.timeZoneOffset,
      );
    });

    test('ends_at suit la même règle', () {
      final event = ChurchEvent.fromJson(fullEventPayload);

      expect(event.endsAt!.isUtc, isTrue);
      expect(event.endsAt, DateTime.utc(2026, 8, 3, 19));
    });

    test('un décalage explicite est normalisé en UTC', () {
      final event = ChurchEvent.fromJson({
        ...fullEventPayload,
        'starts_at': '2026-08-03T18:30:00+01:00',
      });

      expect(event.startsAt.isUtc, isTrue);
      expect(event.startsAt, DateTime.utc(2026, 8, 3, 17, 30));
    });

    test('une chaîne sans fuseau est convertie, jamais laissée en local', () {
      // Dart lit une chaîne nue en heure **locale de l'appareil** : sans le
      // `.toUtc()` de `parseInstant`, l'instant sortirait faux et marqué non-UTC.
      final event = ChurchEvent.fromJson({
        ...fullEventPayload,
        'starts_at': '2026-08-03T17:30:00',
      });

      expect(event.startsAt.isUtc, isTrue);
      expect(event.startsAt, DateTime(2026, 8, 3, 17, 30).toUtc());
    });
  });

  group('EventCategory.fromJson', () {
    test('lit id, label multilingue et tone', () {
      final category = EventCategory.fromJson(const {
        'id': 2,
        'label': {'fr': 'Prière'},
        'tone': 'culte',
      });

      expect(category.id, 2);
      expect(category.label['fr'], 'Prière');
      // `tone` est une **clé d'habillage**, pas une couleur : le thème la
      // résout, le modèle la transporte.
      expect(category.tone, 'culte');
    });
  });
}
