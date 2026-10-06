/// **La médiathèque en pages** (#167) — l'écran : onglets, puces, quatre
/// gabarits, sections vides masquées, loupe, « Voir tout ».
///
/// La composition elle-même (chaque règle de tri et de filtre) se juge sur la
/// fonction pure, dans `test/models/media_page_view_test.dart` ; la lecture du
/// magasin, dans `test/sync/media_pages_collection_test.dart`. Ici, **aucun flux
/// Drift** : les pages sont posées par `pumpScreen(mediaLayout:)` et les
/// contenus par les doubles en mémoire — un flux Drift sous l'horloge factice
/// du harnais fige le montage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/models/media_page_view.dart';
import 'package:maison_du_miracle/models/menu_entry_view.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/widgets/app_empty_state.dart';

import '../helpers/pump_screen.dart';

/// Quatre enseignements, du plus récent (t1) au plus ancien (t4), dans deux
/// rubriques. Le libellé de rubrique s'affiche sur chaque ligne de liste : il
/// ne doit pas répéter un libellé de puce ou d'onglet.
final _teachings = [
  for (final (id, title, type, day) in const [
    ('t1', 'Prier sans cesse', 1, 4),
    ('t2', 'Le pain du jour', 2, 3),
    ('t3', 'Prier en famille', 1, 2),
    ('t4', 'Louange du soir', 2, 1),
  ])
    Teaching(
      id: id,
      title: title,
      author: 'Pasteur Komla',
      teachingTypeId: type,
      recordedAt: DateTime.utc(2026, 9, day),
      publishedAt: DateTime.utc(2026, 9, day),
    ),
];

const _types = [
  TeachingType(id: 1, label: {'fr': 'Intercession'}, slug: 'prieres'),
  TeachingType(id: 2, label: {'fr': 'Culte'}, slug: 'dimanche'),
];

const _rubrics = {'prieres': 1, 'dimanche': 2};

MediaSectionView _section(
  int id, {
  MediaSectionLayout layout = MediaSectionLayout.list,
  MediaSectionSort sort = MediaSectionSort.latest,
  String title = '',
  String? titleKey,
  int maxItems = 10,
  List<String>? manualIds,
}) =>
    MediaSectionView(
      id: id,
      layout: layout,
      sort: sort,
      family: MenuContentFamily.teaching,
      title: title,
      titleKey: titleKey,
      maxItems: maxItems,
      manualIds: manualIds,
    );

