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
      expect(prefs.live, MediaQuality.auto);
      expect(prefs.download, MediaQuality.auto);
    });

    test('les trois usages se règlent séparément', () async {
      await db.settingsDao
          .setMediaQuality(MediaUsage.streaming, MediaQuality.high);
      await db.settingsDao.setMediaQuality(MediaUsage.live, MediaQuality.low);

      final prefs = await db.settingsDao.watchMediaPreferences().first;
      expect(prefs.streaming, MediaQuality.high);
      expect(prefs.live, MediaQuality.low);
      expect(prefs.download, MediaQuality.auto);
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

  group('Le cliquet du plafond', () {
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

    /// Amorce les abonnements et laisse les premiers événements passer.
    Future<void> settle() async {
      container.listen(streamingBitrateCapProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('en wifi, aucun plafond', () async {
      await settle();
      expect(container.read(streamingBitrateCapProvider), isNull);
    });

    test('la bascule vers le cellulaire fait tomber le plafond', () async {
      await settle();
      transport.emit(true);
      await Future<void>.delayed(Duration.zero);

      // Le fidèle sort de l'église au milieu d'un prêche d'une heure : c'est
      // exactement la facture que le réglage doit éviter.
      expect(container.read(streamingBitrateCapProvider), 64000);
    });

    test('le retour au wifi ne fait PAS remonter la qualité en cours',
        () async {
      await settle();
      transport.emit(true);
      await Future<void>.delayed(Duration.zero);
      transport.emit(false);
      await Future<void>.delayed(Duration.zero);

      // Remonter coûterait une remise en tampon au milieu d'un prêche, et une
      // interruption vaut plus cher qu'un peu d'aigu.
      expect(
        container.read(streamingBitrateCapProvider),
        64000,
        reason:
            'le cliquet ne se relâche qu\'à l\'ouverture du contenu suivant',
      );
    });

    test('release() relâche le cliquet — sinon le bridage serait à vie',
        () async {
      await settle();
      transport.emit(true);
      await Future<void>.delayed(Duration.zero);
      transport.emit(false);
      await Future<void>.delayed(Duration.zero);

      container.read(streamingBitrateCapProvider.notifier).release();
      await Future<void>.delayed(Duration.zero);

      // Sans cela, une seule écoute en données mobiles briderait le fidèle chez
      // lui, sur son wifi, jusqu'au redémarrage de l'application.
      expect(container.read(streamingBitrateCapProvider), isNull);
    });
  });
}
