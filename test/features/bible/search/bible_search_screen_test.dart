/// **La recherche à l'écran** (M3, #201), à travers le vrai routeur : entrée
/// par l'onglet Plus, recherche simple (compteur, surlignage, filtres, « Voir
/// plus »), référence qui ouvre le lecteur, historique, recherche croisée et
/// résultats comparatifs.
///
/// Le catalogue est la Bible factice **réduite à quatre livres** : sa source
/// ne rend que ceux-là, et sa versification ne déclare que ceux-là (C3,
/// #240) — l'index se construit alors en un instant, et tout le reste est
/// réel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/features/bible/data/bible_providers.dart';
import 'package:maison_du_miracle/features/bible/data/bible_source.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/data/placeholder_bible.dart';
import 'package:maison_du_miracle/features/bible/reader/bible_reader_screen.dart';
import 'package:maison_du_miracle/features/bible/search/bible_compare_screen.dart';
import 'package:maison_du_miracle/features/bible/search/bible_search_history.dart';
import 'package:maison_du_miracle/features/bible/search/bible_search_screen.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_shell.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/guest_app.dart';

final _fr = AppLocalizationsFr();
const _books = {'Gen', 'Ps', 'John', 'Rev'};

final class _SmallSource implements BibleSource {
  const _SmallSource(this._inner);
  final PlaceholderBibleSource _inner;
  @override
  String get versionCode => _inner.versionCode;
  @override
  Future<List<BibleVerse>> chapter(String book, int chapter) async =>
      _books.contains(book) ? _inner.chapterSync(book, chapter) : const [];
}

final class _SmallCatalog implements BibleCatalog {
  const _SmallCatalog();
  static const _full = PlaceholderBibleCatalog();
  @override
  Future<List<BibleVersion>> versions() => _full.versions();
  @override
  String get defaultVersionCode => _full.defaultVersionCode;
  @override
  BibleSource? sourceFor(String code) {
    final s = _full.sourceFor(code);
    return s == null ? null : _SmallSource(s as PlaceholderBibleSource);
  }

  @override
  BibleVersification versificationFor(String code) => _versification;
}

/// Les quatre livres, à la versification du canon : l'index ne parcourt
/// qu'eux, et ses deux bornes (Genèse 1, Apocalypse 22) y sont.
final _versification = BibleVersification.of({
  for (final b in _books) b: bibleBook(b)!.verseCounts,
});

final List<Override> _extra = [
  radioRepositoryProvider.overrideWithValue(
    const FixedRadioRepository(RadioAntenna.unknown),
  ),
  bibleCatalogProvider.overrideWithValue(const _SmallCatalog()),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Monte l'appli, ouvre le module puis la recherche par la loupe de l'onglet
/// Bible (Mon espace n'a plus de ligne Rechercher, #265).
Future<(ProviderContainer, GoRouter)> _openSearch(WidgetTester tester) async {
  final container = guestContainer(extra: _extra);
  final router = await pumpGuestApp(tester, container);
  router.push('/bible?tab=bible');
  await _settle(tester);
  await tester.tap(find.byKey(BibleShell.searchKey));
  await _settle(tester);
  expect(find.byType(BibleSearchScreen), findsOneWidget);
  return (container, router);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(BibleSearchScreen.fieldKey), text);
  await _settle(tester);
}

