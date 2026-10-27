/// **Le lecteur et l'onglet Favori, à travers le vrai routeur** (M2, #200) :
/// sélection, menu flottant, palette, favori, marque-page, note sur un verset,
/// Favori filtré — en invité, sans réseau.
///
/// Tout ce qui touche le magasin Drift vit dans **un seul** `runAsync`.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Le paragraphe d'un verset : c'est lui qui sait où sa mise en page a posé
/// chaque caractère, dans le test comme dans le lecteur.
RenderParagraph _paragraph(WidgetTester tester, int verse) =>
    tester.renderObject<RenderParagraph>(
      find
          .descendant(
            of: find.byKey(BibleReaderScreen.verseKey(verse)),
            matching: find.byType(RichText),
          )
          .first,
    );

/// Le texte du verset tel qu'il est peint, numéro de tête retiré.
String _verseText(WidgetTester tester, int verse) =>
    _paragraph(tester, verse).text.toPlainText().substring('$verse '.length);

/// Le point à l'écran du caractère [index] du texte du verset.
Offset _charCenter(WidgetTester tester, int verse, int index) {
  final paragraph = _paragraph(tester, verse);
  final at = '$verse '.length + index;
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: at, extentOffset: at + 1),
      )
      .first;
  return paragraph.localToGlobal(
    Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2),
  );
}

/// Un caractère au milieu du mot de rang [rank] (0 = le premier). Sert à
/// **poser le doigt**, pas à prédire les bornes : celles-ci viennent du
/// découpage en mots de Flutter, que le lecteur interroge.
int _insideWord(String text, int rank) {
  final words = RegExp(r'\S+').allMatches(text).toList();
  final w = words[rank];
  return w.start + (w.end - w.start) ~/ 2;
}

/// La bande peinte sur quelques mots d'un verset, s'il y en a une.
MarkerWordHighlight? _wordBand(WidgetTester tester, int verse) {
  final f = find.descendant(
    of: find.byKey(BibleReaderScreen.verseKey(verse)),
    matching: find.byType(MarkerWordHighlight),
  );
  return f.evaluate().isEmpty ? null : tester.widget<MarkerWordHighlight>(f);
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

  // #252 — l'appui long ne sert plus à étendre une plage de versets (le « + »
  // le fait, visiblement, depuis #250) : il prend **un mot**, et le doigt
  // maintenu étend mot à mot, à gauche comme à droite.
  testWidgets(
      'appui long : un mot est pris, le glissement étend à gauche et à '
      'droite, et le surlignage ne couvre que ces mots-là', (tester) async {
    await tester.runAsync(() async {
      final container = guestContainer(extra: [_radioOff]);
      final router = await pumpGuestApp(tester, container);
      router.push('/bible/read/John/3');
      await _settle(tester);

      final text = _verseText(tester, 6);
      final second = _insideWord(text, 1);
      final third = _insideWord(text, 2);
      final first = _insideWord(text, 0);

      // Appui long sur le deuxième mot : il est pris, seul, et la pilule est
      // là comme pour un verset.
      final gesture = await tester.startGesture(_charCenter(tester, 6, second));
      // L'appui long se compte sur une **vraie** minuterie : sous `runAsync`
      // le temps de `tester.pump` n'est pas celui du détecteur de gestes.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await tester.pump();
      expect(find.byKey(BibleVerseMenu.menuKey), findsOneWidget);
      var band = _wordBand(tester, 6)!;
      final start = band.from - '6 '.length;
      final end = band.to - '6 '.length;
      expect(start, lessThanOrEqualTo(second));
      expect(end, greaterThan(second));
      expect(text.substring(start, end).trim(), text.substring(start, end),
          reason: 'un mot, pas deux : aucune espace dedans');
      expect(end - start, lessThan(text.length), reason: 'pas tout le verset');
      // La bande pleine ligne se tait : ce sont les mots qui se montrent.
      expect(_background(tester, 6), isNull);

      // Le doigt glisse à droite, sans se lever : la sélection gagne le
      // troisième mot et garde son ancre.
      await gesture.moveTo(_charCenter(tester, 6, third));
      await tester.pump();
      band = _wordBand(tester, 6)!;
      expect(band.from - '6 '.length, start);
      expect(band.to - '6 '.length, greaterThan(third));

      // Puis à gauche, au-delà de l'ancre : c'est le début qui recule.
      await gesture.moveTo(_charCenter(tester, 6, first));
      await tester.pump();
      band = _wordBand(tester, 6)!;
      final left = band.from - '6 '.length;
      expect(left, lessThanOrEqualTo(first));
      expect(band.to - '6 '.length, greaterThan(second));

      // **Le glissement ne quitte pas le verset** : un mot du verset 8 ne
      // déplace rien (décision mesurée sur l'appareil).
      await gesture.moveTo(
          _charCenter(tester, 8, _insideWord(_verseText(tester, 8), 1)));
      await tester.pump();
      expect(_wordBand(tester, 8), isNull);
      band = _wordBand(tester, 6)!;
      expect(band.from - '6 '.length, left);
      final covered = band.to - '6 '.length;

      await gesture.up();
      await _settle(tester);

      // La pilule surligne : la marque nomme sa traduction et ses bornes.
      await tester.tap(find.byKey(BibleVerseMenu.paletteKey));
      await _settle(tester);
      await tester.tap(find.byKey(BibleVerseMenu.colorKey('yellow')));
      await _settle(tester);
      final row = (await _marks(container)).single;
      expect(
        (row.kind, row.verseFrom, row.verseTo, row.versionCode),
        ('highlight', 6, 6, 'EXA'),
      );
      expect((row.charFrom, row.charTo), (left, covered));

      // Peinte : la bande du surlignage couvre les mêmes caractères.
      final painted = _wordBand(tester, 6)!;
      expect((painted.from - '6 '.length, painted.to - '6 '.length),
          (left, covered));

      // **Le filtrage par traduction** : la même page en version B n'en
      // montre rien — ces décalages désignent le texte de la version A.
      await tester.tap(find.byKey(BibleReaderScreen.versionKey));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('bible_version_EXB')));
      await _settle(tester);
      expect(_wordBand(tester, 6), isNull);
      expect(_background(tester, 6), isNull);

      expect(_wire.requests, isEmpty);
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
