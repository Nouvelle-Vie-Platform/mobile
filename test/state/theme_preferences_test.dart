import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/theme_preferences.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/state/theme_provider.dart';

void main() {
  // Le notifier s'abonne au cycle de vie pour se réévaluer au retour au premier
  // plan : sans binding, `WidgetsBinding.instance` lève. Une ligne, et le test
  // reste une pure vérification de logique.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('La règle horaire', () {
    const soir = DayTime(19, 0);
    const matin = DayTime(6, 0);

    bool dark(int hour, int minute) => isDarkAt(
          DateTime(2026, 8, 15, hour, minute),
          darkFrom: soir,
          lightFrom: matin,
        );

    test('sombre le soir, clair le jour, minuit traversé', () {
      expect(dark(18, 59), isFalse);
      expect(dark(19, 0), isTrue, reason: 'la bascule est inclusive');
      expect(dark(23, 30), isTrue);
      expect(dark(2, 0), isTrue, reason: 'l\'intervalle passe minuit');
      expect(dark(5, 59), isTrue);
      expect(dark(6, 0), isFalse, reason: 'le retour au clair est inclusif');
      expect(dark(12, 0), isFalse);
    });

    test('l\'ordre inverse est un réglage valide, pas un cas particulier', () {
      // Sombre de 6 h à 19 h : c'est le réglage de qui veille la nuit. La même
      // comparaison, prise dans l'autre sens.
      bool inverse(int hour) => isDarkAt(
            DateTime(2026, 8, 15, hour),
            darkFrom: matin,
            lightFrom: soir,
          );
      expect(inverse(12), isTrue);
      expect(inverse(22), isFalse);
      expect(inverse(3), isFalse);
    });

    test('deux heures identiques : intervalle vide, donc toujours clair', () {
      // `ThemeChoice.dark` existe déjà en un geste pour qui veut du sombre en
      // permanence — c'est la lecture la moins surprenante.
      for (final hour in [0, 6, 12, 19, 23]) {
        expect(
          isDarkAt(DateTime(2026, 8, 15, hour),
              darkFrom: soir, lightFrom: soir),
          isFalse,
        );
      }
    });
  });

  group('La prochaine bascule', () {
    const soir = DayTime(19, 0);
    const matin = DayTime(6, 0);

    test('à 12 h, c\'est le soir même', () {
      final at = nextThemeSwitch(DateTime(2026, 8, 15, 12),
          darkFrom: soir, lightFrom: matin);
      expect(at, DateTime(2026, 8, 15, 19));
    });

    test('à 20 h, c\'est le matin suivant', () {
      final at = nextThemeSwitch(DateTime(2026, 8, 15, 20),
          darkFrom: soir, lightFrom: matin);
      expect(at, DateTime(2026, 8, 16, 6));
    });

    test('pile à l\'heure, c\'est la suivante — jamais maintenant', () {
      // Sans cela la minuterie se réarmerait sur un délai nul et tournerait en
      // boucle serrée.
      final at = nextThemeSwitch(DateTime(2026, 8, 15, 19),
          darkFrom: soir, lightFrom: matin);
      expect(at, DateTime(2026, 8, 16, 6));
    });

    test('heures identiques : rien à attendre', () {
      expect(
        nextThemeSwitch(DateTime(2026, 8, 15, 12),
            darkFrom: soir, lightFrom: soir),
        isNull,
      );
    });
  });

  group('La lecture des valeurs stockées', () {
    test('une clé inconnue retombe sur le défaut, sans lever', () {
      expect(ThemeChoice.parse(null), ThemeChoice.system);
      expect(ThemeChoice.parse('turquoise'), ThemeChoice.system);
      expect(ThemeChoice.parse('auto'), ThemeChoice.auto);
    });

    test('une heure illisible ne prive pas l\'app de thème', () {
      const fallback = DayTime(19, 0);
      for (final raw in [null, '', 'midi', '25:00', '19:99', '19']) {
        expect(DayTime.parse(raw, fallback: fallback), fallback,
            reason: 'la forme « $raw » doit retomber sur le défaut');
      }
      expect(DayTime.parse('07:05', fallback: fallback), const DayTime(7, 5));
    });
  });

  group('Le mode effectivement appliqué', () {
    late AppDatabase db;

    ProviderContainer containerAt(DateTime now) {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
    });

    Future<void> settle(ProviderContainer container) async {
      container.listen(themeModeProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('sans réglage, on suit le téléphone', () async {
      final container = containerAt(DateTime(2026, 8, 15, 21));
      await settle(container);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('« Auto » à 21 h donne sombre, à midi donne clair', () async {
      await db.settingsDao.setThemeChoice(ThemeChoice.auto);

      final soir = containerAt(DateTime(2026, 8, 15, 21));
      await settle(soir);
      expect(soir.read(themeModeProvider), ThemeMode.dark);

      final midi = containerAt(DateTime(2026, 8, 15, 12));
      await settle(midi);
      expect(midi.read(themeModeProvider), ThemeMode.light);
    });

    test('« Auto » suit les heures choisies', () async {
      await db.settingsDao.setThemeChoice(ThemeChoice.auto);
      await db.settingsDao.setDarkFrom(const DayTime(11, 0));

      // 12 h tombe désormais dans l'intervalle sombre.
      final container = containerAt(DateTime(2026, 8, 15, 12));
      await settle(container);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('un choix explicite ignore l\'heure', () async {
      await db.settingsDao.setThemeChoice(ThemeChoice.light);
      final container = containerAt(DateTime(2026, 8, 15, 23));
      await settle(container);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('le choix survit — c\'est tout l\'objet de la persistance', () async {
      await db.settingsDao.setThemeChoice(ThemeChoice.dark);

      // Un second conteneur, comme un second lancement de l'application : le
      // thème se perdait à chaque démarrage avant que ce réglage n'ait un toit.
      final relance = containerAt(DateTime(2026, 8, 15, 12));
      await settle(relance);
      expect(relance.read(themeModeProvider), ThemeMode.dark);
    });
  });
}
