/// **M4 (#202), la logique** : réglages, thèmes, catalogue fusionné et
/// téléchargement simulé, rappels programmés,
/// lecture audio verset par verset.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/bible_providers.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/data/placeholder_bible.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_audio.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_catalog.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_prefs.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_reminders.dart';
import 'package:maison_du_miracle/features/bible/personalize/my_space_screen.dart';
import 'package:maison_du_miracle/features/bible/personalize/personalize_slots.dart';
import 'package:maison_du_miracle/features/bible/personalize/reader_appearance.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/theme/app_palette.dart';
import 'package:maison_du_miracle/theme/app_typography.dart';

import '../../../data/local/local_database_fixtures.dart';

BibleVersionRow _served(
  int id,
  String code, {
  int sortOrder = 0,
  String? archiveUrl,
}) =>
    BibleVersionRow(
      syncStamp: 0,
      id: id,
      code: code,
      name: 'Version $code',
      language: 'ee',
      sizeBytes: 4200000,
      sortOrder: sortOrder,
      archiveUrl: archiveUrl,
      publishedAt: DateTime.utc(2026, 10),
    );

BibleInstalledVersionRow _installed(String code) => BibleInstalledVersionRow(
      code: code,
      name: code,
      installedAt: DateTime.utc(2026, 10),
      indexed: false,
    );

/// Le double du greffon de notification.
class _FakeScheduler implements BibleReminderScheduler {
  final cancelled = <int>[];
  final scheduled = <(int, DateTime, String, String)>[];

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> schedule(int id, DateTime at, String title, String body) async =>
      scheduled.add((id, at, title, body));
}

/// Une voix qui « dit » instantanément, et retient ce qu'elle a dit.
class _FakeSpeech extends BibleSpeech {
  final said = <String>[];
  Completer<void>? hold;

  @override
  Future<void> speak(String text, double rate) async {
    said.add(text);
    await hold?.future;
  }

  /// Ne libère rien : le test tient la voix par [hold].
  @override
  Future<void> stop() async {}
}

