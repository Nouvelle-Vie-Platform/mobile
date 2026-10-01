import '../../models/mediatheque_view.dart';
import '../../utils/search_terms.dart';
import '../../utils/server_values.dart';
import '../local/mediatheque_dao.dart';
import 'mediatheque_repository.dart';

/// La médiathèque **peinte depuis le magasin local**, jamais depuis le réseau.
///
/// Ce n'est pas une implémentation « HTTP » comme `HttpCalendarRepository` :
/// aucune requête ne part d'ici. La synchronisation écrit dans le magasin et ne
/// rend rien ; les écrans lisent le magasin et n'attendent rien du réseau
/// (ADR-0026). C'est ce qui fait que la médiathèque s'affiche hors ligne, à la
/// première image.
///
/// Son seul travail est de **traduire des lignes en modèle de lecture** :
/// désérialiser ce que le magasin stocke tel que le serveur l'envoie — une
/// couleur en `#RRGGBB`, un jour de calendrier en texte — puis laisser
/// [TeachingView.resolve] appliquer les règles de présentation. La frontière
/// est là : ici la **forme** des valeurs, là-bas les **règles**.
class StoreMediathequeRepository implements MediathequeRepository {
  const StoreMediathequeRepository(this._dao);

  final MediathequeDao _dao;

  @override
  Stream<List<TeachingView>> latestTeachings({
    required String locale,
    int? limit,
  }) {
    return _dao
        .latestTeachings(limit: limit)
        .watch()
        .map((rows) => _views(rows, locale));
  }

  @override
  Stream<List<TeachingView>> teachingsOfType(
    int teachingTypeId, {
    required String locale,
  }) {
    return _dao
        .teachingsOfType(teachingTypeId)
        .watch()
        .map((rows) => _views(rows, locale));
  }

  @override
  Stream<List<TeachingView>> teachingsMatching({
    required String locale,
    int? teachingTypeId,
    String? search,
  }) {
    return _dao
        .teachingsMatching(
          teachingTypeId: teachingTypeId,
          searchPattern: searchPattern(search),
        )
        .watch()
        .map((rows) => _views(rows, locale));
  }

  @override
  Stream<int?> rubricIdOfSlug(String slug) =>
      _dao.teachingTypeBySlug(slug).watchSingleOrNull().map((row) => row?.id);

  @override
  Stream<TeachingView?> teachingById(String id, {required String locale}) {
    return _dao
        .teachingById(id)
        .watchSingleOrNull()
        .map((row) => row == null ? null : _view(row, locale));
  }

  /// **Les invités, nommés par la copie locale de `contributors`** (#77).
  ///
  /// Le magasin rend la ligne de pivot même sans son intervenant — pour qu'un
  /// manquant n'emporte pas les autres — et c'est ici, une fois pour toute
  /// l'application, que l'invité sans nom est **écarté**. Un « Invité inconnu »
  /// ressemblerait à une donnée et serait pris pour une erreur de saisie ;
  /// l'absence se dessine comme une absence, et le nom paraîtra au cycle de
  /// synchronisation suivant.
  ///
  /// Le nom est **joint**, jamais recopié : renommer un intervenant n'écrit rien
  /// sur le pivot, donc rien ne repasserait par le flux pour corriger une copie.
  @override
  Stream<List<String>> guestNames(String teachingId) {
    return _dao.guestsOfTeaching(teachingId).watch().map(
          (rows) => List<String>.unmodifiable(
            rows
                .map((row) => row.contributor?.name.trim())
                .whereType<String>()
                .where((name) => name.isNotEmpty),
          ),
        );
  }

  @override
  Stream<List<HomeSectionView>> homeSections({required String locale}) {
    return _dao.homeSections().watch().map(
          (sections) => List<HomeSectionView>.unmodifiable(
            sections.map(
              (section) => HomeSectionView.resolve(
                teachingTypeId: section.type.id,
                label: section.type.label,
                slug: section.type.slug,
                locale: locale,
                itemCount: section.teachingCount,
                color: parseHexColor(section.type.color),
                layout: section.type.layout,
                position: section.type.position,
              ),
            ),
          ),
        );
  }

  List<TeachingView> _views(List<TeachingWithRefs> rows, String locale) =>
      List<TeachingView>.unmodifiable(rows.map((row) => _view(row, locale)));

  TeachingView _view(TeachingWithRefs row, String locale) {
    return TeachingView.resolve(
      id: row.teaching.id,
      title: row.teaching.title,
      locale: locale,
      // `null` traverse : l'intervenant n'est peut-être pas encore arrivé, et
      // l'enseignement s'affiche quand même — sans ligne d'auteur inventée.
      contributorName: row.contributor?.name,
      teachingTypeId: row.teaching.teachingTypeId,
      typeLabel: row.type?.label,
      // Les deux maillons bruts, séparés : c'est le modèle de lecture qui
      // termine la cascade, pas le magasin ni le serveur.
      color: parseHexColor(row.teaching.color),
      typeColor: parseHexColor(row.type?.color),
      imageLandscapeUrl: row.teaching.imageLandscapeUrl,
      imagePortraitUrl: row.teaching.imagePortraitUrl,
      imageSquareUrl: row.teaching.imageSquareUrl,
      playlistUrl: row.teaching.playlistUrl,
      description: row.teaching.description,
      recordedAt: parseCalendarDayOrNull(row.teaching.recordedAt),
      publishedAt: row.teaching.publishedAt,
      isFullService: row.teaching.isFullService,
    );
  }
}
