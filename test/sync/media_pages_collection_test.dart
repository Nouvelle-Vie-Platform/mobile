/// **Les trois collections de la médiathèque en pages, de bout en bout**
/// (#167, serveur #540) : `media_pages`, `media_page_chips`,
/// `media_page_sections`.
///
/// Les lignes s'écrivent par le **moteur**, depuis la forme relevée sur les
/// transformers serveur (`media_page*_transformer.ts`) — c'est la seule façon
/// de prouver qu'elle traverse `sync_rows.dart`. Puis `MediaPagesDao` les relit.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/branch_filter.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/sync_protocol.dart';
import 'package:maison_du_miracle/data/sync/sync_rows.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';
import 'package:maison_du_miracle/models/media_page_view.dart';
import 'package:maison_du_miracle/models/menu_entry_view.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

const _keys = [
  SyncCollectionKey.mediaPages,
  SyncCollectionKey.mediaPageChips,
  SyncCollectionKey.mediaPageSections,
];

/// `media_page_transformer.ts` : neuf clés, plus le tombstone.
Map<String, Object?> pagePayload(
  int id, {
  String? labelKey,
  Map<String, Object?>? label,
  int position = 1,
  String? family,
  String? rubric,
  String? deletedAt,
}) =>
    {
      'id': id,
      'labelKey': labelKey,
      'position': position,
      'destinationFamily': family,
      'destinationRubric': rubric,
      'destinationBranch': null,
      'destinationSearch': null,
      'createdAt': '2026-10-01T09:00:00.000Z',
      'updatedAt': '2026-10-01T10:00:00.000Z',
      'label': label,
      'deletedAt': deletedAt,
    };

/// `media_page_chip_transformer.ts`.
Map<String, Object?> chipPayload(
  int id,
  int pageId, {
  Map<String, Object?> label = const {'fr': 'Prières'},
  int position = 1,
  String? rubric,
  String? deletedAt,
}) =>
    {
      'id': id,
      'mediaPageId': pageId,
      'label': label,
      'position': position,
      'filterRubric': rubric,
      'filterBranch': null,
      'filterSearch': null,
      'createdAt': '2026-10-01T09:00:00.000Z',
      'updatedAt': '2026-10-01T10:00:00.000Z',
      'deletedAt': deletedAt,
    };

/// `media_page_section_transformer.ts`.
Map<String, Object?> sectionPayload(
  int id,
  int pageId, {
  int position = 1,
  String layout = 'carousel',
  String sort = 'latest',
  int maxItems = 10,
  String family = 'teaching',
  String? titleKey,
  Map<String, Object?>? title,
  List<Object?>? manualIds,
  List<Object?>? rankedIds,
  String? deletedAt,
}) =>
    {
      'id': id,
      'mediaPageId': pageId,
      'position': position,
      'layout': layout,
      'sort': sort,
      'maxItems': maxItems,
      'destinationFamily': family,
      'destinationRubric': null,
      'destinationBranch': null,
      'destinationSearch': null,
      'createdAt': '2026-10-01T09:00:00.000Z',
      'updatedAt': '2026-10-01T10:00:00.000Z',
      'titleKey': titleKey,
      'title': title,
      'manualIds': manualIds,
      'rankedIds': rankedIds,
      'deletedAt': deletedAt,
    };

String _cursor(int id) => serverCursor(
      updatedAtIso: '2026-10-01T10:00:00.000Z',
      id: id,
    );

