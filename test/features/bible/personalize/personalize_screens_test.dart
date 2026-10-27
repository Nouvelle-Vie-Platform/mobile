/// **M4 (#202), les écrans** : l'aperçu des thèmes, le studio de partage
/// (rendu non vide), le téléchargement simulé d'une version, les rappels des
/// Paramètres.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/bible_providers.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/data/placeholder_bible.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_catalog.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_prefs.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_reminders.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_settings_screen.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_versions_screen.dart';
import 'package:maison_du_miracle/features/bible/personalize/my_space_screen.dart';
import 'package:maison_du_miracle/features/bible/personalize/reader_appearance.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/features/bible/plans/plan_logic.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_providers.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_widgets.dart';
import 'package:maison_du_miracle/features/bible/quiz/quiz_providers.dart';
import 'package:maison_du_miracle/features/bible/personalize/share_studio.dart';
import 'package:maison_du_miracle/data/pickers/status_image_picker.dart';
import 'package:maison_du_miracle/models/announcement_view.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_palette.dart';

import '../../../helpers/pump_screen.dart';
import '../data/bible_archive_fixture.dart';

/// Les réglages en mémoire, sans magasin.
class _MemoryPrefs extends BiblePrefsNotifier {
  @override
  BiblePrefs build() => const BiblePrefs();

  @override
  Future<void> update(BiblePrefs Function(BiblePrefs) change) async =>
      state = change(state);
}

class _FakeSink extends BibleImageSink {
  final shared = <Uint8List>[];
  final saved = <Uint8List>[];

  @override
  Future<void> share(BuildContext context, Uint8List png, String name) async =>
      shared.add(png);

  @override
  Future<bool> save(Uint8List png) async {
    saved.add(png);
    return true;
  }
}

final _prefs = biblePrefsProvider.overrideWith(_MemoryPrefs.new);

