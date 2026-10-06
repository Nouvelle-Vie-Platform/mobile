import 'package:drift/drift.dart';

import '../../models/media_page_view.dart';
import '../../models/menu_entry_view.dart';
import '../../utils/i18n_text.dart';
import 'app_database.dart';
import 'tables/gathering_tables.dart';
import 'tables/media_page_tables.dart';
import 'tables/mediatheque_tables.dart';

part 'media_pages_dao.g.dart';

/// **La lecture de la médiathèque en pages** (#167) : les pages dans leur
/// ordre, chacune avec ses puces et ses sections, et la résolution des slugs
/// de rubrique des deux familles.
///
/// Une puce ou une section dont la page n'est pas (ou plus) en magasin est
/// **ignorée** — jamais remontée ailleurs. Les contenus, eux, ne sont pas lus
/// ici : la composition d'une section (`composeSection`) se fait sur les listes
/// que l'écran lit déjà.
@DriftAccessor(
  tables: [
    MediaPages,
    MediaPageChips,
    MediaPageSections,
    TeachingTypes,
    GatheringTypes,
  ],
)
class MediaPagesDao extends DatabaseAccessor<AppDatabase>
    with _$MediaPagesDaoMixin {
  MediaPagesDao(super.db);

  /// Réémet à chaque écriture de l'une des cinq tables : une requête vide
  /// observée sert de signal, puis tout se relit. Quelques dizaines de lignes
  /// de configuration — relire le tout est plus sûr que d'assembler trois flux.
  Stream<MediaLibraryLayout> watchLayout(String locale) => customSelect(
        'SELECT 1',
        readsFrom: {
          mediaPages,
          mediaPageChips,
          mediaPageSections,
          teachingTypes,
          gatheringTypes,
        },
      ).watch().asyncMap((_) => readLayout(locale));

  Future<MediaLibraryLayout> readLayout(String locale) async {
    final pages = await (select(mediaPages)
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.id)
          ]))
        .get();
    final chips = await (select(mediaPageChips)
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.id)
          ]))
        .get();
    final sections = await (select(mediaPageSections)
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.id)
          ]))
        .get();
    final teachingRubrics = await select(teachingTypes).get();
    final gatheringRubrics = await select(gatheringTypes).get();

    String resolved(Map<String, String>? map) =>
        map == null ? '' : pick(map, locale).trim();

    return MediaLibraryLayout(
      teachingRubricIds: {for (final t in teachingRubrics) t.slug: t.id},
      gatheringRubricIds: {for (final g in gatheringRubrics) g.slug: g.id},
      pages: List.unmodifiable([
        for (final page in pages)
          MediaPageView(
            id: page.id,
            label: resolved(page.label),
            labelKey: page.labelKey,
            family: page.destinationFamily,
            filter: MediaFilter(
              rubric: page.destinationRubric,
              branch: page.destinationBranch,
              search: page.destinationSearch,
            ),
            chips: List.unmodifiable([
              for (final chip in chips)
                if (chip.mediaPageId == page.id)
                  MediaChipView(
                    id: chip.id,
                    label: resolved(chip.label),
                    filter: MediaFilter(
                      rubric: chip.filterRubric,
                      branch: chip.filterBranch,
                      search: chip.filterSearch,
                    ),
                  ),
            ]),
            sections: List.unmodifiable([
              for (final section in sections)
                if (section.mediaPageId == page.id)
                  MediaSectionView(
                    id: section.id,
                    layout: MediaSectionLayout.of(section.layout),
                    sort: MediaSectionSort.of(section.sort),
                    family: MenuContentFamily.of(section.destinationFamily),
                    maxItems: section.maxItems,
                    titleKey: section.titleKey,
                    title: resolved(section.title),
                    filter: MediaFilter(
                      rubric: section.destinationRubric,
                      branch: section.destinationBranch,
                      search: section.destinationSearch,
                    ),
                    manualIds: section.manualIds,
                    rankedIds: section.rankedIds,
                  ),
            ]),
          ),
      ]),
    );
  }
}