void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
    dao = db.syncDao;
  });

  tearDown(() => db.close());

  Map<String, Object?> manifest() => {
        'scope_version': 1,
        'collections': [
          for (final key in _keys)
            manifestEntry(
              key,
              partition: 'reference',
              currentCursor: _cursor(1),
              hasChanges: true,
              fromZero: true,
            ),
        ],
      };

  SyncEngine engine() => SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) => _keys.contains(c.key))
            .toList(growable: false),
      );

  group('Le registre', () {
    test('rangées juste après les menus, pages d\'abord, avant tout contenu',
        () {
      final keys = syncedCollections().map((c) => c.key).toList();
      final menu = keys.indexOf(SyncCollectionKey.menuEntries);
      expect(keys.sublist(menu + 1, menu + 4), _keys);
      expect(
        keys.indexOf(SyncCollectionKey.mediaPageSections),
        lessThan(keys.indexOf(SyncCollectionKey.teachings)),
      );
    });

    test('des référentiels globaux, jamais filtrés par branche', () {
      for (final key in _keys) {
        expect(isBranchScoped(key), isFalse, reason: key);
        expect(kSyncCollections[key], 'reference', reason: key);
      }
    });
  });

  group('Le tirage', () {
    test('page, puce et section entrent au magasin, entières', () async {
      server
        ..serveManifest(manifest())
        ..serveCollection(
          'media_pages',
          deltaPage(
            items: [pagePayload(1, labelKey: 'public.nav.mediatheque')],
            nextCursor: _cursor(1),
          ),
        )
        ..serveCollection(
          'media_page_chips',
          deltaPage(
            items: [chipPayload(3, 1, rubric: 'prieres')],
            nextCursor: _cursor(3),
          ),
        )
        ..serveCollection(
          'media_page_sections',
          deltaPage(
            items: [
              sectionPayload(
                7,
                1,
                titleKey: 'sectionLatestTeachings',
                sort: 'manual',
                layout: 'grid',
                manualIds: ['t-2', 't-1'],
              ),
            ],
            nextCursor: _cursor(7),
          ),
        );

      final report = await engine().synchronize();
      expect(report.pulled, _keys);

      final page = (await db.select(db.mediaPages).get()).single;
      // `label = null` est une valeur : « le libellé du dépôt ».
      expect(page.label, isNull);
      expect(page.labelKey, 'public.nav.mediatheque');

      final chip = (await db.select(db.mediaPageChips).get()).single;
      expect(chip.mediaPageId, 1);
      expect(chip.label, {'fr': 'Prières'});
      expect(chip.filterRubric, 'prieres');

      final section = (await db.select(db.mediaPageSections).get()).single;
      expect(section.layout, 'grid');
      expect(section.sort, 'manual');
      expect(section.titleKey, 'sectionLatestTeachings');
      expect(section.manualIds, ['t-2', 't-1']);
      // Jamais classée : `null`, pas une liste vide.
      expect(section.rankedIds, isNull);

      expect(await dao.cursorFor(SyncCollectionKey.mediaPages), _cursor(1));
    });

    test('un tombstone retire la page, la puce et la section', () async {
      server
        ..serveManifest(manifest())
        ..servePages('media_pages', [
          deltaPage(
            items: [
              pagePayload(1, label: {'fr': 'Tout'})
            ],
            nextCursor: _cursor(1),
          ),
          deltaPage(
            items: [
              pagePayload(1,
                  label: {'fr': 'Tout'}, deletedAt: '2026-10-02T10:00:00.000Z'),
            ],
            nextCursor: _cursor(1),
          ),
        ])
        ..servePages('media_page_chips', [
          deltaPage(items: [chipPayload(3, 1)], nextCursor: _cursor(3)),
          deltaPage(
            items: [chipPayload(3, 1, deletedAt: '2026-10-02T10:00:00.000Z')],
            nextCursor: _cursor(3),
          ),
        ])
        ..servePages('media_page_sections', [
          deltaPage(items: [sectionPayload(7, 1)], nextCursor: _cursor(7)),
          deltaPage(
            items: [
              sectionPayload(7, 1, deletedAt: '2026-10-02T10:00:00.000Z'),
            ],
            nextCursor: _cursor(7),
          ),
        ]);

      await engine().synchronize();
      expect(await db.select(db.mediaPages).get(), hasLength(1));
      expect(await db.select(db.mediaPageChips).get(), hasLength(1));
      expect(await db.select(db.mediaPageSections).get(), hasLength(1));

      await engine().synchronize();
      // Sans tombstone, l'onglet resterait sur chaque téléphone.
      expect(await db.select(db.mediaPages).get(), isEmpty);
      expect(await db.select(db.mediaPageChips).get(), isEmpty);
      expect(await db.select(db.mediaPageSections).get(), isEmpty);
    });
  });

  group('MediaPagesDao', () {
    Future<void> put(
      String key,
      List<Map<String, Object?>> items,
    ) async {
      final collection = syncedCollectionFor(key)!;
      await collection.applyPage(
        dao,
        DeltaPage.fromJson(deltaPage(items: items, nextCursor: _cursor(1))),
      );
    }

    test('les pages dans leur ordre, chacune avec ses puces et sections',
        () async {
      await put('media_pages', [
        pagePayload(1, label: {'fr': 'Tout', 'en': 'All'}, position: 2),
        pagePayload(2,
            label: {'fr': 'Prières'},
            position: 1,
            family: 'teaching',
            rubric: 'prieres'),
      ]);
      await put('media_page_chips', [
        chipPayload(10, 1, label: {'fr': 'B'}, position: 2),
        chipPayload(11, 1, label: {'fr': 'A'}, position: 1),
        // Orpheline : sa page n'est pas en magasin, elle est ignorée.
        chipPayload(12, 99),
      ]);
      await put('media_page_sections', [
        sectionPayload(20, 1, position: 2, layout: 'list', sort: 'popular'),
        sectionPayload(21, 1,
            position: 1, layout: 'hero', title: {'fr': 'À la une'}),
        sectionPayload(22, 2, family: 'gathering', layout: 'mosaic'),
        sectionPayload(23, 99),
      ]);
      await db.into(db.teachingTypes).insert(
            teachingTypeRow(5, label: {'fr': 'Prière'}, slug: 'prieres'),
          );
      await db.into(db.gatheringTypes).insert(
            gatheringTypeRow(6, label: {'fr': 'Concert'}, slug: 'concerts'),
          );
      await db.into(db.branches).insert(
            branchRowOf({'id': 7, 'name': 'Aného', 'slug': 'aneho'}),
          );
      // Sans slug : non adressable, absente de la résolution.
      await db.into(db.branches).insert(
            branchRowOf({'id': 8, 'name': 'Lomé', 'slug': null}),
          );

      final layout = await db.mediaPagesDao.readLayout('en');

      expect(layout.pages.map((p) => p.id), [2, 1]);
      final all = layout.pages.last;
      // Replié par `pick`, dans la langue du contenu.
      expect(all.label, 'All');
      expect(all.chips.map((c) => c.label), ['A', 'B']);
      expect(all.sections.map((s) => s.id), [21, 20]);
      expect(all.sections.first.layout, MediaSectionLayout.hero);
      expect(all.sections.first.title, 'À la une');
      expect(all.sections.last.sort, MediaSectionSort.popular);

      final prieres = layout.pages.first;
      expect(prieres.family, 'teaching');
      expect(prieres.filter.rubric, 'prieres');
      expect(prieres.chips, isEmpty);
      final gathering = prieres.sections.single;
      expect(gathering.family, MenuContentFamily.gathering);
      // Un gabarit inconnu se replie sur la liste.
      expect(gathering.layout, MediaSectionLayout.list);

      expect(layout.teachingRubricIds, {'prieres': 5});
      expect(layout.gatheringRubricIds, {'concerts': 6});
      expect(layout.branchIds, {'aneho': 7});
    });

    test('le flux réémet quand une section arrive', () async {
      await put('media_pages', [
        pagePayload(1, label: {'fr': 'Tout'})
      ]);
      final seen = <List<int>>[];
      final sub = db.mediaPagesDao
          .watchLayout('fr')
          .map((l) => [for (final s in l.pages.single.sections) s.id])
          .listen(seen.add);
      await pumpEventQueue();

      await put('media_page_sections', [sectionPayload(7, 1)]);
      await pumpEventQueue();
      await sub.cancel();

      expect(seen.first, isEmpty);
      expect(seen.last, [7]);
    });

    test('un magasin vide : aucune page', () async {
      expect((await db.mediaPagesDao.readLayout('fr')).pages, isEmpty);
    });
  });
}
