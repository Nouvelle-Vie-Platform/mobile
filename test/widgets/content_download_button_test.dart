/// **Le bouton Télécharger de la fiche** (#192, F5/F6).
///
/// Cinq états, chacun pilotant un geste du `DownloadManager`. Le manager est
/// **réel**, câblé à un `FakeDownloadBackend` : on vérifie donc ce que l'écran
/// demande au moteur (enqueue, pause, resume, cancel) et à quelle qualité — pas
/// des canaux natifs, absents du harnais. La ligne `downloads` du magasin peint
/// les cinq états ; l'écran l'observe, jamais le réseau (ADR-0026).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/disk_space.dart';
import 'package:maison_du_miracle/data/downloads/download_capabilities.dart';
import 'package:maison_du_miracle/data/downloads/download_manager.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/tables/download_tables.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/data/install/install_prompt.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/teaching_download.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/install_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/content_player_view.dart';

import '../helpers/fake_download_backend.dart';
import '../helpers/playback_doubles.dart';

final _fr = AppLocalizationsFr();

const _url = 'https://exemple.test/enseignement/master.m3u8';
const _id = '019f7000-0000-7000-8000-000000000001';

const _view = TeachingView(
  id: _id,
  title: 'La foi qui déplace',
  color: 0xFF223B8C,
  playlistUrl: _url,
);

final _contentProvider = Provider<AsyncValue<ContentView?>>(
  (ref) => const AsyncData<ContentView?>(_view),
);

TeachingDownload _metadata() => const TeachingDownload(
      version: 'v1',
      durationSeconds: 3600,
      renditions: {
        'low': DownloadRendition(url: 'https://x/low.aac', bytes: 100),
        'mid': DownloadRendition(url: 'https://x/mid.aac', bytes: 200),
        'high': DownloadRendition(url: 'https://x/high.aac', bytes: 300),
      },
    );

/// **Ce que la plateforme permet**, piloté — c'est ce qui rend les règles du
/// navigateur vérifiables sur la VM, sans navigateur (#273).
class FakeDownloadCapabilities implements DownloadCapabilities {
  FakeDownloadCapabilities({
    this.available = true,
    this.canPause = true,
    this.durable = true,
  });

  @override
  final bool available;

  @override
  final bool canPause;

  /// Ce que rend `ensureDurable()` : faux = `navigator.storage.persist()` a
  /// répondu non, c'est-à-dire un onglet non installé.
  final bool durable;

  int asked = 0;

  @override
  Future<bool> ensureDurable() async {
    asked++;
    return durable;
  }
}

/// Une offre d'installation, et la preuve que le bouton atteint le navigateur.
class FakeInstallPrompt implements InstallPrompt {
  FakeInstallPrompt(this.offer);

  @override
  final InstallOffer offer;

  int shown = 0;

  @override
  Stream<InstallOffer> get changes => const Stream<InstallOffer>.empty();