void main() {
  testWidgets('Thèmes : le sépia repeint l\'aperçu en direct', (tester) async {
    await pumpScreen(
      tester,
      const BibleAppearanceScreen(),
      overrides: [_prefs],
    );
    Color previewColor() => tester
        .widget<ColoredBox>(
          find
              .descendant(
                of: find.byKey(BibleAppearanceScreen.previewKey),
                matching: find.byType(ColoredBox),
              )
              .first,
        )
        .color;
    expect(previewColor(), AppPalette.light.background);

    await tester.tap(find.byKey(BibleAppearanceScreen.themeKey(
      BibleReaderTheme.sepia,
    )));
    await tester.pump();
    expect(
      previewColor(),
      bibleReaderPalette(BibleReaderTheme.sepia).background,
    );

    await tester.tap(find.byKey(BibleAppearanceScreen.fontKey(
      BibleReaderFont.literata,
    )));
    await tester.pump();
    final ctx = tester.element(find.byKey(BibleAppearanceScreen.previewKey));
    final container = ProviderScope.containerOf(ctx);
    expect(container.read(biblePrefsProvider).font, BibleReaderFont.literata);
  });

  testWidgets('Studio : le verset rendu en image, partagé et enregistré',
      (tester) async {
    final sink = _FakeSink();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await pumpScreen(
        tester,
        const BibleShareStudioScreen(
          link: BibleLink('John', 3, from: 16, to: 17),
          versionCode: 'EXA',
        ),
        overrides: [
          bibleCatalogProvider
              .overrideWithValue(const PlaceholderBibleCatalog()),
          bibleImageSinkProvider.overrideWithValue(sink),
          bibleStudioBackdropsProvider.overrideWith(
            (ref) => Stream.value(const [
              StatusBackdrop(
                baseColor: 0xFF336699,
                topColor: 0xFF4477AA,
                bottomColor: 0xFF225588,
                ink: StatusInk.light,
              ),
            ]),
          ),
          statusImagePickerProvider
              .overrideWithValue(const InertStatusImagePicker()),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Jean 3:16-17'), findsOneWidget);
      // Le fond de l'annonce est offert avant les dégradés de la marque.
      await tester.tap(find.byKey(const Key('bible_studio_bg_0')));
      await tester.pump();

      await tester.tap(find.byKey(BibleShareStudioScreen.shareKey));
      for (var i = 0; i < 20 && sink.shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      await tester.ensureVisible(find.byKey(BibleShareStudioScreen.saveKey));
      await tester.tap(find.byKey(BibleShareStudioScreen.saveKey));
      for (var i = 0; i < 20 && sink.saved.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    expect(sink.shared, hasLength(1));
    final png = sink.shared.single;
    expect(png.length, greaterThan(1000));
    // La signature PNG.
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(sink.saved, hasLength(1));
  });

  /// La version servie du test : avec archive, donc téléchargeable depuis C4.
  BibleVersionRow served(String code, {String? archiveUrl}) => BibleVersionRow(
        syncStamp: 0,
        id: 1,
        code: code,
        name: 'Biblia $code',
        sortOrder: 0,
        archiveUrl: archiveUrl,
        publishedAt: DateTime.utc(2026),
      );

  testWidgets('Versions : télécharger installe la vraie archive et indexe',
      (tester) async {
    final indexed = <String>[];
    final root = Directory.systemTemp.createTempSync('bible_c4_ui_');
    addTearDown(() => root.deleteSync(recursive: true));
    final archive = fakeBibleArchive(
      code: 'S21',
      versification: const {
        'Gen': [1]
      },
      books: const {
        1: [
          ['Au commencement']
        ]
      },
    );
    late AppDatabase db;
    await tester.runAsync(() async {
      await pumpScreen(
        tester,
        const BibleVersionsScreen(),
        overrides: [
          mergedBibleCatalogProvider.overrideWithValue(
            MergedBibleCatalog(
                remote: [served('S21', archiveUrl: archive.url)]),
          ),
          bibleInstallerProvider.overrideWithValue(
            BibleVersionInstaller(
              fetch: (url, onProgress) async {
                onProgress(1, 2);
                return archive.bytes;
              },
              root: () async => root,
            ),
          ),
          bibleEnsureIndexedProvider
              .overrideWithValue((code) async => indexed.add(code)),
          bibleReadingStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      // Les deux exemples ne sont plus là : S21 porte une archive, donc une
      // vraie version est proposée (#249). Ce que devient une ligne factice
      // se vérifie désormais dans le test voisin, sur une version sans
      // archive.
      expect(find.byKey(BibleVersionsScreen.rowKey('EXA')), findsNothing);
      await tester.tap(find.byKey(BibleVersionsScreen.downloadKey('S21')));
      for (var i = 0; i < 20 && indexed.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      final ctx = tester.element(find.byType(BibleVersionsScreen));
      db = ProviderScope.containerOf(ctx).read(appDatabaseProvider);
      final row = (await db.select(db.bibleInstalledVersions).get()).single;
      expect(row.code, 'S21');
      expect(row.localPath, '${root.path}/bible/S21');
    });
    expect(indexed, ['S21']);
  });

  testWidgets('Versions : une version sans archive n\'offre pas le bouton',
      (tester) async {
    await pumpScreen(
      tester,
      const BibleVersionsScreen(),
      overrides: [
        mergedBibleCatalogProvider
            .overrideWithValue(MergedBibleCatalog(remote: [served('EWE')])),
        bibleReadingStateProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    expect(find.byKey(BibleVersionsScreen.rowKey('EWE')), findsOneWidget);
    expect(find.byKey(BibleVersionsScreen.downloadKey('EWE')), findsNothing);
    expect(find.text(AppLocalizationsFr().bibleM4VersionSoon), findsOneWidget);
    // Aucune vraie version proposée : les exemples tiennent la place, et
    // aucun ne s'enlève.
    expect(find.byKey(BibleVersionsScreen.rowKey('EXA')), findsOneWidget);
    expect(find.byKey(BibleVersionsScreen.removeKey('EXA')), findsNothing);
  });

  testWidgets('Versions : une archive refusée le dit, et n\'installe rien',
      (tester) async {
    final root = Directory.systemTemp.createTempSync('bible_c4_ko_');
    addTearDown(() => root.deleteSync(recursive: true));
    final archive = fakeBibleArchive(code: 'S21');
    late AppDatabase db;
    await tester.runAsync(() async {
      await pumpScreen(
        tester,
        const BibleVersionsScreen(),
        overrides: [
          mergedBibleCatalogProvider.overrideWithValue(
            MergedBibleCatalog(
                remote: [served('S21', archiveUrl: archive.url)]),
          ),
          bibleInstallerProvider.overrideWithValue(
            BibleVersionInstaller(
              // Les octets servis ne sont pas ceux que l'URL annonce.
              fetch: (url, onProgress) async => [...archive.bytes, 0],
              root: () async => root,
            ),
          ),
          bibleReadingStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      await tester.tap(find.byKey(BibleVersionsScreen.downloadKey('S21')));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      final ctx = tester.element(find.byType(BibleVersionsScreen));
      db = ProviderScope.containerOf(ctx).read(appDatabaseProvider);
      expect(await db.select(db.bibleInstalledVersions).get(), isEmpty);
    });
    await tester.pump();
    expect(
      find.text(AppLocalizationsFr().bibleM4DownloadFailed),
      findsOneWidget,
    );
    // Le bouton est revenu : le geste est rejouable.
    expect(find.byKey(BibleVersionsScreen.downloadKey('S21')), findsOneWidget);
  });

  testWidgets('Versions : la licence paraît sous la traduction (#258)',
      (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(
        tester,
        const BibleVersionsScreen(),
        overrides: [
          mergedBibleCatalogProvider.overrideWithValue(
            MergedBibleCatalog(
              remote: [
                BibleVersionRow(
                  syncStamp: 0,
                  id: 1,
                  code: 'EWE',
                  name: 'Biblia Ewe',
                  language: 'ee',
                  license: '© Bible Society of Ghana, 1913, 2006',
                  sortOrder: 0,
                  publishedAt: DateTime.utc(2026),
                ),
                // Une traduction que le portail sert **sans** licence : le
                // sous-titre doit s'arrêter aux faits, et surtout ne pas
                // afficher le mot « null » à la place.
                BibleVersionRow(
                  syncStamp: 0,
                  id: 2,
                  code: 'LSG',
                  name: 'Louis Segond',
                  language: 'fr',
                  sortOrder: 1,
                  publishedAt: DateTime.utc(2026),
                ),
              ],
            ),
          ),
          bibleEnsureIndexedProvider.overrideWithValue((code) async {}),
          bibleReadingStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );

      // La ligne est bien là, et la langue y est : ce n'est donc pas un écran vide
      // qui ferait passer l'assertion suivante pour acquise.
      expect(find.byKey(BibleVersionsScreen.rowKey('EWE')), findsOneWidget);
      expect(find.textContaining('EE'), findsWidgets);

      // Et la licence est là, **entière** : plusieurs ayants droit exigent la
      // mention exacte, pas un fragment ni une abréviation. Elle en était partie
      // le 26/10 (#242) ; elle revient le 27 (#258), sur sa propre ligne.
      expect(
        find.textContaining('© Bible Society of Ghana, 1913, 2006'),
        findsOneWidget,
      );
      expect(find.byKey(BibleVersionsScreen.rowKey('LSG')), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });
  });

  testWidgets('Paramètres : un rappel s\'active et se reprogramme',
      (tester) async {
    var refreshed = 0;
    final subscriptions = <bool>[];
    await pumpScreen(
      tester,
      const BibleSettingsScreen(),
      overrides: [
        _prefs,
        bibleRemindersRefreshProvider
            .overrideWithValue(() async => refreshed++),
        bibleVerseOfDaySubscriptionProvider
            .overrideWithValue((on) async => subscriptions.add(on)),
      ],
    );
    // La voix du système seulement (Piper retirée).
    expect(find.byKey(BibleSettingsScreen.voiceKey), findsOneWidget);
    await tester.tap(find.byKey(BibleSettingsScreen.verseReminderKey));
    await tester.pump();
    final ctx = tester.element(find.byType(BibleSettingsScreen));
    final prefs = ProviderScope.containerOf(ctx).read(biblePrefsProvider);
    expect(prefs.verseReminder, isTrue);
    expect(refreshed, 1);
    // Un invité n'a pas d'abonnement au push.
    expect(subscriptions, isEmpty);
    await tester.scrollUntilVisible(
      find.byKey(BibleSettingsScreen.aboutKey),
      200,
    );
    expect(find.textContaining('SIL Open Font License'), findsOneWidget);
    expect(find.textContaining('espeak'), findsNothing);
    // La revalidation de session de `pumpScreen` (300 ms).
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Mon espace : badges des plans (M5) puis des quiz (M6)',
      (tester) async {
    await pumpScreen(
      tester,
      const BibleMySpaceScreen(),
      overrides: [
        bibleMySpaceStatsProvider
            .overrideWith((ref) async => const BibleMySpaceStats()),
        bibleBadgesProvider.overrideWithValue({BibleBadge.firstDay}),
        quizBadgesProvider.overrideWithValue({QuizBadge.perfect}),
      ],
    );
    expect(find.byType(BibleBadgeGrid), findsOneWidget);
    BibleMedal medal(Key key) => tester.widget<BibleMedal>(find.byKey(key));
    expect(medal(BibleBadgeGrid.badgeKey(BibleBadge.firstDay)).earned, isTrue);
    expect(medal(BibleBadgeGrid.badgeKey(BibleBadge.week)).earned, isFalse);
    expect(
      medal(BibleMySpaceScreen.quizBadgeKey(QuizBadge.perfect)).earned,
      isTrue,
    );
    expect(
      medal(BibleMySpaceScreen.quizBadgeKey(QuizBadge.firstQuiz)).earned,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 1));
  });
}
