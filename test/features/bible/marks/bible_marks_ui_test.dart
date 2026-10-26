/// **Le lecteur et l'onglet Favori, à travers le vrai routeur** (M2, #200) :
/// sélection, menu flottant, palette, favori, marque-page, note sur un verset,
/// Favori filtré — en invité, sans réseau.
///
/// Tout ce qui touche le magasin Drift vit dans **un seul** `runAsync`.
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
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/marks/bible_favorites_list.dart';
import 'package:maison_du_miracle/features/bible/marks/bible_marks_outbox.dart';
import 'package:maison_du_miracle/features/bible/marks/bible_marks_store.dart';
import 'package:maison_du_miracle/features/bible/marks/bible_verse_menu.dart';
import 'package:maison_du_miracle/features/bible/reader/bible_reader_screen.dart';
import 'package:maison_du_miracle/features/bible/reader/marker_highlight.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_shell.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();

final Override _radioOff = radioRepositoryProvider.overrideWithValue(
  const FixedRadioRepository(RadioAntenna.unknown),
);

late FakeAdapter _wire;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Attend (borné) que [done] devienne vrai : la file part hors du `build`.
Future<void> _until(WidgetTester tester, Future<bool> Function() done) async {
  for (var i = 0; i < 20 && !await done(); i++) {
    await _settle(tester);
  }
}

Future<List<LocalBibleMarkRow>> _marks(ProviderContainer c) {
  final db = c.read(appDatabaseProvider);
  return db.select(db.localBibleMarks).get();
}

/// La couleur du surlignage d'un verset. Depuis #250 elle n'est plus un fond
/// de `BoxDecoration` mais l'encre du trait de marqueur : [MarkerHighlight]
/// disparaît de l'arbre quand il n'y a rien à peindre.
Color? _background(WidgetTester tester, int verse) {
  final marker = find.descendant(
    of: find.byKey(BibleReaderScreen.verseKey(verse)),
    matching: find.byType(MarkerHighlight),
  );
  return marker.evaluate().isEmpty
      ? null
      : tester.widget<MarkerHighlight>(marker).color;
}

Future<void> _tapVerse(WidgetTester tester, int verse) async {
  final f = find.byKey(BibleReaderScreen.verseKey(verse));
  if (f.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
    await _settle(tester);
  }
  await tester.tap(f);
  await _settle(tester);
}