  @override
  Future<void> show() async => shown++;
}

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

  /// Écrit une ligne `downloads` dans l'état voulu, comme si le moteur l'avait
  /// peinte. `taskId` non nul : pause/resume/cancel en ont besoin.
  Future<void> seed({
    required DownloadState state,
    int bytesReceived = 0,
    int bytesTotal = 200,
  }) {
    return db.downloadsDao.upsert(
      DownloadsCompanion.insert(
        contentType: 'teaching',
        contentId: _id,
        quality: 'mid',
        state: Value(state),
        bytesReceived: Value(bytesReceived),
        bytesTotal: Value(bytesTotal),
        taskId: const Value('task-1'),
        createdAt: DateTime.utc(2026, 8, 15),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    MediaQuality quality = MediaQuality.mid,
    bool cellular = false,
    bool mobileDataAllowed = false,
    DownloadCapabilities? capabilities,
    InstallPrompt? install,
  }) async {
    final player = InertContentPlayer();
    addTearDown(player.dispose);

    final manager = DownloadManager(
      dao: db.downloadsDao,
      backend: backend,
      diskSpace: const FixedDiskSpace(1000000),
      network: FixedNetworkTransport(cellular: cellular),
      metadataFor: (id) async => id == _id ? _metadata() : null,
      mobileDataAllowed: () async => mobileDataAllowed,
      newTaskId: () => 'task-1',
      now: () => DateTime.utc(2026, 8, 15),
    );
    manager.start();
    addTearDown(manager.dispose);

    final container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        contentPlayerProvider.overrideWithValue(player),
        playbackProgressReporterProvider
            .overrideWithValue(FakePlaybackProgressReporter()),
        networkStatusProvider
            .overrideWithValue(const FixedNetworkStatus(offline: true)),
        downloadManagerProvider.overrideWithValue(manager),
        downloadQualityProvider.overrideWithValue(quality),
        if (capabilities != null)
          downloadCapabilitiesProvider.overrideWithValue(capabilities),
        if (install != null) installPromptProvider.overrideWithValue(install),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('fr'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: ContentPlayerView(
            content: _contentProvider,
            chromeTitle: 'MESSAGE',
            retractedTitle: 'x',
            retractedMessage: 'x',
            onRetry: () {},
            downloadContentType: 'teaching',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('Les cinq états rendent le bon contrôle', () {
    testWidgets('aucune ligne → icône télécharger', (tester) async {
      await pump(tester);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    });

    testWidgets('en cours → anneau de progression + %', (tester) async {
      await seed(
        state: DownloadState.running,
        bytesReceived: 42,
        bytesTotal: 100,
      );
      await pump(tester);

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      // 42 / 100 → 42 %.
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('en pause → icône reprendre', (tester) async {
      await seed(state: DownloadState.paused);
      await pump(tester);
      expect(find.byIcon(Icons.download), findsOneWidget);
    });

    testWidgets('en attente de wifi → icône dédiée', (tester) async {
      await seed(state: DownloadState.waitingWifi);
      await pump(tester);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('complété → coche téléchargé', (tester) async {
      await seed(state: DownloadState.complete);
      await pump(tester);
      expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
    });

    testWidgets('échec → icône réessayer', (tester) async {
      await seed(state: DownloadState.failed);
      await pump(tester);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });

  group('Chaque état déclenche le bon geste', () {
    testWidgets('non téléchargé : tap lance le téléchargement', (tester) async {
      await pump(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(backend.enqueued, hasLength(1));
    });

    testWidgets('en cours : tap met en pause', (tester) async {
      await seed(state: DownloadState.running, bytesReceived: 10);
      await pump(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(backend.paused, contains('task-1'));
    });

    testWidgets('en pause : tap reprend', (tester) async {
      await seed(state: DownloadState.paused);
      await pump(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(backend.resumed, contains('task-1'));
    });

    testWidgets('complété : tap demande confirmation puis supprime',
        (tester) async {
      await seed(state: DownloadState.complete);
      await pump(tester);

      await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
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

    testWidgets('échec : tap relance', (tester) async {
      await seed(state: DownloadState.failed);
      await pump(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(backend.enqueued, hasLength(1));
    });
  });

  group('La qualité choisie part au moteur (F6)', () {
    testWidgets('« haute » télécharge la rendition high', (tester) async {
      await pump(tester, quality: MediaQuality.high);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(backend.enqueued.single.url, 'https://x/high.aac');
    });
  });

  group('Le rassemblement n\'offre pas le téléchargement (v1)', () {
    testWidgets('sans downloadContentType, aucun bouton', (tester) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            contentPlayerProvider.overrideWithValue(player),
            playbackProgressReporterProvider
                .overrideWithValue(FakePlaybackProgressReporter()),
            networkStatusProvider
                .overrideWithValue(const FixedNetworkStatus(offline: true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('fr'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: ContentPlayerView(
              content: _contentProvider,
              chromeTitle: 'RASSEMBLEMENT',
              retractedTitle: 'x',
              retractedMessage: 'x',
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(ContentPlayerView.downloadButtonKey), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Le navigateur (#273) — les mêmes règles, jugées contre un faux backend
  // ═══════════════════════════════════════════════════════════════════════════

  group('ce que le navigateur permet, l\'écran le dit', () {
    testWidgets('pas de moteur de transfert ⇒ pas de bouton du tout',
        (tester) async {
      // Safari : Background Fetch n'y existe pas, quel que soit le code. Un
      // bouton grisé resterait un bouton offert.
      await pump(
        tester,
        capabilities: FakeDownloadCapabilities(available: false),
      );

      expect(find.byKey(ContentPlayerView.downloadButtonKey), findsNothing);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
    });

    testWidgets('sans pause : le pictogramme de l\'anneau est une croix',
        (tester) async {
      // Total inconnu ⇒ pas de pourcentage, donc c'est le pictogramme qui
      // porte le geste — et il doit dire la vérité.
      await seed(state: DownloadState.running, bytesTotal: 0);
      await pump(
        tester,
        capabilities: FakeDownloadCapabilities(canPause: false),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
      // ⚠️ Ce test ne touche pas au geste, et c'est voulu : un total inconnu
      // donne un anneau **indéterminé**, qui tourne sans fin, et le combiner à
      // `runAsync` laissait le test pendu (mesuré). Le geste se juge sur le cas
      // déterminé, juste en dessous.
    });

    testWidgets('sans pause : l\'anneau annule au lieu de mettre en pause',
        (tester) async {
      await seed(state: DownloadState.running, bytesReceived: 10);
      await pump(
        tester,
        capabilities: FakeDownloadCapabilities(canPause: false),
      );

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      // ⚠️ On s'arrête à ce que l'écran a **demandé au moteur**, exactement
      // comme les suppressions de la page Téléchargements : relire la ligne
      // dans la même foulée laissait le test pendu dix minutes (mesuré). Que
      // l'annulation efface la ligne est jugé sur le manager
      // (`download_manager_test.dart`), où il n'y a pas d'arbre de widgets.
      expect(backend.canceled, contains('task-1'));
      expect(backend.paused, isEmpty,
          reason: 'Background Fetch ne sait pas mettre en pause : ne pas '
              'fabriquer une fausse pause');
    });

    testWidgets('stockage non durable : invite à installer, ne télécharge pas',
        (tester) async {
      final capabilities = FakeDownloadCapabilities(durable: false);
      final install = FakeInstallPrompt(InstallOffer.prompt);
      await pump(tester, capabilities: capabilities, install: install);

      // ⚠️ Jamais `pumpAndSettle` ici : cet écran porte une animation
      // continue, et l'attente ne finirait pas (mesuré — le test restait
      // pendu). Deux pompes suffisent : le geste, puis l'ouverture.
      await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(capabilities.asked, 1);
      expect(find.text(_fr.downloadNeedsInstallTitle), findsOneWidget);
      expect(backend.enqueued, isEmpty,
          reason: 'pas un octet tant que le navigateur peut tout évincer');

      await tester.tap(find.byKey(ContentPlayerView.downloadInstallKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(install.shown, 1, reason: 'le bouton ouvre la vraie boîte');
    });

    testWidgets('stockage durable : le téléchargement part normalement',
        (tester) async {
      final capabilities = FakeDownloadCapabilities();
      await pump(tester, capabilities: capabilities);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ContentPlayerView.downloadButtonKey));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(capabilities.asked, 1);
      expect(backend.enqueued, hasLength(1));
      expect(find.text(_fr.downloadNeedsInstallTitle), findsNothing);
    });
  });
}
