import '../../models/gathering_view.dart';
import '../../utils/search_terms.dart';
import '../../utils/server_values.dart';
import '../local/gathering_dao.dart';
import 'gathering_repository.dart';

/// Les rassemblements **peints depuis le magasin local**, jamais depuis le
/// réseau.
///
/// Le jumeau de `StoreMediathequeRepository` : aucune requête ne part d'ici. La
/// synchronisation écrit dans le magasin et ne rend rien ; les écrans lisent le
/// magasin et n'attendent rien du réseau (ADR-0026).
///
/// Son seul travail est de **traduire des lignes en modèle de lecture** :
/// désérialiser ce que le magasin stocke tel que le serveur l'envoie — une
/// couleur en `#RRGGBB`, un jour de calendrier en texte — puis laisser
/// [GatheringView.resolve] appliquer les règles de présentation. La frontière
/// est là : ici la **forme** des valeurs, là-bas les **règles**.
class StoreGatheringRepository implements GatheringRepository {
  const StoreGatheringRepository(this._dao);

  final GatheringDao _dao;

  @override
  Stream<List<GatheringView>> latestGatherings({
    required String locale,
    int? limit,
  }) {
    return _dao
        .latestGatherings(limit: limit)
        .watch()
        .map((rows) => _views(rows, locale));
  }

  @override
  Stream<List<GatheringView>> gatheringsOfType(
    int gatheringTypeId, {
    required String locale,
  }) {
    return _dao
        .gatheringsOfType(gatheringTypeId)
        .watch()
        .map((rows) => _views(rows, locale));
  }

  @override
  Stream<List<GatheringView>> gatheringsMatching({
    required String locale,
    int? gatheringTypeId,
    String? search,
  }) {
    return _dao
        .gatheringsMatching(
          gatheringTypeId: gatheringTypeId,
          searchPattern: searchPattern(search),
        )
        .watch()
        .map((rows) => _views(rows, locale));
  }

  @override
  Stream<GatheringView?> gatheringById(String id, {required String locale}) {
    return _dao
        .gatheringById(id)
        .watchSingleOrNull()
        .map((row) => row == null ? null : _view(row, locale));
  }

  @override
  Stream<List<GatheringSectionView>> homeSections({required String locale}) {
    return _dao.homeSections().watch().map(
          (sections) => List<GatheringSectionView>.unmodifiable(
            sections.map(
              (section) => GatheringSectionView.resolve(
                teachingTypeId: section.type.id,
                label: section.type.label,
                slug: section.type.slug,
                locale: locale,
                itemCount: section.gatheringCount,
                color: parseHexColor(section.type.color),
                layout: section.type.layout,
                position: section.type.position,
              ),
            ),
          ),
        );
  }

  List<GatheringView> _views(List<GatheringWithRefs> rows, String locale) =>
      List<GatheringView>.unmodifiable(rows.map((row) => _view(row, locale)));

  GatheringView _view(GatheringWithRefs row, String locale) {
    return GatheringView.resolve(
      id: row.gathering.id,
      title: row.gathering.title,
      locale: locale,
      // `null` traverse : l'intervenant n'est peut-être pas encore arrivé, et
      // le rassemblement s'affiche quand même — sans ligne d'auteur inventée.
      contributorName: row.contributor?.name,
      teachingTypeId: row.gathering.teachingTypeId,
      branchId: row.gathering.branchId,
      typeLabel: row.type?.label,
      // Les deux maillons bruts, séparés : c'est le modèle de lecture qui
      // termine la cascade, pas le magasin ni le serveur.
      color: parseHexColor(row.gathering.color),
      typeColor: parseHexColor(row.type?.color),
      imageLandscapeUrl: row.gathering.imageLandscapeUrl,
      imagePortraitUrl: row.gathering.imagePortraitUrl,
      playlistUrl: row.gathering.playlistUrl,
      description: row.gathering.description,
      recordedAt: parseCalendarDayOrNull(row.gathering.recordedAt),
      publishedAt: row.gathering.publishedAt,
      isFullService: row.gathering.isFullService,
    );
  }
}
