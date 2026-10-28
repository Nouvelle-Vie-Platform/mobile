/// **Le module Bible** (M1 à M7, #199–#205), à travers le vrai routeur : la
/// coquille à quatre onglets remplis par les tranches (mémoire, retour, loupe,
/// invité, emplacements, écrans d'attente, invitation sans Bible — #265), le
/// parcours livre →
/// chapitre → verset, et le lecteur (glissement, version, position, chapitre
/// lu, lien `nv://bible`).
///
/// Tout ce qui touche le magasin Drift vit dans **un seul** `runAsync` par
/// test (un flux Drift attendu sous l'horloge factice fige le montage).
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
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
import 'package:maison_du_miracle/features/bible/personalize/bible_versions_screen.dart';
import 'package:maison_du_miracle/features/bible/reader/bible_reader_screen.dart';
import 'package:maison_du_miracle/features/bible/reader/marker_highlight.dart';
import 'package:maison_du_miracle/features/bible/search/bible_search_screen.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_browser.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_favorites_screen.dart';
import 'package:maison_du_miracle/features/bible/home/home_view.dart';
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
/// tranches M2–M7 remplissent Accueil, Favori et Plus).
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
    testWidgets(
        'quatre onglets, chacun rempli par sa tranche, et rien sur le fil '
        'que le geste du verset du jour', (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/bible');
        await _settle(tester);

        expect(find.byType(BibleShell), findsOneWidget);
        for (final tab in BibleModuleTab.values) {
          expect(find.byKey(BibleShell.tabKey(tab)), findsOneWidget);
        }
        // Bible (M1) d'abord, avec la loupe (M3).
        expect(find.byKey(BibleBrowser.testamentTabsKey), findsOneWidget);
        expect(find.byKey(BibleShell.searchKey), findsOneWidget);
        // Les pilules Bible / Notes ont disparu.
        expect(find.byKey(const Key('bible_tabs')), findsNothing);

        // Accueil (M7) : la maquette, sans barre bleue — sa propre flèche et
        // sa barre de recherche, pas la loupe de la coquille.
        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.home)));
        await _settle(tester);
        expect(find.text(_fr.bibleHomeHeroTitle), findsOneWidget);
        expect(find.byKey(BibleHomeKeys.back), findsOneWidget);
        expect(find.byKey(BibleHomeKeys.search), findsOneWidget);
        expect(find.byKey(BibleShell.searchKey), findsNothing);

        // Mon espace (#265) : Favoris, puis M4 ; Rechercher, plans, défis et
        // quiz n'y sont plus — l'accueil les porte.
        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.more)));
        await _settle(tester);
        for (final id in [
          'favorites',
          'my_space',
          'offline',
          'appearance',
          'settings',
        ]) {
          expect(find.byKey(Key('bible_more_$id'), skipOffstage: false),
              findsOneWidget,
              reason: id);
        }
        for (final id in ['search', 'plans', 'challenges', 'quiz']) {
          expect(find.byKey(Key('bible_more_$id'), skipOffstage: false),
              findsNothing,
              reason: id);
        }
        expect(find.text(_fr.bibleMyBadges), findsOneWidget);

        // Favoris (M2) : un écran poussé, l'état vide de la liste.
        await tester.tap(find.byKey(BibleShell.favoritesKey));
        await _settle(tester);
        expect(find.byType(BibleFavoritesScreen), findsOneWidget);
        expect(find.text(_fr.bibleM2Empty), findsOneWidget);
        Navigator.of(tester.element(find.byType(BibleFavoritesScreen))).pop();
        await _settle(tester);

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

    testWidgets('la loupe ouvre la recherche (M3)', (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/bible?tab=bible');
        await _settle(tester);
        await tester.tap(find.byKey(BibleShell.searchKey));
        await _settle(tester);
        expect(find.byType(BibleSearchScreen), findsOneWidget);
      });
    });

    testWidgets('sans emplacement : les écrans d\'attente', (tester) async {
      await tester.runAsync(() async {
        final router = await pumpGuestApp(
            tester, guestContainer(extra: [_radioOff, _noSlots]));
        router.push('/bible?tab=home');
        await _settle(tester);
        expect(find.text(_fr.bibleHomeSoon), findsOneWidget);
        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.more)));
        await _settle(tester);
        await tester.tap(find.byKey(BibleShell.favoritesKey));
        await _settle(tester);
        expect(find.text(_fr.bibleFavoritesSoon), findsOneWidget);
      });
    });

    testWidgets('le dernier onglet est mémorisé ; `?tab=` l\'emporte',
        (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff]);
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
        expect(find.byKey(const Key('bible_more_settings')), findsOneWidget);

        router.pop();
        await _settle(tester);
        // Un ancien lien (#265) : l'onglet Bible, Favoris poussé dessus.
        router.push('/bible?tab=favorites');
        await _settle(tester);
        expect(find.byType(BibleFavoritesScreen), findsOneWidget);
        expect(find.text(_fr.bibleM2Empty), findsOneWidget);
        Navigator.of(tester.element(find.byType(BibleFavoritesScreen))).pop();
        await _settle(tester);
        expect(find.byKey(BibleBrowser.testamentTabsKey), findsOneWidget);

        // Un ancien onglet **mémorisé** `favorites` : l'onglet Bible seul.
        router.pop();
        await _settle(tester);
        await container
            .read(appDatabaseProvider)
            .settingsDao
            .setBibleTab('favorites');
        router.push('/bible');
        await _settle(tester);
        expect(find.byKey(BibleBrowser.testamentTabsKey), findsOneWidget);
        expect(find.byType(BibleFavoritesScreen), findsNothing);
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

    testWidgets(
        'les emplacements : une ligne de Mon espace, une section d\'Accueil',
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

  group('Sans Bible téléchargée (#265)', () {
    final invitation = find.byKey(BibleVersionsScreen.invitationKey);

    testWidgets(
        'les exemples seuls : l\'invitation sur Accueil, Bible et Mon espace, '
        'la barre reste, Notes reste ouvert', (tester) async {
      await tester.runAsync(() async {
        // `null` : le vrai provider, lu dans le magasin — vide, donc les
        // seules Bibles d'exemple.
        final router = await pumpGuestApp(
          tester,
          guestContainer(bibleDownloaded: null, extra: [_radioOff]),
        );
        router.push('/bible?tab=home');
        await _settle(tester);
        expect(invitation, findsOneWidget);
        expect(find.text(_fr.bibleHomeHeroTitle), findsNothing);
        // Catalogue vide (aucune synchro) : se connecter, et aucun exemple.
        expect(find.text(_fr.bibleInviteOffline), findsOneWidget);
        expect(find.byKey(BibleVersionsScreen.rowKey('EXA')), findsNothing);
        expect(find.byKey(BibleShell.navKey), findsOneWidget);

        for (final tab in [BibleModuleTab.bible, BibleModuleTab.more]) {
          await tester.tap(find.byKey(BibleShell.tabKey(tab)));
          await _settle(tester);
          expect(invitation, findsOneWidget, reason: tab.name);
        }
        expect(find.byKey(BibleBrowser.testamentTabsKey), findsNothing);
        expect(find.byKey(BibleShell.searchKey), findsNothing);

        await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.notes)));
        await _settle(tester);
        expect(find.byType(NotesTab), findsOneWidget);
        expect(invitation, findsNothing);
      });
    });

    testWidgets(
        'une vraie version débloque sans geste ; supprimée, l\'invitation '
        'revient', (tester) async {
      await tester.runAsync(() async {
        final container =
            guestContainer(bibleDownloaded: null, extra: [_radioOff]);
        final db = container.read(appDatabaseProvider);
        final router = await pumpGuestApp(tester, container);
        await db.into(db.bibleVersions).insert(
              BibleVersionsCompanion.insert(
                id: const Value(7),
                code: 'EWE',
                name: 'Biblia',
                publishedAt: Value(DateTime.utc(2026)),
                archiveUrl: const Value('https://exemple.test/ewe.zip'),
              ),
            );
        router.push('/bible?tab=bible');
        await _settle(tester);
        // Proposée mais pas descendue : l'invitation, avec son bouton.
        expect(invitation, findsOneWidget);
        expect(find.text(_fr.bibleInviteDownload), findsOneWidget);
        expect(
          find.byKey(BibleVersionsScreen.downloadKey('EWE')),
          findsOneWidget,
        );

        // La fin d'un téléchargement : la ligne et son dossier.
        await db.into(db.bibleInstalledVersions).insert(
              BibleInstalledVersionsCompanion.insert(
                code: 'EWE',
                name: 'Biblia',
                installedAt: DateTime.utc(2026),
                localPath: const Value('/nulle-part/EWE'),
              ),
            );
        await _settle(tester);
        expect(invitation, findsNothing);
        expect(find.byKey(BibleBrowser.testamentTabsKey), findsOneWidget);

        await db.delete(db.bibleInstalledVersions).go();
        await _settle(tester);
        expect(invitation, findsOneWidget);
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

    // #250 : le propriétaire a jugé l'écran sur son allure, pas sur ses
    // fonctions. Les deux traits qu'un test peut tenir sont la lettrine et
    // l'encre des numéros ; la brique est écrite en clair des deux côtés,
    // sinon changer la couleur changerait aussi l'attente.
    testWidgets(
        'l\'allure : une lettrine ouvre le chapitre, les numéros sont '
        'en ligne et rouge brique', (tester) async {
      await tester.runAsync(() async {
        final router =
            await pumpGuestApp(tester, guestContainer(extra: [_radioOff]));
        router.push('/bible/read/John/3');
        await _settle(tester);

        // La lettrine : le numéro du chapitre en Playfair, dans le premier
        // verset — et le titre du corps a disparu avec elle.
        final first = tester.widgetList<Text>(
          find.descendant(
            of: find.byKey(BibleReaderScreen.verseKey(1)),
            matching: find.byType(Text),
          ),
        );
        expect(
          first.where(
            (t) => t.data == '3' && t.style?.fontFamily == 'Playfair Display',
          ),
          hasLength(1),
        );
        expect(
          find.descendant(
            of: find.byKey(BibleReaderScreen.pageKey('John', 3)),
            matching: find.text('Jean 3'),
          ),
          findsNothing,
        );

        // Le numéro : un simple `TextSpan` (plus de `WidgetSpan` en exposant),
        // à la taille du texte et en brique.
        final line = tester.widget<Text>(
          find.descendant(
            of: find.byKey(BibleReaderScreen.verseKey(2)),
            matching: find.byType(Text),
          ),
        );
        final spans = (line.textSpan! as TextSpan).children!;
        expect(spans.whereType<WidgetSpan>(), isEmpty);
        final number = spans.first as TextSpan;
        expect(number.text, '2 ');
        expect(number.style?.color, const Color(0xFFAE3B23));
        expect(number.style?.fontSize, isNull);
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
      // La durée du surlignage, réglée par le test : longue tant qu'on le
      // regarde (la charge de la machine ne l'éteint plus avant), courte pour
      // le voir s'éteindre.
      var flash = const Duration(hours: 1);
      await tester.runAsync(() async {
        final container = guestContainer(extra: [
          _radioOff,
          bibleFlashDurationProvider.overrideWith((_) => flash),
        ]);
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

        // Depuis #250 le surlignage d'arrivée est peint au marqueur, et
        // [MarkerHighlight] n'est dans l'arbre que s'il y a de l'encre.
        Color? colorOf(int verse) {
          final marker = find.descendant(
            of: find.byKey(BibleReaderScreen.verseKey(verse)),
            matching: find.byType(MarkerHighlight),
          );
          return marker.evaluate().isEmpty
              ? null
              : tester.widget<MarkerHighlight>(marker).color;
        }

        expect(colorOf(16), isNotNull);
        expect(colorOf(18), isNotNull);
        expect(colorOf(19), isNull);
        expect((await _localState(container))!.verse, 16);

        // Rouvert avec un surlignage bref : il s'éteint.
        flash = const Duration(milliseconds: 50);
        container.invalidate(bibleFlashDurationProvider);
        router.pop();
        await _settle(tester);
        await NoteLinkOpener.open(
          element,
          element as WidgetRef,
          'nv://bible/John/3/16-18',
        );
        await _settle(tester);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await _settle(tester);
        expect(colorOf(16), isNull);
      });
    });

    testWidgets(
        'une version proposée mais pas descendue : le lecteur invite à la '
        'télécharger au lieu d\'un chapitre vide', (tester) async {
      await tester.runAsync(() async {
        final container = guestContainer(extra: [_radioOff]);
        // L'état que crée la règle de #249 : une vraie version **proposée**
        // (servie et porteuse d'une archive) efface les exemples, et rien
        // n'est encore installé. L'appli n'a donc aucun texte — c'est le
        // moment que M4 passait en silence, avec un chapitre sans un verset.
        final db = container.read(appDatabaseProvider);
        await db.into(db.bibleVersions).insert(
              BibleVersionsCompanion.insert(
                id: const Value(1),
                code: 'BOV',
                name: 'Bible Bovet Bonnet',
                archiveUrl: const Value('https://x/uploads/bible/BOV-ab.zip'),
                publishedAt: Value(DateTime.utc(2026, 10)),
              ),
            );
        final router = await pumpGuestApp(tester, container);
        router.push('/bible/read/John/3');
        await _settle(tester);

        // La page courante, et non le `PageView` entier : ses voisines
        // portent la même invitation.
        final page = find.byKey(BibleReaderScreen.pageKey('John', 3));
        Finder on(Finder matching) =>
            find.descendant(of: page, matching: matching);
        expect(
          on(find.text(_fr.bibleVersionNotInstalled)),
          findsOneWidget,
        );
        // « Pas disponible dans cette version » était vrai, inutile et sans
        // issue : ce n'est plus ce qui est dit.
        expect(on(find.text(_fr.bibleChapterUnavailable)), findsNothing);

        // Et l'action mène au catalogue, où le bouton existe vraiment.
        await tester.tap(on(find.byKey(BibleReaderScreen.downloadKey)));
        await _settle(tester);
        expect(router.state.matchedLocation, '/bible/personalize/offline');
        expect(find.text(_fr.bibleM4VersionsTitle), findsOneWidget);
        expect(find.text('Bible Bovet Bonnet'), findsOneWidget);
        // Les exemples ne sont plus proposés à côté d'elle (#249).
        expect(find.text("Version d'exemple A"), findsNothing);
      });
    });
  });
}
