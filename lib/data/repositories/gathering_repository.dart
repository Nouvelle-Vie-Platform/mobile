import '../../models/gathering_view.dart';
import '../../models/models.dart';
import '../sample_data.dart';

/// Rassemblements — **repository dédié, asynchrone, et le seul chemin des
/// écrans vers les rassemblements**.
///
/// Le jumeau de `MediathequeRepository` pour l'autre famille, et **jamais une
/// méthode de plus sur celui-ci** : ce sont deux collections, deux types, deux
/// écrans (ADR-0026, décision 1). Les fondre en un repository paramétré par une
/// famille rendrait possible — donc, un jour, réel — un appel qui mélange les
/// deux ; ici le système de types l'interdit, un `GatheringView` ne pouvant pas
/// se glisser dans une liste d'enseignements.
///
/// **Des `Stream`, pas des `Future`**, pour la même raison que la médiathèque :
/// la source est un magasin local que la synchronisation réécrit sous les pieds
/// des écrans, et une rétractation (`{ id, deletedAt }`, ADR-0025) reçue pendant
/// la consultation doit retirer le contenu de l'écran ouvert.
///
/// Tout ce qui sort d'ici est **déjà résolu** pour l'affichage : couleur en
/// cascade, libellé replié, URL absolues. D'où le [locale] exigé à chaque appel.
abstract interface class GatheringRepository {
  /// Les derniers rassemblements, **toutes rubriques confondues**.
  Stream<List<GatheringView>> latestGatherings({
    required String locale,
    int? limit,
  });

  /// Les rassemblements d'une rubrique, du plus récemment mis à disposition au
  /// plus ancien. Peut être vide.
  Stream<List<GatheringView>> gatheringsOfType(
    int gatheringTypeId, {
    required String locale,
  });

  /// Un rassemblement par son identifiant, `null` s'il ne résout plus rien.
  ///
  /// `null` **n'est pas une erreur technique** : c'est l'une des quatre
  /// absences (« contenu retiré », cf. `ContentAbsence`).
  Stream<GatheringView?> gatheringById(String id, {required String locale});

  /// Les rubriques de rassemblement de l'accueil, dans l'ordre voulu par le
  /// serveur, réduites à celles qui sont visibles **et** dont le magasin
  /// possède au moins un rassemblement.
  ///
  /// Ce second filtre n'est pas cosmétique : `gathering_types` se supprime
  /// durement, **sans tombstone**, et c'est ce qui fait disparaître d'elle-même
  /// une rubrique retirée côté serveur.
  Stream<List<GatheringSectionView>> homeSections({required String locale});
}

/// Implémentation **en mémoire**, servie quand `AppEnv.useBackend` est faux
/// (mode maquette) et dans les tests d'écran.
///
/// Comme le double de la médiathèque, elle refait à la main la jointure et les
/// tris que le magasin fait en SQL : le mode maquette doit exercer **les mêmes
/// règles de lecture** que le mode magasin, sans quoi les bugs de cascade et de
/// repli de langue resteraient invisibles jusqu'à la production. Ces règles-là
/// ne sont pas recopiées — elles vivent une seule fois dans
/// `GatheringView.resolve`.
///
/// Les fixtures réutilisent les modèles de maquette [Teaching] / [TeachingType],
/// et c'est délibéré : ce sont des **formes de contenu de médiathèque**, jamais
/// rendues à l'écran (le modèle de lecture s'interpose), et le serveur lui-même
/// range les deux familles dans une seule table. Les dédoubler aurait doublé la
/// surface de la maquette pour zéro différence de comportement.
class InMemoryGatheringRepository implements GatheringRepository {
  InMemoryGatheringRepository({
    List<Teaching>? gatherings,
    List<TeachingType>? types,
  })  : _gatherings = gatherings ?? SampleData.gatherings,
        _types = types ?? SampleData.gatheringTypes;

  final List<Teaching> _gatherings;
  final List<TeachingType> _types;

  @override
  Stream<List<GatheringView>> latestGatherings({
    required String locale,
    int? limit,
  }) {
    final sorted = _sorted(_gatherings);
    final capped = limit != null && sorted.length > limit
        ? sorted.sublist(0, limit)
        : sorted;
    return Stream.value(_views(capped, locale));
  }

  @override
  Stream<List<GatheringView>> gatheringsOfType(
    int gatheringTypeId, {
    required String locale,
  }) {
    final matching =
        _gatherings.where((g) => g.teachingTypeId == gatheringTypeId);
    return Stream.value(_views(_sorted(matching), locale));
  }

  @override
  Stream<GatheringView?> gatheringById(String id, {required String locale}) {
    for (final gathering in _gatherings) {
      if (gathering.id == id) return Stream.value(_view(gathering, locale));
    }
    return Stream.value(null);
  }

  @override
  Stream<List<GatheringSectionView>> homeSections({required String locale}) {
    final sections = <GatheringSectionView>[];
    for (final type in _types) {
      if (!type.visibleOnHome) continue;
      final count =
          _gatherings.where((g) => g.teachingTypeId == type.id).length;
      // « Pas de rassemblement, pas de section » — la même règle que le magasin.
      if (count == 0) continue;
      sections.add(
        GatheringSectionView.resolve(
          teachingTypeId: type.id,
          label: type.label,
          slug: type.slug,
          locale: locale,
          itemCount: count,
          color: type.color,
          layout: type.layout,
          position: type.position,
        ),
      );
    }
    sections.sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0
          ? byPosition
          : a.teachingTypeId.compareTo(b.teachingTypeId);
    });
    return Stream.value(List<GatheringSectionView>.unmodifiable(sections));
  }

  /// Miroir du tri du magasin : mise à disposition décroissante, puis jour
  /// d'enregistrement, puis identifiant — pour que l'ordre soit **stable**
  /// d'un appel à l'autre (`List.sort` n'est pas stable en Dart).
  List<Teaching> _sorted(Iterable<Teaching> source) => source.toList()
    ..sort((a, b) {
      final byPublished = b.publishedAt.compareTo(a.publishedAt);
      if (byPublished != 0) return byPublished;
      final byRecorded = b.recordedAt.compareTo(a.recordedAt);
      return byRecorded != 0 ? byRecorded : b.id.compareTo(a.id);
    });

  List<GatheringView> _views(List<Teaching> source, String locale) =>
      List<GatheringView>.unmodifiable(
        source.map((gathering) => _view(gathering, locale)),
      );

  GatheringView _view(Teaching gathering, String locale) {
    final type = _typeOf(gathering.teachingTypeId);
    return GatheringView.resolve(
      id: gathering.id,
      title: gathering.title,
      locale: locale,
      contributorName: gathering.author,
      teachingTypeId: gathering.teachingTypeId,
      typeLabel: type?.label,
      color: gathering.color,
      typeColor: type?.color,
      imageLandscapeUrl: gathering.imageLandscapeUrl,
      imagePortraitUrl: gathering.imagePortraitUrl,
      playlistUrl: gathering.playlistUrl,
      description: gathering.description,
      recordedAt: gathering.recordedAt,
      publishedAt: gathering.publishedAt,
      isFullService: gathering.isFullService,
    );
  }

  /// Jointure **tolérante** : `null` quand la rubrique désignée n'existe pas.
  TeachingType? _typeOf(int? id) {
    if (id == null) return null;
    for (final type in _types) {
      if (type.id == id) return type;
    }
    return null;
  }
}
