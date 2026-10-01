/// **La page Téléchargements** (#193, F13/F14).
///
/// On vérifie ce que l'écran **peint** depuis le magasin (liste, états, en-tête
/// d'espace, état vide) et ce qu'il **demande** au moteur à la suppression — pas
/// des canaux natifs, absents du harnais.
///
/// Les providers `downloads` sont surchargés par des **flux nus** : un flux
/// Drift attendu sous l'horloge factice du harnais fige le montage (0 % de CPU
/// jusqu'à expiration). C'est le piège rencontré en #192 ; on ne le retente pas.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/disk_space.dart';
import 'package:maison_du_miracle/data/downloads/download_manager.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/teaching_download.dart';
import 'package:maison_du_miracle/screens/downloads_screen.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/widgets/app_empty_state.dart';

import '../helpers/fake_download_backend.dart';
import '../helpers/pump_screen.dart';

const _id = '019f7000-0000-7000-8000-000000000001';

DownloadRow _row({
  String contentId = _id,
  DownloadState state = DownloadState.complete,
  int bytesReceived = 0,
  int bytesTotal = 0,
  String? taskId = 'task-1',
}) =>
    DownloadRow(
      contentType: 'teaching',
      contentId: contentId,
      quality: 'mid',
      state: state,
      bytesReceived: bytesReceived,
      bytesTotal: bytesTotal,
      taskId: taskId,
      createdAt: DateTime.utc(2026, 8, 15),
    );

TeachingView _view({String id = _id, String title = 'La foi qui déplace'}) =>
    TeachingView(id: id, title: title, color: 0xFF223B8C);

/// Monte la page avec des flux nus. [titles] joint un titre par `contentId`.
Future<void> pumpDownloads(
  WidgetTester tester, {
  required List<DownloadRow> rows,
  int usage = 0,
  Map<String, TeachingView> titles = const {},
  DownloadManager? manager,
  AppDatabase? database,
  List<DownloadNotificationRow> notifications = const [],
  List<Override> extraOverrides = const [],
}) {
  return pumpScreen(
    tester,
    const DownloadsScreen(),
    database: database,
    notifications: notifications,
    overrides: [
      downloadsListProvider.overrideWith((ref) => Stream.value(rows)),
      downloadsStorageUsageProvider.overrideWith((ref) => Stream.value(usage)),
      teachingByIdProvider.overrideWith((ref, id) => Stream.value(titles[id])),
      if (manager != null) downloadManagerProvider.overrideWithValue(manager),
      ...extraOverrides,
    ],
  );
}