/// Les textes des résultats, marques de surlignage comprises (`RichText`).
Iterable<InlineSpan> _boldSpans(WidgetTester tester) => tester
        .widgetList<RichText>(find.descendant(
      of: find.byType(BibleSearchScreen),
      matching: find.byType(RichText),
    ))
        .expand((r) {
      final spans = <InlineSpan>[];
      r.text.visitChildren((s) {
        if (s is TextSpan && s.style?.fontWeight == FontWeight.w700) {
          spans.add(s);
        }
        return true;
      });
      return spans;
    });

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient.instance.dio.httpClientAdapter = FakeAdapter(
      (o) => throw StateError('requête HTTP interdite : ${o.path}'),
    );
  });

  testWidgets('recherche simple : compteur, mot surligné, filtres, page',
      (tester) async {
    await tester.runAsync(() async {
      await _openSearch(tester);
      await _type(tester, 'parole');

      final count = tester.widget<Text>(find.byKey(BibleSearchScreen.countKey));
      expect(count.data, matches(RegExp(r'^\d+ résultats$')));
      expect(
        _boldSpans(tester).map((s) => (s as TextSpan).text?.toLowerCase()),
        everyElement('parole'),
      );
      expect(_boldSpans(tester), isNotEmpty);
      // Une seule version cochée : pas d'étiquette de version.
      expect(find.textContaining('EXA  '), findsNothing);

      // Pagination.
      await tester.scrollUntilVisible(
        find.byKey(BibleSearchScreen.moreKey),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(BibleSearchScreen.moreKey));
      await _settle(tester);

      // Filtre : NT seulement → les résultats sont de Jean ou Apocalypse.
      await tester.tap(find.byKey(BibleSearchScreen.scopeKey('new')));
      await _settle(tester);
      final labels = tester
          .widgetList<Text>(find
              .textContaining(RegExp(r'^(Jean|Apocalypse|Genèse|Psaumes) \d')))
          .map((t) => t.data!)
          .toList();
      expect(labels, isNotEmpty);
      expect(
        labels.every((l) => l.startsWith('Jean') || l.startsWith('Apocalypse')),
        isTrue,
      );
    });
  });

  testWidgets('une référence ouvre le lecteur, et entre dans l\'historique',
      (tester) async {
    await tester.runAsync(() async {
      final (container, _) = await _openSearch(tester);
      await _type(tester, 'jn 3 16');
      expect(find.byKey(BibleSearchScreen.gotoKey), findsOneWidget);
      expect(find.text(_fr.bibleSearchGoTo('Jean 3:16')), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      final reader =
          tester.widget<BibleReaderScreen>(find.byType(BibleReaderScreen));
      expect((reader.book, reader.chapter, reader.from), ('John', 3, 16));
      expect(
        await container.read(bibleSearchHistoryProvider).read(),
        ['jn 3 16'],
      );
    });
  });

  testWidgets('croisée puis comparative', (tester) async {
    await tester.runAsync(() async {
      await _openSearch(tester);
      await _type(tester, 'jour');
      final single =
          tester.widget<Text>(find.byKey(BibleSearchScreen.countKey)).data;

      await tester.tap(find.byKey(BibleSearchScreen.versionKey('EXB')));
      await _settle(tester);
      final cross =
          tester.widget<Text>(find.byKey(BibleSearchScreen.countKey)).data;
      expect(cross, isNot(single));
      // Les résultats portent le code de leur version.
      expect(find.textContaining('EXB  ', findRichText: true), findsWidgets);

      // Décocher la dernière version ne fait rien : il en faut une.
      await tester.tap(find.byKey(BibleSearchScreen.versionKey('EXA')));
      await _settle(tester);
      await tester.tap(find.byKey(BibleSearchScreen.versionKey('EXB')));
      await _settle(tester);
      final chip = tester.widget<FilterChip>(
        find.byKey(BibleSearchScreen.versionKey('EXB')),
      );
      expect(chip.selected, isTrue);

      // Comparer le premier résultat.
      await tester.tap(find.byIcon(Icons.compare_arrows).first);
      await _settle(tester);
      expect(find.byType(BibleCompareScreen), findsOneWidget);
      final link = tester
          .widget<BibleCompareScreen>(find.byType(BibleCompareScreen))
          .link;
      for (final (code, variant) in [('EXA', 0), ('EXB', 1)]) {
        final card = find.byKey(BibleCompareScreen.versionKey(code));
        expect(card, findsOneWidget);
        final text = PlaceholderBibleSource(code, variant: variant)
            .verseText(link.book, link.chapter, link.from!);
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining(text, findRichText: true),
          ),
          findsOneWidget,
        );
      }
      expect(bibleBook(link.book), isNotNull);
    });
  });
}