void main() {
  group('Réglages', () {
    test('défauts : clair, Atkinson, rappels éteints', () {
      final p = BiblePrefs.parse(null);
      expect(p.theme, BibleReaderTheme.light);
      expect(p.font, BibleReaderFont.atkinson);
      expect(p.verseReminder, isFalse);
      expect(p.planReminder, isFalse);
    });

    test('aller-retour JSON, et une valeur illisible garde son défaut', () {
      const p = BiblePrefs(
        theme: BibleReaderTheme.sepia,
        font: BibleReaderFont.literata,
        fontSize: 22,
        lineHeight: 1.8,
        verseReminder: true,
        verseReminderMinutes: 6 * 60 + 30,
      );
      final back = BiblePrefs.parse(jsonEncode(p.toJson()));
      expect(back.theme, BibleReaderTheme.sepia);
      expect(back.font, BibleReaderFont.literata);
      expect(back.fontSize, 22);
      expect(back.lineHeight, 1.8);
      expect(back.verseReminderMinutes, 390);

      final odd = BiblePrefs.parse(
        '{"theme":"pink","fontSize":99,"verseReminderMinutes":9999}',
      );
      expect(odd.theme, BibleReaderTheme.light);
      expect(odd.fontSize, BiblePrefs.maxFontSize);
      expect(odd.verseReminderMinutes, 7 * 60);
      expect(BiblePrefs.parse('pas du json').theme, BibleReaderTheme.light);
    });

    test('le réglage s\'écrit dans app_settings et se relit', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      c.read(biblePrefsProvider);
      await c
          .read(biblePrefsProvider.notifier)
          .update((p) => p.copyWith(theme: BibleReaderTheme.dark));
      final row = await (db.select(db.appSettings)
            ..where((t) => t.key.equals(kBiblePrefsKey)))
          .getSingle();
      expect(BiblePrefs.parse(row.value).theme, BibleReaderTheme.dark);

      final again = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(again.dispose);
      again.read(biblePrefsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(again.read(biblePrefsProvider).theme, BibleReaderTheme.dark);
    });
  });

  group('Thèmes', () {
    test('trois palettes distinctes, le sépia a son propre fond', () {
      final light = bibleReaderPalette(BibleReaderTheme.light);
      final dark = bibleReaderPalette(BibleReaderTheme.dark);
      final sepia = bibleReaderPalette(BibleReaderTheme.sepia);
      expect(light, AppPalette.light);
      expect(dark, AppPalette.dark);
      expect(sepia.background, isNot(light.background));
      expect(sepia.textPrimary, isNot(light.textPrimary));
    });

    test('le style d\'un verset suit police, taille et interligne', () {
      final style = bibleVerseTextStyle(
        const BiblePrefs(
          font: BibleReaderFont.literata,
          fontSize: 24,
          lineHeight: 2,
        ),
        AppPalette.dark,
      );
      expect(style.fontFamily, 'Literata');
      expect(style.fontSize, 24);
      expect(style.height, 2);
      expect(style.color, AppPalette.dark.textPrimary);
      expect(
        bibleFontFamily(BibleReaderFont.atkinson),
        AppTypography.fontFamily,
      );
    });
  });

  group('Catalogue fusionné', () {
    test('les deux factices d\'abord, puis S5 dans l\'ordre du portail',
        () async {
      final catalog = MergedBibleCatalog(
        remote: [
          _served(2, 'EWE', sortOrder: 2),
          _served(1, 'LSG', sortOrder: 1),
          _served(3, 'EXA'), // un code factice servi ne se double pas
          _served(4, 'ZIP', archiveUrl: 'https://x/zip'),
        ],
        installed: [_installed('LSG')],
      );
      final versions = await catalog.versions();
      expect(versions.map((v) => v.code), ['EXA', 'EXB', 'ZIP', 'LSG', 'EWE']);
      expect(
          versions.map((v) => v.installed), [true, true, false, true, false]);
      final entries = {for (final e in catalog.entries) e.version.code: e};
      expect(entries['EXA']!.builtIn, isTrue);
      expect(entries['EWE']!.downloadable, isTrue);
      expect(entries['ZIP']!.downloadable, isFalse);
      // Installée : du texte ; pas installée : rien.
      expect(catalog.sourceFor('LSG'), isNotNull);
      expect(await catalog.sourceFor('LSG')!.chapter('John', 3), isNotEmpty);
      expect(catalog.sourceFor('EWE'), isNull);
      expect(catalog.sourceFor('EXB'), isA<PlaceholderBibleSource>());
      // Même contenu, même catalogue : le chapitre ouvert ne se recharge pas.
      expect(MergedBibleCatalog(), MergedBibleCatalog());
      expect(catalog, isNot(MergedBibleCatalog()));
    });

    test('télécharger : progression simulée, installation, indexation',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final entry =
          MergedBibleCatalog(remote: [_served(1, 'EWE')]).entries.last;
      final indexed = <String>[];
      final progress = await installBibleVersion(
        db,
        entry,
        ensureIndexed: (code) async => indexed.add(code),
        step: Duration.zero,
      ).toList();
      expect(progress, hasLength(kSimulatedSteps));
      expect(progress.last, 1.0);
      final rows = await db.select(db.bibleInstalledVersions).get();
      expect(rows.single.code, 'EWE');
      expect(indexed, ['EWE']);

      await removeBibleVersion(db, 'EWE');
      expect(await db.select(db.bibleInstalledVersions).get(), isEmpty);
    });

    test('après installation, la version servie est indexée (M3)', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      await db.into(db.bibleVersions).insert(
            BibleVersionsCompanion.insert(
              id: const Value(7),
              code: 'EWE',
              name: 'Biblia',
              publishedAt: Value(DateTime.utc(2026)),
            ),
          );
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final entry =
          MergedBibleCatalog(remote: [_served(7, 'EWE')]).entries.last;
      await installBibleVersion(
        db,
        entry,
        ensureIndexed: container.read(bibleEnsureIndexedProvider),
        step: Duration.zero,
      ).drain<void>();
      final n = await db
          .customSelect(
            "SELECT count(*) AS n FROM bible_fts WHERE version_code = 'EWE'",
          )
          .getSingle();
      expect(n.read<int>('n'), greaterThan(30000));
      final row = (await db.select(db.bibleInstalledVersions).get()).single;
      expect(row.indexed, isTrue);
    });

    test('bibleCatalogProvider rend le catalogue fusionné du magasin',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      await db.into(db.bibleVersions).insert(
            BibleVersionsCompanion.insert(
              id: const Value(7),
              code: 'EWE',
              name: 'Biblia',
              publishedAt: Value(DateTime.utc(2026)),
            ),
          );
      await db.into(db.bibleInstalledVersions).insert(
            BibleInstalledVersionsCompanion.insert(
              code: 'EWE',
              name: 'Biblia',
              installedAt: DateTime.utc(2026),
            ),
          );
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(bibleVersionsProvider, (_, __) {});
      addTearDown(sub.close);
      c.listen(bibleServedVersionsProvider, (_, __) {});
      c.listen(bibleInstalledVersionsProvider, (_, __) {});
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final codes = c.read(bibleVersionsProvider).value?.map((v) => v.code);
        if (codes?.contains('EWE') ?? false) break;
      }
      final versions = c.read(bibleVersionsProvider).value!;
      expect(versions.map((v) => v.code), ['EXA', 'EXB', 'EWE']);
      expect(c.read(bibleCatalogProvider).sourceFor('EWE'), isNotNull);
    });
  });

  group('Rappels', () {
    final l10n = AppLocalizationsFr();

    Future<_FakeScheduler> run(
      BiblePrefs prefs,
      DateTime now, {
      bool hasPlan = true,
      bool planDoneToday = false,
    }) async {
      final scheduler = _FakeScheduler();
      await syncBibleReminders(
        prefs: prefs,
        scheduler: scheduler,
        l10n: l10n,
        verseFor: (day) async => const BibleLink('John', 3, from: 16),
        textFor: (link) async => 'Texte $link',
        now: now,
        hasPlan: hasPlan,
        planDoneToday: planDoneToday,
      );
      return scheduler;
    }

    test('éteints par défaut : tout est annulé, rien n\'est programmé',
        () async {
      final s = await run(const BiblePrefs(), DateTime(2026, 10, 13, 8));
      expect(s.cancelled, hasLength(2 * kReminderDays));
      expect(s.scheduled, isEmpty);
    });

    test('verset du jour à 7 h et plan à 20 h, sur sept jours', () async {
      final s = await run(
        const BiblePrefs(verseReminder: true, planReminder: true),
        DateTime(2026, 10, 13, 8),
      );
      final verses = s.scheduled.where((e) => e.$1 < kPlanReminderBaseId);
      final plans = s.scheduled.where((e) => e.$1 >= kPlanReminderBaseId);
      // 7 h est passé aujourd'hui : six jours ; 20 h ne l'est pas : sept.
      expect(verses, hasLength(6));
      expect(plans, hasLength(7));
      expect(verses.first.$2, DateTime(2026, 10, 14, 7));
      expect(verses.first.$3, l10n.bibleM4VerseOfDayTitle);
      expect(verses.first.$4, contains('Jean 3:16'));
      expect(plans.first.$2, DateTime(2026, 10, 13, 20));
      expect(plans.first.$4, l10n.bibleM4PlanReminderBody);
    });

    test('lecture du plan (M5) : rien sans plan, pas aujourd\'hui si faite',
        () async {
      const prefs = BiblePrefs(planReminder: true);
      final at = DateTime(2026, 10, 13, 8);
      expect((await run(prefs, at, hasPlan: false)).scheduled, isEmpty);
      final done = await run(prefs, at, planDoneToday: true);
      expect(done.scheduled, hasLength(kReminderDays - 1));
      expect(done.scheduled.first.$2, DateTime(2026, 10, 14, 20));
    });

    test('le verset du jour vient du magasin, sinon de la liste intégrée',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      await db.into(db.bibleVerseOfDays).insert(
            BibleVerseOfDaysCompanion.insert(
              id: const Value(1),
              day: '2026-10-13',
              book: 'Rom',
              chapter: 8,
              verseFrom: const Value(28),
              publishedAt: Value(DateTime.utc(2026)),
            ),
          );
      final today = await verseOfDayFor(db, DateTime(2026, 10, 13));
      expect(today.labelFr, 'Romains 8:28');
      final tomorrow = await verseOfDayFor(db, DateTime(2026, 10, 14));
      expect(kBuiltInVersesOfDay, contains(tomorrow));
      for (final link in kBuiltInVersesOfDay) {
        expect(isValidBibleRef(link), isTrue, reason: link.labelFr);
      }
    });
  });

  group('Lecture audio', () {
    ProviderContainer container(_FakeSpeech speech) {
      final db = openTestDatabase();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bibleSpeechProvider.overrideWithValue(speech),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('verset par verset, à partir du verset choisi, puis s\'arrête',
        () async {
      final speech = _FakeSpeech();
      final c = container(speech);
      final verses = const PlaceholderBibleSource('EXA').chapterSync('Ps', 117);
      await c
          .read(bibleAudioProvider.notifier)
          .playFrom('EXA', 'Ps', 117, verse: 2);
      expect(speech.said, [verses[1].text]);
      final s = c.read(bibleAudioProvider)!;
      expect(s.playing, isFalse);
      expect(s.verse, isNull);
    });

    test('le verset en cours est surligné ; pause et chapitre suivant',
        () async {
      final speech = _FakeSpeech()..hold = Completer<void>();
      final c = container(speech);
      final audio = c.read(bibleAudioProvider.notifier);
      unawaited(audio.playFrom('EXA', 'John', 3, verse: 16));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(bibleAudioProvider)!.verse, 16);
      expect(c.read(bibleAudioProvider)!.playing, isTrue);

      await audio.pause();
      expect(c.read(bibleAudioProvider)!.playing, isFalse);
      expect(c.read(bibleAudioProvider)!.verse, 16);

      unawaited(audio.skipChapter(1));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final s = c.read(bibleAudioProvider)!;
      expect((s.book, s.chapter, s.verse), ('John', 4, 1));

      await audio.stop();
      expect(c.read(bibleAudioProvider), isNull);
    });
  });

  group('Emplacements', () {
    test('Plus, raccourci Hors ligne, actions de verset, surlignage', () {
      expect(
        personalizeSlots.moreEntries.map((e) => e.id),
        ['my_space', 'offline', 'appearance', 'settings'],
      );
      expect(personalizeSlots.homeShortcuts.single.id, 'offline');
      expect(
        personalizeSlots.verseActions.map((a) => a.id),
        ['share_image', 'listen'],
      );
      expect(personalizeSlots.chapterDecorators, hasLength(1));
    });

    test('Mon espace : chiffres lus du magasin, sans miroir pour l\'invité',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      await db.bibleDao
          .markChapterRead(member: false, book: 'John', chapter: 3);
      await db.bibleDao
          .markChapterRead(member: false, book: 'John', chapter: 4);
      await db.into(db.localBibleMarks).insert(
            LocalBibleMarksCompanion.insert(
              id: 'm1',
              kind: 'favorite',
              book: 'John',
              chapter: 3,
              clientCreatedAt: DateTime.utc(2026),
              clientUpdatedAt: DateTime.utc(2026),
            ),
          );
      await db.into(db.bibleMarks).insert(
            BibleMarksCompanion.insert(
                id: 'srv', kind: 'favorite', book: 'Ps', chapter: 1),
          );
      final guest = await readBibleMySpaceStats(db, member: false);
      expect(guest.chaptersRead, 2);
      expect(guest.favorites, 1);
      expect(guest.notes, 0);
      final member = await readBibleMySpaceStats(db, member: true);
      expect(member.favorites, 2);
    });

    test('Mon espace : la série de lecture, rompue après un jour sans lire',
        () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      await db.bibleDao.markChapterRead(
          member: false, book: 'John', chapter: 1, now: DateTime(2026, 10, 12));
      await db.bibleDao.markChapterRead(
          member: false, book: 'John', chapter: 2, now: DateTime(2026, 10, 13));
      Future<int> streak(DateTime now, {bool member = false}) async =>
          (await readBibleMySpaceStats(db, member: member, now: now))
              .streakDays;
      expect(await streak(DateTime(2026, 10, 13, 20)), 2);
      expect(await streak(DateTime(2026, 10, 14, 8)), 2);
      expect(await streak(DateTime(2026, 10, 15, 8)), 0);

      // Membre sans ligne locale : la série du miroir.
      await db.delete(db.localBibleReadingState).go();
      await db.syncDao.applyPage(
        db.syncDao.bibleReadingStatesCollection,
        upserts: [
          BibleReadingStatesCompanion.insert(
            id: 'srv-1',
            streakDays: const Value(9),
            lastReadOn: const Value('2026-10-13'),
          ),
        ],
        cursor: 'c1',
      );
      expect(await streak(DateTime(2026, 10, 13, 20), member: true), 9);
      expect(await streak(DateTime(2026, 10, 13, 20)), 0);
    });
  });
}