void main() {
  group('La liste peuplée', () {
    testWidgets('rend le titre et l\'état de chaque item', (tester) async {
      await pumpDownloads(
        tester,
        rows: [
          _row(state: DownloadState.complete, bytesTotal: 20 * 1024 * 1024),
          _row(
            contentId: 'c2',
            state: DownloadState.running,
            bytesReceived: 42,
            bytesTotal: 100,
          ),
          _row(contentId: 'c3', state: DownloadState.waitingWifi),
        ],
        titles: {
          _id: _view(title: 'Le pardon'),
          'c2': _view(id: 'c2', title: 'La persévérance'),
          'c3': _view(id: 'c3', title: 'L\'espérance'),
        },
      );

      // Les trois titres joints depuis le read-model paraissent.
      expect(find.text('Le pardon'), findsOneWidget);
      expect(find.text('La persévérance'), findsOneWidget);
      expect(find.text('L\'espérance'), findsOneWidget);

      // Les états : complété (avec taille), en cours (42 %), en attente de wifi.
      expect(find.textContaining('Téléchargé'), findsOneWidget);
      expect(find.text('42 %'), findsOneWidget);
      expect(find.text('En attente de wifi'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('un enseignement absent du magasin garde un titre de repli',
        (tester) async {
      await pumpDownloads(
        tester,
        rows: [_row(state: DownloadState.complete, bytesTotal: 1024 * 1024)],
        // Aucun titre joint : la ligne existe, le read-model ne la connaît pas.
      );

      expect(find.text('Message téléchargé'), findsOneWidget);
    });
  });

  group('L\'en-tête d\'espace', () {
    testWidgets('affiche l\'espace total utilisé', (tester) async {
      await pumpDownloads(
        tester,
        rows: [
          _row(state: DownloadState.complete, bytesTotal: 21 * 1024 * 1024)
        ],
        usage: 21 * 1024 * 1024,
        titles: {_id: _view()},
      );

      // 21 Mo → « 21 Mo utilisés ».
      expect(find.textContaining('21 Mo utilisés'), findsOneWidget);
    });
  });

  group('L\'état vide', () {
    testWidgets('« Aucun téléchargement » quand la liste est vide',
        (tester) async {
      await pumpDownloads(tester, rows: const []);

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Aucun téléchargement'), findsOneWidget);
    });
  });

  group('Le badge « mise à jour disponible » (#194, F15)', () {
    testWidgets('un item périmé affiche le badge et propose la mise à jour',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final backend = FakeDownloadBackend();
      addTearDown(backend.dispose);
      // Le magasin connaît le contrat de téléchargement : « Mettre à jour »
      // relance vraiment un enqueue.
      final manager = DownloadManager(
        dao: db.downloadsDao,
        backend: backend,
        diskSpace: const FixedDiskSpace(1000000),
        network: FixedNetworkTransport(),
        metadataFor: (id) async => const TeachingDownload(
          version: 'v2',
          durationSeconds: 3600,
          renditions: {
            'mid': DownloadRendition(url: 'https://x/mid.aac', bytes: 200),
          },
        ),
        mobileDataAllowed: () async => true,
        newTaskId: () => 'task-9',
        now: () => DateTime.utc(2026, 8, 15),
      );
      manager.start();
      addTearDown(manager.dispose);

      await db.downloadsDao.upsert(
        DownloadsCompanion.insert(
          contentType: 'teaching',
          contentId: _id,
          quality: 'mid',
          state: const Value(DownloadState.outdated),
          bytesTotal: const Value(200),
          versionId: const Value('v1'),
          taskId: const Value('task-1'),
          createdAt: DateTime.utc(2026, 8, 15),
        ),
      );
      final row = (await db.downloadsDao.forContent(_id))!;

      await pumpDownloads(
        tester,
        rows: [row],
        titles: {_id: _view()},
        manager: manager,
        database: db,
        // « Mettre à jour » lit la qualité choisie : posée par une valeur nue
        // pour ne pas ouvrir un flux Drift (`mediaPreferences`) sous l'horloge
        // factice, qui figerait le montage.
        extraOverrides: [
          downloadQualityProvider.overrideWithValue(MediaQuality.mid),
        ],
      );

      // Le badge est visible sur l'item périmé.
      expect(find.text('Mise à jour disponible'), findsOneWidget);

      // Le menu propose « Mettre à jour », qui relance le téléchargement.
      await tester.tap(find.byKey(DownloadsScreen.menuKey(_id)));
      await tester.pumpAndSettle();
      expect(find.text('Mettre à jour'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Mettre à jour'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(backend.enqueued, hasLength(1),
          reason: 'la mise à jour re-télécharge la nouvelle version');
      expect(backend.enqueued.single.url, 'https://x/mid.aac');
    });
  });

  group('Le bandeau de purge (#194, F16)', () {
    testWidgets('rend la notification nommée', (tester) async {
      await pumpDownloads(
        tester,
        rows: const [],
        notifications: [
          DownloadNotificationRow(
            id: 1,
            contentId: 'gone',
            title: 'Le pardon',
            createdAt: DateTime.utc(2026, 8, 15),
          ),
        ],
      );

      expect(
        find.textContaining('« Le pardon » a été retiré par la médiathèque'),
        findsOneWidget,
      );
    });

    testWidgets('sans titre connu, un message générique', (tester) async {
      await pumpDownloads(
        tester,
        rows: const [],
        notifications: [
          DownloadNotificationRow(
            id: 2,
            contentId: 'gone',
            createdAt: DateTime.utc(2026, 8, 15),
          ),
        ],
      );

      expect(
        find.textContaining('Un message a été retiré'),
        findsOneWidget,
      );
    });

    testWidgets('rejeter une notification la supprime du magasin',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.downloadNotificationsDao.add(
        contentId: 'gone',
        title: 'Le pardon',
        createdAt: DateTime.utc(2026, 8, 15),
      );
      final notice = (await db.downloadNotificationsDao.all()).single;

      await pumpDownloads(
        tester,
        rows: const [],
        database: db,
        notifications: [notice],
      );

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Ignorer'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(await db.downloadNotificationsDao.all(), isEmpty);
    });
  });

  group('La suppression depuis la page (F14)', () {
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

    /// Un moteur réel câblé au faux backend, sur la base seedée.
    DownloadManager buildManager() {
      final manager = DownloadManager(
        dao: db.downloadsDao,
        backend: backend,
        diskSpace: const FixedDiskSpace(1000000),
        network: FixedNetworkTransport(),
        metadataFor: (id) async => null,
        mobileDataAllowed: () async => false,
        newTaskId: () => 'task-1',
        now: () => DateTime.utc(2026, 8, 15),
      );
      manager.start();
      addTearDown(manager.dispose);
      return manager;
    }

    Future<DownloadRow> seed(DownloadState state) async {
      await db.downloadsDao.upsert(
        DownloadsCompanion.insert(
          contentType: 'teaching',
          contentId: _id,
          quality: 'mid',
          state: Value(state),
          bytesTotal: const Value(200),
          taskId: const Value('task-1'),
          createdAt: DateTime.utc(2026, 8, 15),
        ),
      );
      return (await db.downloadsDao.forContent(_id))!;
    }

    testWidgets('un complété demande confirmation, puis supprime',
        (tester) async {
      final row = await seed(DownloadState.complete);
      await pumpDownloads(
        tester,
        rows: [row],
        titles: {_id: _view()},
        manager: buildManager(),
        database: db,
      );

      await tester.tap(find.byKey(DownloadsScreen.menuKey(_id)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer le téléchargement'));
      await tester.pumpAndSettle();

      // La confirmation paraît — on jette un contenu prêt (F14).
      expect(find.text('Supprimer le téléchargement ?'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Supprimer'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(backend.canceled, contains('task-1'));
    });

    testWidgets('un partiel se supprime directement, sans confirmation',
        (tester) async {
      final row = await seed(DownloadState.paused);
      await pumpDownloads(
        tester,
        rows: [row],
        titles: {_id: _view()},
        manager: buildManager(),
        database: db,
      );

      await tester.tap(find.byKey(DownloadsScreen.menuKey(_id)));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('Supprimer le téléchargement'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      // Aucun dialogue de confirmation pour un partiel.
      expect(find.text('Supprimer le téléchargement ?'), findsNothing);
      expect(backend.canceled, contains('task-1'));
    });
  });
}
