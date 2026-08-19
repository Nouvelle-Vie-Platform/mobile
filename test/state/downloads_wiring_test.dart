/// **Le branchement des réglages média au moteur de téléchargement** (#192).
///
/// Deux fils, jusqu'ici morts, que cette issue relie :
/// - la **qualité** « Téléchargement » (F6) → [downloadQualityProvider] ;
/// - le toggle **« données mobiles »** (F8) → `DownloadManager.mobileDataAllowed`,
///   câblé en dur à `false` par le socle #190. On prouve ici qu'il ne l'est plus.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/disk_space.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/models/teaching_download.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../helpers/fake_download_backend.dart';

const _id = 't-1';

TeachingDownload _metadata() => const TeachingDownload(
      version: 'v1',
      durationSeconds: 3600,
      renditions: {
        'mid': DownloadRendition(url: 'https://x/mid.aac', bytes: 200),
      },
    );

void main() {
  late AppDatabase db;
  late FakeDownloadBackend backend;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeDownloadBackend();
  });

  tearDown(() async {
    await backend.dispose();
    await db.close();
  });

  ProviderContainer buildContainer({bool cellular = false}) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        downloadBackendProvider.overrideWithValue(backend),
        diskSpaceProvider.overrideWithValue(const FixedDiskSpace(1000000)),
        networkTransportProvider
            .overrideWithValue(FixedNetworkTransport(cellular: cellular)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('La qualité de téléchargement (F6)', () {
    test('suit le réglage média « Téléchargement »', () async {
      final container = ProviderContainer(
        overrides: [
          mediaPreferencesProvider.overrideWith(
            (ref) => Stream.value(
              const MediaPreferences(download: MediaQuality.high),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Un écouteur persistant : sans lui, le `StreamProvider` s'autodispose
      // avant même d'avoir émis sa première valeur.
      container.listen(mediaPreferencesProvider, (_, __) {});

      await container.read(mediaPreferencesProvider.future);

      expect(container.read(downloadQualityProvider), MediaQuality.high);
    });

    test('défaut auto quand rien n\'est réglé', () async {
      final container = ProviderContainer(
        overrides: [
          mediaPreferencesProvider
              .overrideWith((ref) => Stream.value(const MediaPreferences())),
        ],
      );
      addTearDown(container.dispose);
      container.listen(mediaPreferencesProvider, (_, __) {});

      await container.read(mediaPreferencesProvider.future);

      expect(container.read(downloadQualityProvider), MediaQuality.auto);
    });
  });

  group('Le toggle « données mobiles » (F8) alimente mobileDataAllowed', () {
    test('wifi seulement (défaut) : sur cellulaire, l\'item attend le wifi',
        () async {
      final container = buildContainer(cellular: true);
      // Réglage à son défaut : rien d'écrit, donc wifi seulement.
      final manager = container.read(downloadManagerProvider);

      await manager.download(
        contentId: _id,
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _metadata(),
      );

      final row = await db.downloadsDao.forContent(_id);
      expect(row!.state, DownloadState.waitingWifi);
      // Rien n'est parti sur le forfait.
      expect(backend.enqueued.single.requiresWifi, isTrue);
    });

    test('toggle activé : sur cellulaire, le téléchargement démarre', () async {
      final container = buildContainer(cellular: true);
      await db.settingsDao.setDownloadOnCellular(true);

      final manager = container.read(downloadManagerProvider);
      await manager.download(
        contentId: _id,
        contentType: 'teaching',
        quality: MediaQuality.mid,
        metadata: _metadata(),
      );

      final row = await db.downloadsDao.forContent(_id);
      expect(row!.state, DownloadState.queued);
      expect(backend.enqueued.single.requiresWifi, isFalse);
    });
  });
}
