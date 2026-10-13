/// **Le module Bible** (M1, #199), à travers le vrai routeur : la coquille à
/// cinq onglets (mémoire, retour, invité, emplacements), le parcours livre →
/// chapitre → verset, et le lecteur (glissement, version, position, chapitre
/// lu, lien `nv://bible`).
///
/// Tout ce qui touche le magasin Drift vit dans **un seul** `runAsync` par
/// test (un flux Drift attendu sous l'horloge factice fige le montage).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/features/bible/data/placeholder_bible.dart';
import 'package:maison_du_miracle/features/bible/reader/bible_reader_screen.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_browser.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_shell.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_slots.dart';
import 'package:maison_du_miracle/features/notes_editor/links/note_link_opener.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/screens/notes/notes_tab.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../../helpers/fake_api.dart';
import '../../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();

final Override _radioOff = radioRepositoryProvider.overrideWithValue(
  const FixedRadioRepository(RadioAntenna.unknown),
);

/// Les écrans d'attente de la coquille : sans aucun emplacement rempli (les
/// tranches M2–M7 remplissent « Plus » et « Accueil »).
final Override _noSlots =
    bibleSlotsProvider.overrideWithValue(const BibleSlots());

late FakeAdapter _wire;

/// `settle`, avec des tours de **vraie** boucle d'événements entre les images.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<LocalBibleReadingStateRow?> _localState(ProviderContainer c) async {
  final db = c.read(appDatabaseProvider);
  return (db.select(db.localBibleReadingState)..limit(1)).getSingleOrNull();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    _wire = FakeAdapter(
      (options) => throw StateError(
        'requête HTTP interdite : ${options.method} ${options.path}',
      ),
    );
    ApiClient.instance.dio.httpClientAdapter = _wire;
  });

  group('La coquille', () {
    testWidgets('cinq onglets, la Bible d\'abord, et rien sur le fil',
        (tester) async {
      await tester.runAsync(() async {
        final router = await pumpGuestApp(
            tester, guestContainer(extra: [_radioOff, _noSlots]));
        router.push('/bible');
        await _settle(tester);

        expect(find.byType(BibleShell), findsOneWidget);
        for (final tab in BibleModuleTab.values) {
          expect(find.byKey(BibleShell.tabKey(tab)), findsOneWidget);
        }
        expect(find.byKey(BibleBrowser.testamentTabsKey), findsOneWidget);
        // Les pilules Bible / Notes ont disparu.
        expect(find.byKey(const Key('bible_tabs')), findsNothing);

        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.home)));
        await _settle(tester);
        // L'accueil (M7) : l'en-tête du verset du jour.
        expect(find.text(_fr.bibleHomeHeroTitle), findsOneWidget);

        await tester
            .tap(find.byKey(BibleShell.tabKey(BibleModuleTab.favorites)));
        await _settle(tester);
        expect(find.text(_fr.bibleM2Empty), findsOneWidget);

        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.more)));
        await _settle(tester);
        // M4 remplit l'onglet Plus (Mon espace, Paramètres…).
        expect(find.byKey(const Key('bible_more_settings')), findsOneWidget);

        // Notes : la liste existante — pour un invité, sa porte de session.
        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.notes)));
        await _settle(tester);
        expect(find.byType(NotesTab), findsOneWidget);
        expect(find.byKey(NotesTab.signInButtonKey), findsOneWidget);

        // Seul le geste « ouvert » du verset du jour part (M7).
        expect(
          _wire.requests.map((r) => r.path),
          everyElement(endsWith('/bible/verse-of-day/events')),
        );
      });
    });

    testWidgets('le dernier onglet est mémorisé ; `?tab=` l\'emporte',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff, _noSlots]);
        final router = await pumpGuestApp(tester, container);
        router.push('/bible');
        await _settle(tester);

        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.more)));
        await _settle(tester);
        expect(
          await container.read(appDatabaseProvider).settingsDao.bibleTab(),
          'more',
        );

        router.pop();
        await _settle(tester);
        router.push('/bible');
        await _settle(tester);
        // M4 remplit l'onglet Plus (Mon espace, Paramètres…).
        expect(find.byKey(const Key('bible_more_settings')), findsOneWidget);

        router.pop();
        await _settle(tester);
        router.push('/bible?tab=favorites');
        await _settle(tester);
        expect(find.text(_fr.bibleM2Empty), findsOneWidget);
      });
    });

    testWidgets('la flèche ramène à l\'accueil de l\'église', (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/bible');
        await _settle(tester);

        await tester.tap(find.byKey(BibleShell.backKey));
        await _settle(tester);
        expect(router.state.matchedLocation, '/home');
        expect(find.byType(BibleShell), findsNothing);

        // Ouvert sans pile (lien profond) : même destination.
        router.go('/bible');
        await _settle(tester);
        await tester.tap(find.byKey(BibleShell.backKey));
        await _settle(tester);
        expect(router.state.matchedLocation, '/home');
      });
    });

    testWidgets('les emplacements : une entrée de Plus, une section d\'Accueil',
        (tester) async {
      var tapped = 0;
      await tester.runAsync(() async {
        final router = await pumpGuestApp(
          tester,
          guestContainer(
            extra: [
              _radioOff,
              bibleSlotsProvider.overrideWithValue(
                BibleSlots.merge([
                  BibleSlots(
                    moreEntries: [
                      BibleMoreEntry(
                        id: 'plans',
                        order: 10,
                        icon: Icons.event_note,
                        label: (_) => 'Plans de lecture',
                        onTap: (_, __) => tapped++,
                      ),
                    ],
                    homeSections: [
                      BibleHomeSection(
                        id: 'vod',
                        order: 0,
                        builder: (_) => const Text('Verset du jour'),
                      ),
                    ],
                  ),
                ]),
              ),
            ],
          ),
        );
        router.push('/bible?tab=more');
        await _settle(tester);
        expect(find.text(_fr.bibleMoreSoon), findsNothing);
        await tester.tap(find.text('Plans de lecture'));
        await _settle(tester);
        expect(tapped, 1);

        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.home)));
        await _settle(tester);
        expect(find.text('Verset du jour'), findsOneWidget);
      });
    });
  });

  group('Parcourir', () {
    testWidgets(
        'testament → livre → chapitre → verset, puis « Commencer Jean 3 »',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff]);
        final router = await pumpGuestApp(tester, container);
        router.push('/bible?tab=bible');
        await _settle(tester);

        // Ancien Testament d'abord.
        expect(find.byKey(BibleBrowser.bookKey('Gen')), findsOneWidget);
        expect(find.text(_fr.bibleChapterCount(50)), findsOneWidget);
        expect(find.byKey(BibleBrowser.bookKey('John')), findsNothing);

        await tester.tap(find.text(_fr.bibleNewTestament));
        await _settle(tester);
        await tester.tap(find.byKey(BibleBrowser.bookKey('John')));
        await _settle(tester);

        expect(find.text(_fr.bibleChooseChapter), findsOneWidget);
        expect(find.byKey(BibleBrowser.chapterKey(21)), findsOneWidget);
        expect(find.byKey(BibleBrowser.chapterKey(22)), findsNothing);

        await tester.tap(find.byKey(BibleBrowser.chapterKey(3)));
        await _settle(tester);
        expect(find.text(_fr.bibleChooseVerse), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(BibleBrowser.verseKey(36)),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.byKey(BibleBrowser.verseKey(37)), findsNothing);

        await tester.tap(find.byKey(BibleBrowser.startKey));
        await _settle(tester);
        expect(router.state.matchedLocation, '/bible/read/John/3');
        expect(find.textContaining(kPlaceholderMark), findsOneWidget);

        final state = await _localState(container);
        expect((state!.book, state.chapter, state.versionCode),
            ('John', 3, 'EXA'));

        // Retour à la grille : le chapitre courant se distingue, sans pastel.
        router.pop();
        await _settle(tester);
        expect(find.byKey(BibleBrowser.verseKey(1)), findsOneWidget);
      });
    });

    testWidgets('la recherche rapide trouve un livre sans accent',
        (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/bible?tab=bible');
        await _settle(tester);

        await tester.enterText(
            find.byKey(BibleBrowser.searchFieldKey), 'esaie');
        await _settle(tester);
        expect(find.byKey(BibleBrowser.bookKey('Isa')), findsOneWidget);
        expect(find.byKey(BibleBrowser.bookKey('Gen')), findsNothing);

        await tester.enterText(find.byKey(BibleBrowser.searchFieldKey), 'jn');
        await _settle(tester);
        expect(find.byKey(BibleBrowser.bookKey('John')), findsOneWidget);

        await tester.enterText(find.byKey(BibleBrowser.searchFieldKey), 'zzz');
        await _settle(tester);
        expect(find.text(_fr.bibleNoBookFound), findsOneWidget);
      });
    });

    testWidgets('un verset touché ouvre le lecteur sur lui', (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/bible?tab=bible');
        await _settle(tester);
        await tester.tap(find.byKey(BibleBrowser.bookKey('Gen')));
        await _settle(tester);
        await tester.tap(find.byKey(BibleBrowser.chapterKey(1)));
        await _settle(tester);
        await tester.tap(find.byKey(BibleBrowser.verseKey(5)));
        await _settle(tester);

        expect(router.state.matchedLocation, '/bible/read/Gen/1');
        expect(router.state.uri.queryParameters['v'], '5');
      });
    });
  });

  group('Le lecteur', () {
    testWidgets(
        'on glisse d\'un chapitre à l\'autre, et d\'un livre à l\'autre',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff]);
        final router = await pumpGuestApp(tester, container);
        router.push('/bible/read/John/21');
        await _settle(tester);

        expect(
            find.byKey(BibleReaderScreen.pageKey('John', 21)), findsOneWidget);
        await tester.drag(
          find.byKey(BibleReaderScreen.pagesKey),
          const Offset(-600, 0),
        );
        await _settle(tester);
        expect(
            find.byKey(BibleReaderScreen.pageKey('Acts', 1)), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(BibleReaderScreen.headerKey),
            matching: find.text('Actes 1'),
          ),
          findsOneWidget,
        );
        expect((await _localState(container))!.book, 'Acts');

        await tester.drag(
          find.byKey(BibleReaderScreen.pagesKey),
          const Offset(600, 0),
        );
        await _settle(tester);
        await tester.drag(
          find.byKey(BibleReaderScreen.pagesKey),
          const Offset(600, 0),
        );
        await _settle(tester);
        expect(
            find.byKey(BibleReaderScreen.pageKey('John', 20)), findsOneWidget);
        final state = await _localState(container);
        expect((state!.book, state.chapter), ('John', 20));
      });
    });

    testWidgets('l\'en-tête rouvre le choix du chapitre', (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/bible/read/John/3');
        await _settle(tester);

        await tester.tap(find.byKey(BibleReaderScreen.headerKey));
        await _settle(tester);
        // La feuille ouvre directement les chapitres de Jean.
        await tester.tap(find.byKey(BibleBrowser.chapterKey(10)));
        await _settle(tester);
        expect(
            find.byKey(BibleReaderScreen.pageKey('John', 10)), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
      });
    });

    testWidgets('changer de version change le texte, et se retient',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff]);
        final router = await pumpGuestApp(tester, container);
        router.push('/bible/read/John/3');
        await _settle(tester);

        const a = PlaceholderBibleSource('EXA');
        const b = PlaceholderBibleSource('EXB', variant: 1);
        expect(find.textContaining(a.verseText('John', 3, 2)), findsOneWidget);

        await tester.tap(find.byKey(BibleReaderScreen.versionKey));
        await _settle(tester);
        await tester.tap(find.byKey(const Key('bible_version_EXB')).last);
        await _settle(tester);

        expect(find.textContaining(b.verseText('John', 3, 2)), findsOneWidget);
        expect((await _localState(container))!.versionCode, 'EXB');
      });
    });

    testWidgets('un chapitre défilé jusqu\'au bout est marqué lu',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff]);
        final router = await pumpGuestApp(tester, container);
        router.push('/bible/read/Ps/119');
        await _settle(tester);
        var state = await _localState(container);
        expect(jsonDecode(state!.readChapters ?? '{}'), isEmpty);

        await tester.drag(
          find.byKey(BibleReaderScreen.pageKey('Ps', 119)),
          const Offset(0, -100000),
        );
        await _settle(tester);
        state = await _localState(container);
        expect(jsonDecode(state!.readChapters!), {
          'Ps': [119],
        });

        // Un chapitre qui tient à l'écran est lu d'office.
        router.go('/bible/read/Ps/117');
        await _settle(tester);
        state = await _localState(container);
        expect((jsonDecode(state!.readChapters!) as Map)['Ps'], [117, 119]);
      });
    });

    testWidgets(
        'un lien `nv://bible/John/3/16-18` ouvre le lecteur au verset 16, '
        'surligné un instant', (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff]);
        final router = await pumpGuestApp(tester, container);
        router.push('/bible?tab=bible');
        await _settle(tester);

        final element = tester.element(find.byType(BibleShell));
        await NoteLinkOpener.open(
          element,
          element as WidgetRef,
          'nv://bible/John/3/16-18',
        );
        await _settle(tester);

        expect(router.state.matchedLocation, '/bible/read/John/3');
        expect(router.state.uri.queryParameters['v'], '16-18');
        final v16 = find.byKey(BibleReaderScreen.verseKey(16));
        expect(v16.hitTestable(), findsOneWidget);

        Color? colorOf(int verse) {
          final box = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(BibleReaderScreen.verseKey(verse)),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return (box.decoration! as BoxDecoration).color;
        }

        expect(colorOf(16), isNotNull);
        expect(colorOf(18), isNotNull);
        expect(colorOf(19), isNull);
        expect((await _localState(container))!.verse, 16);

        await Future<void>.delayed(BibleReaderScreen.flashDuration);
        await _settle(tester);
        expect(colorOf(16), isNull);
      });
    });
  });
}