Future<void> _pump(
  WidgetTester tester,
  List<MediaPageView> pages, {
  String? rubric,
}) async {
  // Écran haut : les listes sont paresseuses, et une ligne jamais construite ne
  // prouve rien — ni sa présence, ni son absence.
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await pumpScreen(
    tester,
    MediaLibraryScreen(initialRubric: rubric),
    mediatheque:
        InMemoryMediathequeRepository(teachings: _teachings, types: _types),
    gatherings:
        InMemoryGatheringRepository(gatherings: const [], types: const []),
    mediaLayout: MediaLibraryLayout(pages: pages, teachingRubricIds: _rubrics),
  );
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Les onglets sont les pages', () {
    testWidgets('dans leur ordre, et chacun montre sa page', (tester) async {
      await _pump(tester, [
        MediaPageView(id: 1, label: 'Écouter', sections: [_section(1)]),
        MediaPageView(
          id: 2,
          label: 'Cultes',
          filter: const MediaFilter(rubric: 'dimanche'),
          sections: [_section(2)],
        ),
      ]);

      expect(
        tester.getTopLeft(find.text('Écouter')).dx,
        lessThan(tester.getTopLeft(find.text('Cultes')).dx),
      );
      // La première page est ouverte : tout le catalogue.
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsOneWidget);

      await _tap(tester, find.text('Cultes'));

      // Le filtre de la page borne sa section.
      expect(find.text('Le pain du jour'), findsOneWidget);
      expect(find.text('Louange du soir'), findsOneWidget);
      expect(find.text('Prier sans cesse'), findsNothing);
    });

    testWidgets('une page à clé du dépôt prend son mot ; sans libellé, aucune',
        (tester) async {
      await _pump(tester, [
        MediaPageView(
          id: 1,
          labelKey: 'public.nav.mediatheque',
          sections: [_section(1)],
        ),
        MediaPageView(
            id: 2, labelKey: 'public.nav.dons', sections: [_section(2)]),
      ]);

      expect(find.text('Tout'), findsOneWidget);
      expect(find.text('public.nav.dons'), findsNothing);
    });

    testWidgets('sans aucune page : pas de barre, le catalogue entier',
        (tester) async {
      await _pump(tester, const []);

      for (final t in _teachings) {
        expect(find.text(t.title), findsOneWidget);
      }
    });
  });

  group('Les puces', () {
    testWidgets('une puce filtre **toutes** les sections de la page',
        (tester) async {
      await _pump(tester, [
        MediaPageView(
          id: 1,
          label: 'Écouter',
          chips: const [
            MediaChipView(
              id: 9,
              label: 'Prières',
              filter: MediaFilter(rubric: 'prieres'),
            ),
          ],
          sections: [
            _section(1, layout: MediaSectionLayout.carousel),
            // `popular` jamais classé : les plus récents, en attendant.
            _section(2, sort: MediaSectionSort.popular),
          ],
        ),
      ]);

      // Sans puce, les deux sections montrent le catalogue.
      expect(find.text('Le pain du jour'), findsNWidgets(2));

      await _tap(tester, find.text('Prières'));

      expect(find.text('Le pain du jour'), findsNothing);
      expect(find.text('Louange du soir'), findsNothing);
      expect(find.text('Prier sans cesse'), findsNWidgets(2));
      expect(find.text('Prier en famille'), findsNWidgets(2));

      // Un second appui relâche la puce.
      await _tap(tester, find.text('Prières'));
      expect(find.text('Le pain du jour'), findsNWidgets(2));
    });
  });

  group('Les sections', () {
    testWidgets('les quatre gabarits se rendent', (tester) async {
      await _pump(tester, [
        MediaPageView(
          id: 1,
          label: 'Écouter',
          sections: [
            _section(1, layout: MediaSectionLayout.hero, maxItems: 1),
            _section(2, layout: MediaSectionLayout.carousel, maxItems: 1),
            _section(3, layout: MediaSectionLayout.list, maxItems: 1),
            _section(4, layout: MediaSectionLayout.grid, maxItems: 2),
          ],
        ),
      ]);

      for (final id in [1, 2, 3, 4]) {
        expect(find.byKey(MediaLibraryScreen.sectionKey(id)), findsOneWidget,
            reason: 'section $id');
      }
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(SliverGrid), findsOneWidget);
      // Le plus récent paraît dans chacune des quatre ; le second, dans la
      // grille seulement (plafond 2).
      expect(find.text('Prier sans cesse'), findsNWidgets(4));
      expect(find.text('Le pain du jour'), findsOneWidget);
    });

    testWidgets('une section vide ne paraît pas, ni son titre', (tester) async {
      await _pump(tester, [
        MediaPageView(
          id: 1,
          label: 'Écouter',
          sections: [
            _section(
              1,
              title: 'Sélection',
              sort: MediaSectionSort.manual,
              manualIds: const ['retire'],
            ),
            _section(2, title: 'Tout récemment'),
          ],
        ),
      ]);

      expect(find.text('Sélection'), findsNothing);
      expect(find.byKey(MediaLibraryScreen.sectionKey(1)), findsNothing);
      expect(find.text('Tout récemment'), findsOneWidget);
      expect(find.byKey(MediaLibraryScreen.sectionKey(2)), findsOneWidget);
    });

    testWidgets('toutes les sections vides : l\'état vide', (tester) async {
      await _pump(tester, [
        MediaPageView(
          id: 1,
          label: 'Écouter',
          sections: [
            _section(1, sort: MediaSectionSort.manual),
          ],
        ),
      ]);

      expect(find.byType(AppEmptyState), findsOneWidget);
    });

    testWidgets('titleKey se résout par le vocabulaire, avant la carte',
        (tester) async {
      await _pump(tester, [
        MediaPageView(
          id: 1,
          label: 'Écouter',
          sections: [
            _section(
              1,
              titleKey: 'sectionLatestTeachings',
              title: 'Ignoré',
            ),
            _section(2, titleKey: 'cleInconnue', title: 'Recommandés'),
          ],
        ),
      ]);

      expect(find.text('Dernières publications'), findsOneWidget);
      expect(find.text('Ignoré'), findsNothing);
      expect(find.text('Recommandés'), findsOneWidget);
    });
  });

  group('La loupe', () {
    testWidgets('elle affine chaque section, et se referme en effaçant',
        (tester) async {
      await _pump(tester, [
        MediaPageView(
          id: 1,
          label: 'Écouter',
          sections: [
            _section(1, layout: MediaSectionLayout.carousel),
            _section(2),
          ],
        ),
      ]);

      await _tap(tester, find.byKey(MediaLibraryScreen.searchButtonKey));
      await tester.enterText(
          find.byKey(MediaLibraryScreen.searchFieldKey), 'louange');
      await tester.pump();

      expect(find.text('Louange du soir'), findsNWidgets(2));
      expect(find.text('Prier sans cesse'), findsNothing);

      await _tap(tester, find.byKey(MediaLibraryScreen.searchButtonKey));
      expect(find.text('Prier sans cesse'), findsNWidgets(2));
    });
  });

  group('Le « Voir tout » d\'une rubrique d\'accueil', () {
    testWidgets('ouvre la page qui vise la rubrique', (tester) async {
      await _pump(
        tester,
        [
          MediaPageView(id: 1, label: 'Écouter', sections: [_section(1)]),
          MediaPageView(
            id: 2,
            label: 'Cultes',
            filter: const MediaFilter(rubric: 'dimanche'),
            sections: [_section(2)],
          ),
        ],
        rubric: 'dimanche',
      );

      expect(find.text('Le pain du jour'), findsOneWidget);
      expect(find.text('Prier sans cesse'), findsNothing);
    });

    testWidgets('sans page qui la vise, elle affine la page ouverte',
        (tester) async {
      await _pump(
        tester,
        [
          MediaPageView(id: 1, label: 'Écouter', sections: [_section(1)])
        ],
        rubric: 'prieres',
      );

      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsNothing);
    });

    testWidgets('un slug inconnu ne ramène rien, jamais tout le catalogue',
        (tester) async {
      await _pump(tester, const [], rubric: 'inconnue');

      expect(find.byType(AppEmptyState), findsOneWidget);
    });
  });
}
