/// **La composition d'une section** (#167) — chaque règle du plan
/// `docs/mediatheque-pages-plan.md`, sur la fonction pure que l'écran appelle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/media_page_view.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/menu_entry_view.dart';

/// Les plus récents d'abord : t1 est le plus récent.
/// t2 et t4 sont d'Aného (7), t3 de Lomé (8), t1 est national.
const _latest = [
  TeachingView(
      id: 't1', title: 'Prier sans cesse', color: 0, teachingTypeId: 1),
  TeachingView(
    id: 't2',
    title: 'Le pain du jour',
    color: 0,
    teachingTypeId: 2,
    branchId: 7,
  ),
  TeachingView(
    id: 't3',
    title: 'Prier en famille',
    color: 0,
    teachingTypeId: 1,
    branchId: 8,
    authorName: 'Pasteur Kodjo Agbéko',
  ),
  TeachingView(
    id: 't4',
    title: 'Louange',
    color: 0,
    teachingTypeId: 2,
    branchId: 7,
  ),
];

const _rubrics = {'prieres': 1, 'dimanche': 2};

/// Une branche sans slug n'y figure pas, comme dans ce que lit le DAO.
const _branches = {'aneho': 7, 'lome': 8};

MediaSectionView _section({
  MediaSectionSort sort = MediaSectionSort.latest,
  MenuContentFamily? family = MenuContentFamily.teaching,
  MediaFilter filter = const MediaFilter(),
  int maxItems = 10,
  List<String>? manualIds,
  List<String>? rankedIds,
}) =>
    MediaSectionView(
      id: 1,
      layout: MediaSectionLayout.list,
      sort: sort,
      family: family,
      filter: filter,
      maxItems: maxItems,
      manualIds: manualIds,
      rankedIds: rankedIds,
    );

List<String> _compose(
  MediaSectionView section, {
  MediaPageView page = const MediaPageView(id: 1),
  MediaFilter? chip,
  String? query,
}) =>
    composeSection(
      section: section,
      page: page,
      latestFirst: _latest,
      rubricIds: _rubrics,
      branchIds: _branches,
      chip: chip,
      query: query,
    ).map((c) => c.id).toList();

