// Tests du **résolveur de lecture offline-first** (`DownloadResolver`, #191).
//
// C'est le point de résolution unique de la médiathèque (PRD §3.3 F10/F11) : il
// décide, à la lecture, entre le fichier local et le HLS. Sa logique se vérifie
// entièrement sur la VM Dart — un vrai DAO sur une base **en mémoire** (le
// magasin fait foi, ADR-0026) et un état réseau **figé** ([FixedNetworkStatus]).
// Aucun lecteur, aucun canal de plugin.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/download_resolver.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';

import '../local/local_database_fixtures.dart';

const _id = 'c-1';
const _hls = 'https://exemple.test/c-1/master.m3u8';
const _path = '/data/downloads/c-1.mid.aac';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  /// Écrit une ligne de téléchargement pour [_id].
  Future<void> seed({
    required DownloadState state,
    String? localPath,
    int bytesReceived = 0,
    int bytesTotal = 0,
  }) {
    return db.downloadsDao.upsert(
      DownloadsCompanion.insert(
        contentType: 'teaching',
        contentId: _id,
        quality: 'mid',
        state: Value(state),
        localPath: Value(localPath),
        bytesReceived: Value(bytesReceived),
        bytesTotal: Value(bytesTotal),
        createdAt: DateTime.utc(2026, 8, 15),
      ),
    );
  }

  DownloadResolver resolver({bool offline = false}) => DownloadResolver(
        dao: db.downloadsDao,
        network: FixedNetworkStatus(offline: offline),
      );

  Future<PlaybackResolution> resolve({bool offline = false}) =>
      resolver(offline: offline).resolve(contentId: _id, hlsUrl: _hls);

  group('aucun téléchargement', () {
    test('retombe sur le HLS — en ligne comme hors ligne', () async {
      expect((await resolve()).hlsUrl, _hls);
      expect((await resolve()).isLocal, isFalse);
      expect((await resolve(offline: true)).hlsUrl, _hls);
    });
  });

  group('fichier complet (F10)', () {
    test('joue le local **en ligne**', () async {
      await seed(
        state: DownloadState.complete,
        localPath: _path,
        bytesReceived: 500,
        bytesTotal: 500,
      );
      final r = await resolve();
      expect(r.isLocal, isTrue);
      expect(r.localFilePath, _path);
    });

    test('joue le local **hors ligne**', () async {
      await seed(
        state: DownloadState.complete,
        localPath: _path,
        bytesReceived: 500,
        bytesTotal: 500,
      );
      expect((await resolve(offline: true)).localFilePath, _path);
    });

    test('sans chemin sur le disque, retombe sur le HLS (défensif)', () async {
      // Ne devrait pas arriver — un complet a un fichier — mais le magasin fait
      // foi et une ligne sans chemin ne doit pas casser la lecture.
      await seed(state: DownloadState.complete, bytesReceived: 500);
      expect((await resolve()).hlsUrl, _hls);
    });

    test('« mise à jour disponible » reste écoutable en local (ADR-0039)',
        () async {
      // Une révision garde le fichier (jamais de purge) : `outdated` se joue
      // comme un complet, en ligne comme hors ligne.
      await seed(
        state: DownloadState.outdated,
        localPath: _path,
        bytesReceived: 500,
        bytesTotal: 500,
      );
      expect((await resolve()).localFilePath, _path);
      expect((await resolve(offline: true)).localFilePath, _path);
    });
  });

  group('fichier partiel (F11)', () {
    test('hors ligne → joue le local', () async {
      await seed(
        state: DownloadState.paused,
        localPath: _path,
        bytesReceived: 120,
        bytesTotal: 500,
      );
      expect((await resolve(offline: true)).localFilePath, _path);
    });

    test('en ligne → HLS complet, pas le tronqué', () async {
      await seed(
        state: DownloadState.running,
        localPath: _path,
        bytesReceived: 120,
        bytesTotal: 500,
      );
      final r = await resolve();
      expect(r.isLocal, isFalse);
      expect(r.hlsUrl, _hls);
    });

    test('un échec conserve son partiel : jouable hors ligne (F9)', () async {
      await seed(
        state: DownloadState.failed,
        localPath: _path,
        bytesReceived: 120,
        bytesTotal: 500,
      );
      expect((await resolve(offline: true)).localFilePath, _path);
      expect((await resolve()).hlsUrl, _hls);
    });

    test('rien de reçu (0 octet) → HLS même hors ligne', () async {
      // En file d'attente / en attente de wifi : la ligne existe mais aucun
      // octet n'est encore sur le disque, il n'y a rien à jouer localement.
      await seed(
        state: DownloadState.waitingWifi,
        bytesReceived: 0,
        bytesTotal: 500,
      );
      expect((await resolve(offline: true)).hlsUrl, _hls);
    });
  });
}
