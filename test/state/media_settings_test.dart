import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

void main() {
  group('L\'échelle et le coût annoncé', () {
    test('les débits sont ceux du transcodeur, pas des inventions', () {
      // `streaming-service/app/transcodes/support/hls.ts` : low 64k, mid 128k,
      // high 192k. Un plafond qu'aucun rendu ne peut satisfaire ferait retomber
      // le lecteur sur le palier le plus bas, en silence.
      expect(MediaQuality.low.bitsPerSecond, 64000);
      expect(MediaQuality.mid.bitsPerSecond, 128000);
      expect(MediaQuality.high.bitsPerSecond, 192000);
      expect(MediaQuality.auto.bitsPerSecond, isNull);
    });

    test('le coût horaire se déduit du débit', () {
      // 64 kbit/s × 3600 s ÷ 8 ÷ 10⁶ ≈ 29 Mo. C'est le chiffre que la phrase
      // d'impact affiche, et il doit rester vérifiable par qui recoupe son
      // forfait.
      expect(MediaQuality.low.megabytesPerHour, 29);
      expect(MediaQuality.mid.megabytesPerHour, 58);
      expect(MediaQuality.high.megabytesPerHour, 86);
      // « Automatique » annonce le **pire cas** : celui des données mobiles,
      // c'est-à-dire précisément ce contre quoi le réglage protège.
      expect(MediaQuality.auto.megabytesPerHour, 29);
    });

    test('une valeur inconnue retombe sur le défaut, sans lever', () {
      expect(MediaQuality.parse(null), MediaQuality.auto);
      expect(MediaQuality.parse('ultra'), MediaQuality.auto);
      expect(MediaQuality.parse('mid'), MediaQuality.mid);
    });
  });

  group('Le mode automatique', () {
    test('bride en données mobiles, laisse libre en wifi', () {
      expect(
        effectiveBitrateCap(MediaQuality.auto, onCellular: true),
        MediaQuality.low.bitsPerSecond,
      );
      expect(effectiveBitrateCap(MediaQuality.auto, onCellular: false), isNull);
    });

    test('un palier choisi s\'applique partout, réseau compris', () {
      // Choisir « Haute » est une décision explicite : la corriger dans le dos
      // de qui l'a prise serait le pire ressenti possible pour un réglage.
      for (final cellular in [true, false]) {
        expect(
          effectiveBitrateCap(MediaQuality.high, onCellular: cellular),
          192000,
        );
      }
    });
  });

  group('Le magasin de réglages', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
    });

    test('une table vide rend les défauts, sans ligne à écrire', () async {
      final prefs = await db.settingsDao.watchMediaPreferences().first;

      // L'absence de ligne **est** le défaut : une valeur écrite d'office
      // serait indiscernable d'un choix, et changer le défaut plus tard ne
      // toucherait plus personne.
      expect(await db.select(db.appSettings).get(), isEmpty);
      expect(prefs.streaming, MediaQuality.auto);
      expect(prefs.download, MediaQuality.auto);
    });

    test('les trois usages se règlent séparément', () async {
      await db.settingsDao
          .setMediaQuality(MediaUsage.streaming, MediaQuality.high);
      await db.settingsDao
          .setMediaQuality(MediaUsage.download, MediaQuality.low);

      final prefs = await db.settingsDao.watchMediaPreferences().first;
      expect(prefs.streaming, MediaQuality.high);
      expect(prefs.download, MediaQuality.low);
    });

    test('réécrire un usage écrase, sans empiler de lignes', () async {
      await db.settingsDao
          .setMediaQuality(MediaUsage.streaming, MediaQuality.high);
      await db.settingsDao
          .setMediaQuality(MediaUsage.streaming, MediaQuality.mid);

      expect(await db.select(db.appSettings).get(), hasLength(1));
      final prefs = await db.settingsDao.watchMediaPreferences().first;
      expect(prefs.streaming, MediaQuality.mid);
    });
  });

  group('La radio (M2 du plan radio adaptative)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
    });

    test('quatre choix dans l\'ordre de l\'arc, et leurs Mo/h', () {
      expect(RadioQuality.values, [
        RadioQuality.minimum,
        RadioQuality.economy,
        RadioQuality.auto,
        RadioQuality.high,
      ]);
      expect(RadioQuality.minimum.megabytesPerHour, 7);
      expect(RadioQuality.economy.bitsPerSecond, 32000);
      expect(RadioQuality.economy.megabytesPerHour, 14);
      expect(RadioQuality.high.megabytesPerHour, 58);
      // L'automatique de la radio ne bride pas : il annonce le palier haut.
      expect(RadioQuality.auto.megabytesPerHour, 58);
    });

    test('clé stable, lecture tolérante', () {
      expect(MediaUsage.radio.key, 'radio');
      expect(RadioQuality.parse(null), RadioQuality.auto);
      expect(RadioQuality.parse('mid'), RadioQuality.auto);
      expect(RadioQuality.parse('economy'), RadioQuality.economy);
      expect(RadioQuality.parse('minimum'), RadioQuality.minimum);
      expect(RadioQuality.parse('high'), RadioQuality.high);
    });

    test('défaut Automatique, sans ligne écrite', () async {
      final prefs = await db.settingsDao.watchMediaPreferences().first;
      expect(prefs.radio, RadioQuality.auto);
    });

    test('Économie se persiste, sans toucher aux enseignements', () async {
      await db.settingsDao.setRadioQuality(RadioQuality.economy);

      final rows = await db.select(db.appSettings).get();
      expect(rows.single.key, 'radio');
      expect(rows.single.value, 'economy');
      final prefs = await db.settingsDao.watchMediaPreferences().first;
      expect(prefs.radio, RadioQuality.economy);
      expect(prefs.streaming, MediaQuality.auto);
    });

    test('radioQualityProvider suit le magasin', () async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.listen(radioQualityProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(radioQualityProvider), RadioQuality.auto);

      await db.settingsDao.setRadioQuality(RadioQuality.economy);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(radioQualityProvider), RadioQuality.economy);
    });
  });

  group('Le plafond visé — une dérivation pure', () {
    late AppDatabase db;
    late FixedNetworkTransport transport;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      transport = FixedNetworkTransport();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          networkTransportProvider.overrideWithValue(transport),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
        await db.close();
      });
    });

    Future<void> settle() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('un abonné ne provoque pas de reconstruction sans fin', () async {
      // **Le test qui garde la porte.** La version précédente de ce provider
      // mutait un champ depuis son `build` ; couplée à un `ref.listen`, elle
      // faisait tourner le montage de l'écran de lecture jusqu'à expiration.
      // On compte donc les émissions : une poignée, jamais une avalanche.
      var emissions = 0;
      container.listen(streamingBitrateTargetProvider, (_, __) => emissions++);
      await settle();
      transport.emit(true);
      await settle();
      transport.emit(false);
      await settle();

      expect(
        emissions,
        lessThan(10),
        reason: 'deux changements de réseau ne peuvent pas produire dix '
            'émissions — au-delà, le provider se reconstruit lui-même',
      );
    });

    test('en wifi aucun plafond, en cellulaire 64k', () async {
      container.listen(streamingBitrateTargetProvider, (_, __) {});
      await settle();
      expect(container.read(streamingBitrateTargetProvider), isNull);

      transport.emit(true);
      await settle();
      expect(container.read(streamingBitrateTargetProvider), 64000);

      // La dérivation est **pure** : elle remonte aussi. C'est le widget qui
      // pose le cliquet, parce qu'il ne vaut que pour l'écoute en cours.
      transport.emit(false);
      await settle();
      expect(container.read(streamingBitrateTargetProvider), isNull);
    });
  });
}