void main() {
  group('latest', () {
    test('les plus récents d\'abord, depuis le magasin', () {
      expect(_compose(_section()), ['t1', 't2', 't3', 't4']);
    });

    test('la page borne, la section affine : les deux s\'appliquent', () {
      const page = MediaPageView(
        id: 1,
        filter: MediaFilter(rubric: 'prieres'),
      );
      expect(_compose(_section(), page: page), ['t1', 't3']);
      expect(
        _compose(
          _section(filter: const MediaFilter(search: 'famille')),
          page: page,
        ),
        ['t3'],
      );
      // Page et section contradictoires : l'intersection est vide.
      expect(
        _compose(
          _section(filter: const MediaFilter(rubric: 'dimanche')),
          page: page,
        ),
        isEmpty,
      );
    });

    test('la puce et la loupe affinent encore', () {
      expect(
        _compose(_section(), chip: const MediaFilter(rubric: 'dimanche')),
        ['t2', 't4'],
      );
      expect(_compose(_section(), query: 'PRIER'), ['t1', 't3']);
      expect(
        _compose(
          _section(),
          chip: const MediaFilter(rubric: 'dimanche'),
          query: 'pain',
        ),
        ['t2'],
      );
    });

    test('une famille de page différente de la section ne ramène rien', () {
      expect(
        _compose(
          _section(),
          page: const MediaPageView(id: 1, family: 'gathering'),
        ),
        isEmpty,
      );
    });

    test('un slug de rubrique ou de branche inconnu ne ramène rien', () {
      expect(
        _compose(_section(filter: const MediaFilter(rubric: 'inconnue'))),
        isEmpty,
      );
      expect(
        _compose(_section(filter: const MediaFilter(branch: 'kpalime'))),
        isEmpty,
      );
    });

    test('la branche se résout par son slug : page, section, puce', () {
      // Le national (t1) ne passe aucune borne de branche.
      expect(
        _compose(_section(filter: const MediaFilter(branch: 'aneho'))),
        ['t2', 't4'],
      );
      expect(
        _compose(
          _section(),
          page: const MediaPageView(id: 1, filter: MediaFilter(branch: 'lome')),
        ),
        ['t3'],
      );
      expect(
        _compose(_section(), chip: const MediaFilter(branch: 'aneho')),
        ['t2', 't4'],
      );
    });

    test('la loupe ignore accents et casse, et lit aussi l\'intervenant', () {
      expect(_compose(_section(), query: 'LOUANGE'), ['t4']);
      expect(_compose(_section(), query: 'agbeko'), ['t3']);
      expect(_compose(_section(), query: 'PRIÈR'), ['t1', 't3']);
    });

    test('une famille inconnue ne ramène rien', () {
      expect(_compose(_section(family: null)), isEmpty);
    });
  });

  group('popular', () {
    test('suit l\'ordre de rankedIds, filtré par la composition', () {
      final section = _section(
        sort: MediaSectionSort.popular,
        rankedIds: ['t4', 't3', 't1', 't2'],
      );
      expect(_compose(section), ['t4', 't3', 't1', 't2']);
      expect(
        _compose(section, chip: const MediaFilter(rubric: 'prieres')),
        ['t3', 't1'],
      );
    });

    test('rankedIds nul : les plus récents, en attendant', () {
      expect(
        _compose(_section(sort: MediaSectionSort.popular)),
        ['t1', 't2', 't3', 't4'],
      );
    });

    test('un identifiant classé absent du magasin est sauté', () {
      expect(
        _compose(_section(
          sort: MediaSectionSort.popular,
          rankedIds: ['retire', 't2'],
        )),
        ['t2'],
      );
    });
  });

  group('manual', () {
    test('l\'ordre de manualIds, un absent sauté sans bruit', () {
      expect(
        _compose(_section(
          sort: MediaSectionSort.manual,
          manualIds: ['t3', 'absent', 't2'],
        )),
        ['t3', 't2'],
      );
    });

    test('ni la source ni le filtre de page ne l\'écartent', () {
      expect(
        _compose(
          _section(
            sort: MediaSectionSort.manual,
            manualIds: ['t2', 't1'],
            filter: const MediaFilter(
              rubric: 'prieres',
              branch: 'aneho',
              search: 'zzz',
            ),
          ),
          page: const MediaPageView(
            id: 1,
            family: 'gathering',
            filter: MediaFilter(rubric: 'dimanche'),
          ),
        ),
        ['t2', 't1'],
      );
    });

    test('la puce et la loupe s\'appliquent encore', () {
      final section = _section(
        sort: MediaSectionSort.manual,
        manualIds: ['t4', 't3', 't2', 't1'],
      );
      expect(
        _compose(section, chip: const MediaFilter(rubric: 'prieres')),
        ['t3', 't1'],
      );
      expect(_compose(section, query: 'louange'), ['t4']);
    });

    test('la famille de la source compte toujours', () {
      expect(
        _compose(_section(
          sort: MediaSectionSort.manual,
          family: null,
          manualIds: ['t1'],
        )),
        isEmpty,
      );
    });

    test('rien de choisi : une section vide', () {
      expect(_compose(_section(sort: MediaSectionSort.manual)), isEmpty);
    });
  });

  test('le plafond s\'applique en dernier', () {
    expect(_compose(_section(maxItems: 2)), ['t1', 't2']);
    // Après le filtre, pas avant : deux prières, et non « deux, puis filtrer ».
    expect(
      _compose(_section(maxItems: 2),
          chip: const MediaFilter(rubric: 'dimanche')),
      ['t2', 't4'],
    );
    expect(
      _compose(_section(
        sort: MediaSectionSort.manual,
        manualIds: ['t4', 't3', 't2'],
        maxItems: 1,
      )),
      ['t4'],
    );
  });

  test('les chaînes libres inconnues se replient', () {
    expect(MediaSectionLayout.of('mosaic'), MediaSectionLayout.list);
    expect(MediaSectionLayout.of('grid'), MediaSectionLayout.grid);
    expect(MediaSectionSort.of('random'), MediaSectionSort.latest);
    expect(MediaSectionSort.of('manual'), MediaSectionSort.manual);
  });
}