Finder _marginIcon(int verse, IconData icon) => find.descendant(
      of: find.byKey(BibleReaderScreen.verseKey(verse)),
      matching: find.byIcon(icon),
    );

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

  testWidgets(
      'toucher sélectionne, toucher plus loin étend ; le menu flottant '
      'surligne et pose un favori — invité, sans réseau', (tester) async {
    await tester.runAsync(() async {
      final container = guestContainer(extra: [_radioOff]);
      final router = await pumpGuestApp(tester, container);
      router.push('/bible/read/John/3');
      await _settle(tester);

      expect(find.byKey(BibleVerseMenu.menuKey), findsNothing);
      await _tapVerse(tester, 6);
      expect(find.byKey(BibleVerseMenu.menuKey), findsOneWidget);
      for (final id in ['copy', 'favorite', 'note', 'share', 'bookmark']) {
        expect(find.byKey(Key('bible_action_$id')), findsOneWidget);
      }
      // Le menu se tient au-dessus : le verset 8 reste à portée.
      await _tapVerse(tester, 8);

      // Palette : vert sur 6-8. Depuis #250 les pastels sont repliés sous
      // la pastille multicolore — il faut l'ouvrir d'abord.
      expect(find.byKey(BibleVerseMenu.colorKey('green')), findsNothing);
      await tester.tap(find.byKey(BibleVerseMenu.paletteKey));
      await _settle(tester);
      await tester.tap(find.byKey(BibleVerseMenu.colorKey('green')));
      await _settle(tester);
      expect(find.byKey(BibleVerseMenu.menuKey), findsNothing);
      var row = (await _marks(container)).single;
      expect((row.kind, row.verseFrom, row.verseTo, row.color),
          ('highlight', 6, 8, 'green'));
      expect(_background(tester, 7), isNotNull);
      expect(_background(tester, 9), isNull);

      // Favori sur 7 seul.
      await _tapVerse(tester, 7);
      await tester.tap(find.byKey(const Key('bible_action_favorite')));
      await _settle(tester);
      expect(_marginIcon(7, Icons.favorite), findsOneWidget);
      expect(_marginIcon(6, Icons.favorite), findsNothing);

      // Effacer : le surlignage qui touche le verset 6 part en entier.
      await _tapVerse(tester, 6);
      await tester.tap(find.byKey(BibleVerseMenu.clearKey));
      await _settle(tester);
      expect(_background(tester, 7), isNull);
      row = (await _marks(container)).single;
      expect(row.kind, 'favorite');

      expect(_wire.requests, isEmpty);
    });
  });

  // #250 : l'appui long puis glisser étendait déjà la plage, mais rien ne
  // l'annonçait. Le « + » des références rend la fonction visible ; ce test
  // tient le geste, pas son dessin.
  testWidgets(
      'le « + » étend la sélection d\'un verset, et le signet de la pilule '
      'est celui du chapitre', (tester) async {
    await tester.runAsync(() async {
      final container = guestContainer(extra: [_radioOff]);
      final router = await pumpGuestApp(tester, container);
      router.push('/bible/read/John/3');
      await _settle(tester);

      expect(find.byKey(BibleReaderScreen.extendKey), findsNothing);
      await _tapVerse(tester, 6);
      expect(find.byKey(BibleReaderScreen.extendKey), findsOneWidget);

      // Deux appuis : la plage passe de 6 seul à 6-8.
      await tester.tap(find.byKey(BibleReaderScreen.extendKey));
      await _settle(tester);
      await tester.tap(find.byKey(BibleReaderScreen.extendKey));
      await _settle(tester);
      await tester.tap(find.byKey(BibleVerseMenu.paletteKey));
      await _settle(tester);
      await tester.tap(find.byKey(BibleVerseMenu.colorKey('blue')));
      await _settle(tester);
      final highlight = (await _marks(container)).single;
      expect(
        (highlight.kind, highlight.verseFrom, highlight.verseTo),
        ('highlight', 6, 8),
      );

      // Le signet de la pilule est **chapitré**, comme le nôtre l'a toujours
      // été : la ligne n'a pas de verset, et l'icône de l'en-tête s'allume.
      await _tapVerse(tester, 6);
      await tester.tap(find.byKey(const Key('bible_action_bookmark')));
      await _settle(tester);
      final bookmark =
          (await _marks(container)).firstWhere((m) => m.kind == 'bookmark');
      expect((bookmark.verseFrom, bookmark.verseTo), (null, null));
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(BibleReaderScreen.bookmarkKey),
                matching: find.byType(Icon),
              ),
            )
            .icon,
        Icons.bookmark,
      );
    });
  });

  testWidgets('le marque-page du chapitre, dans l\'en-tête', (tester) async {
    await tester.runAsync(() async {
      final container = guestContainer(extra: [_radioOff]);
      final router = await pumpGuestApp(tester, container);
      router.push('/bible/read/Ps/23');
      await _settle(tester);

      await tester.tap(find.byKey(BibleReaderScreen.bookmarkKey));
      await _settle(tester);
      final row = (await _marks(container)).single;
      expect((row.kind, row.book, row.chapter, row.verseFrom),
          ('bookmark', 'Ps', 23, null));
      expect(
        find.descendant(
          of: find.byKey(BibleReaderScreen.bookmarkKey),
          matching: find.byIcon(Icons.bookmark),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(BibleReaderScreen.bookmarkKey));
      await _settle(tester);
      expect(await _marks(container), isEmpty);
    });
  });

  testWidgets('Favori : filtré par genre ; toucher ouvre ; glisser retire',
      (tester) async {
    await tester.runAsync(() async {
      final container = guestContainer(extra: [_radioOff]);
      final router = await pumpGuestApp(tester, container);
      router.push('/bible/read/Ps/23');
      await _settle(tester);
      await tester.tap(find.byKey(BibleReaderScreen.bookmarkKey));
      await _tapVerse(tester, 1);
      await tester.tap(find.byKey(const Key('bible_action_favorite')));
      await _settle(tester);

      router.go('/bible?tab=favorites');
      await _settle(tester);
      expect(find.text('Psaumes 23'), findsOneWidget);
      expect(find.text('Psaumes 23:1'), findsOneWidget);

      await tester.tap(find.text(_fr.bibleM2FilterChapters));
      await _settle(tester);
      expect(find.text('Psaumes 23'), findsOneWidget);
      expect(find.text('Psaumes 23:1'), findsNothing);

      await tester.tap(find.text(_fr.bibleM2FilterHighlights));
      await _settle(tester);
      expect(find.text(_fr.bibleM2Empty), findsOneWidget);

      await tester.tap(find.text(_fr.bibleM2FilterVerses));
      await _settle(tester);
      final card = find.byType(BibleFavoritesList);
      expect(find.descendant(of: card, matching: find.text('Psaumes 23:1')),
          findsOneWidget);
      await tester.drag(find.text('Psaumes 23:1'), const Offset(-600, 0));
      await _settle(tester);
      expect(find.text('Psaumes 23:1'), findsNothing);
      expect((await _marks(container)).single.kind, 'bookmark');

      await tester.tap(find.text(_fr.bibleM2FilterAll));
      await _settle(tester);
      await tester.tap(find.text('Psaumes 23'));
      await _settle(tester);
      expect(router.state.matchedLocation, '/bible/read/Ps/23');
    });
  });

  testWidgets(
      'Note : réservée aux membres ; après connexion, une note avec le lien '
      'et la citation, et l\'icône en marge', (tester) async {
    await tester.runAsync(() async {
      _wire = FakeAdapter((o) => jsonReply(200, {}));
      ApiClient.instance.dio.httpClientAdapter = _wire;
      final container = guestContainer(extra: [_radioOff]);
      // Comme `app.dart`.
      container.listen(bibleMarksOutboxProvider, (_, __) {});
      final router = await pumpGuestApp(tester, container);
      router.push('/bible/read/John/3');
      await _settle(tester);

      await _tapVerse(tester, 16);
      await tester.tap(find.byKey(const Key('bible_action_note')));
      await _settle(tester);
      // La connexion d'abord.
      expect(router.state.name, AppRoute.authIdentifier);

      await signIn(container);
      await untilSignedIn(tester, container);
      await _settle(tester);
      await _settle(tester);

      expect(router.state.name, AppRoute.noteEditor);
      final db = container.read(appDatabaseProvider);
      final note = (await db.select(db.localNotes).get()).single;
      final ops = (jsonDecode(note.content!) as Map)['ops'] as List;
      expect(
          (ops.first as Map)['attributes'], {'link': 'nv://bible/John/3/16'});
      expect((ops[3] as Map)['attributes'], {'blockquote': true});
      expect(note.body, startsWith('Jean 3:16\n'));

      router.pop();
      await _settle(tester);
      expect(router.state.matchedLocation, '/bible/read/John/3');
      expect(_marginIcon(16, Icons.sticky_note_2_outlined), findsOneWidget);
      expect(find.byType(BibleShell), findsNothing);
    });
  });

  testWidgets(
      'invité → membre : ce que l\'invité a fait part en un seul '
      'POST /bible/import ; à la déconnexion, les local_bible_* sont vidées',
      (tester) async {
    await tester.runAsync(() async {
      _wire = FakeAdapter(
          (o) => jsonReply(o.path == '/bible/import' ? 204 : 200, {}));
      ApiClient.instance.dio.httpClientAdapter = _wire;
      final container = guestContainer(extra: [_radioOff]);
      container.listen(bibleMarksOutboxProvider, (_, __) {});
      await pumpGuestApp(tester, container);
      await container.read(bibleMarksStoreProvider).toggleFavorite(
            member: false,
            link: const BibleLink('John', 3, from: 16),
          );

      await signIn(container);
      await untilSignedIn(tester, container);
      await _until(
          tester, () async => (await _marks(container)).every((m) => !m.dirty));

      final imports =
          _wire.requests.where((r) => r.path == '/bible/import').toList();
      expect(imports, hasLength(1));
      expect(((imports.single.data as Map)['marks'] as List).single,
          containsPair('kind', 'favorite'));
      expect(_wire.requests.where((r) => r.path == '/bible/marks'), isEmpty);
      expect((await _marks(container)).single.dirty, isFalse);

      await container.read(authProvider.notifier).signOut();
      await _until(tester, () async => (await _marks(container)).isEmpty);
    });
  });
}
