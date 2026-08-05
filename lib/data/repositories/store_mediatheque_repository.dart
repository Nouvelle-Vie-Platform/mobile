import '../../models/mediatheque_view.dart';
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
  Stream<TeachingView?> teachingById(String id, {required String locale}) {
    return _dao
        .teachingById(id)
        .watchSingleOrNull()
        .map((row) => row == null ? null : _view(row, locale));
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
                teachingCount: section.teachingCount,
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
      playlistUrl: row.teaching.playlistUrl,
      description: row.teaching.description,
      recordedAt: parseCalendarDayOrNull(row.teaching.recordedAt),
      publishedAt: row.teaching.publishedAt,
      isFullService: row.teaching.isFullService,
    );
  }
}

/// Lit une couleur servie par le serveur (`#RRGGBB`, `#AARRGGBB`, ou sans `#`)
/// et rend son ARGB.
///
/// **Une valeur illisible rend `null`, et ne lève pas.** Une couleur est un
/// habillage : une faute de frappe dans le portail ne doit pas faire disparaître
/// un enseignement de l'écran. `null` laisse simplement la cascade continuer
/// vers la rubrique, puis vers le bleu de marque.
///
/// L'opacité est ajoutée quand elle manque : le serveur sert des couleurs
/// pleines, `0x223B8C` sans alpha serait transparent.
int? parseHexColor(String? source) {
  var raw = source?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('#')) raw = raw.substring(1);
  if (raw.length != 6 && raw.length != 8) return null;
  final value = int.tryParse(raw, radix: 16);
  if (value == null) return null;
  return raw.length == 6 ? 0xFF000000 | value : value;
}

/// Lit le **jour** d'enregistrement stocké en texte (`YYYY-MM-DD`).
///
/// Ancré à minuit **UTC** non pour désigner un instant, mais pour qu'aucun
/// appareil ne puisse le déplacer : `DateTime.parse('2026-04-12')` seul rend
/// minuit en heure **locale**, et un téléphone à l'est du serveur afficherait
/// « samedi 11 » un enseignement du dimanche 12.
///
/// Tolérant comme [parseHexColor], et pour la même raison : une date illisible
/// vaut « pas de date », jamais un écran qui plante.
DateTime? parseCalendarDayOrNull(String? source) {
  final raw = source?.trim();
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}
