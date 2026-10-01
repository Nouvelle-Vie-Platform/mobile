import '../../models/mediatheque_view.dart';
import '../../models/models.dart';
import '../../utils/search_terms.dart';
import '../sample_data.dart';

/// Médiathèque — **repository dédié, asynchrone, et le seul chemin des écrans
/// vers les enseignements**.
///
/// Hors de `ChurchRepository` à dessein (CLAUDE.md, « Brancher un vrai
/// backend ») : ce contrat-là est **synchrone** et ne couvre plus que des
/// domaines fictifs. Le passer en `Future` pour la médiathèque casserait les
/// cinq autres d'un coup, et tous leurs écrans. Le motif du dépôt est
/// l'inverse — un domaine servi par le back **sort** vers sa propre
/// abstraction, comme `AuthRepository`, `BranchRepository` et
/// `CalendarRepository` avant lui. `ChurchRepository` rétrécit d'autant ; c'est
/// voulu, il finira par disparaître.
///
/// **Des `Stream`, pas des `Future`**, et ce n'est pas de la coquetterie : la
/// source est un magasin local que la synchronisation réécrit sous les pieds
/// des écrans. Une rétractation (`{ id, deletedAt }`, ADR-0025) reçue pendant
/// qu'un fidèle écoute doit **retirer le contenu de l'écran ouvert** et arrêter
/// la lecture. Un `Future` livrerait une photographie prise au moment du clic,
/// exactement ce que la convention « l'identifiant, jamais l'objet » cherche à
/// éviter. Drift rend un flux qui ré-émet à chaque écriture des tables lues ;
/// le double en mémoire, lui, n'a qu'une valeur à émettre.
///
/// Tout ce qui sort d'ici est **déjà résolu** pour l'affichage
/// ([TeachingView], [HomeSectionView]) : couleur en cascade, libellé replié,
/// URL absolues. D'où le [locale] exigé à chaque appel — la langue courante est
/// une décision de l'application, pas du magasin, et elle change sans que le
/// magasin bouge.
abstract interface class MediathequeRepository {
  /// Les derniers enseignements, **toutes rubriques confondues**.
  ///
  /// Ce n'est pas une rubrique mais un **tri** : `libre` a été retiré du
  /// référentiel serveur précisément parce qu'il déguisait un tri en espèce.
  Stream<List<TeachingView>> latestTeachings({
    required String locale,
    int? limit,
  });

  /// Les enseignements d'une rubrique, du plus récemment mis à disposition au
  /// plus ancien. Peut être vide — une rubrique fraîchement créée côté serveur
  /// n'a encore rien.
  Stream<List<TeachingView>> teachingsOfType(
    int teachingTypeId, {
    required String locale,
  });

  /// **Les enseignements que la destination d'une entrée de menu désigne**
  /// (#82) — ce qui fait enfin filtrer les onglets de la médiathèque.
  ///
  /// Les deux bornes se **composent** : la rubrique que l'entrée a choisie et la
  /// recherche (celle de l'entrée, celle de la loupe, ou les deux). Aucune des
  /// deux n'est obligatoire — sans bornes, c'est le catalogue entier, et c'est
  /// exactement ce que désigne l'entrée indélébile de la médiathèque.
  ///
  /// ⚠️ **Les cultes entiers ne sont pas écartés** : le modèle de menu ne porte
  /// aucune colonne qui les concerne, et en décider dans le client serait une
  /// règle éditoriale figée dans le binaire, invisible depuis le portail. Le
  /// portail a déjà le moyen de les écarter dans la donnée — les ranger dans
  /// leur rubrique et ne pointer aucune entrée dessus.
  Stream<List<TeachingView>> teachingsMatching({
    required String locale,
    int? teachingTypeId,
    String? search,
  });

  /// **L'identifiant local d'une rubrique, depuis son slug** — `null` quand le
  /// magasin ne la connaît pas (encore), ou plus.
  ///
  /// C'est ce qui permet à une destination de menu et à un « Voir tout » de
  /// désigner une rubrique par ce qui survit à son renommage. `null` **n'est pas
  /// une erreur** : c'est le slug inconnu, et le client en tire la même
  /// conclusion que le site public d'un `?rubrique=` inconnu — rien, jamais
  /// « tout le catalogue ».
  Stream<int?> rubricIdOfSlug(String slug);

  /// Un enseignement par son identifiant, `null` s'il ne résout plus rien.
  ///
  /// `null` **n'est pas une erreur technique** : c'est l'une des quatre
  /// absences (« contenu retiré », cf. `ContentAbsence`). L'identifiant a été
  /// valide, il ne l'est plus.
  Stream<TeachingView?> teachingById(String id, {required String locale});

  /// **Les noms des invités d'un contenu, dans l'ordre saisi** (#77).
  ///
  /// Un **chemin distinct**, et c'est tout l'intérêt : `ContentView.authorName`
  /// est une chaîne unique partagée avec les rassemblements, le lecteur et les
  /// trois cartes d'accueil — elle ne bouge pas, et la liste des invités ne
  /// passe donc pas par elle. Seul l'écran de détail la demande ; les listes,
  /// carrousels, vignettes et la notification d'écran verrouillé continuent
  /// d'afficher le seul **animateur**.
  ///
  /// Pas de `locale` : un nom de personne ne se traduit pas.
  ///
  /// **Les invités que le magasin ne sait pas encore nommer n'en sortent pas.**
  /// La jointure du magasin est tolérante — elle rend la ligne de pivot même
  /// sans son intervenant, pour qu'un manquant n'emporte pas les autres —, et
  /// c'est ici que l'absence se dessine comme une absence (règle 4 du modèle de
  /// lecture). Une liste **vide** est l'état normal de presque tout le
  /// catalogue, et se rend en ne rendant rien.
  Stream<List<String>> guestNames(String teachingId);

  /// Les rubriques de l'accueil, dans l'ordre voulu par le serveur, réduites à
  /// celles qui sont visibles **et** dont le magasin possède au moins un
  /// enseignement.
  ///
  /// Ce second filtre n'est pas cosmétique : `teaching_types` se supprime
  /// durement, **sans tombstone**, et c'est ce qui fait disparaître d'elle-même
  /// une rubrique retirée côté serveur.
  Stream<List<HomeSectionView>> homeSections({required String locale});
}

/// Implémentation **en mémoire**, servie quand `AppEnv.useBackend` est faux
/// (mode maquette) et dans les tests d'écran.
///
/// Elle refait à la main la jointure et les tris que le magasin fait en SQL,
/// pour une raison précise : le mode maquette doit exercer **les mêmes règles
/// de lecture** que le mode magasin. Un double qui construirait ses
/// [TeachingView] autrement laisserait les bugs de cascade et de repli de
/// langue invisibles jusqu'à la production.
///
/// Les jointures y sont **tolérantes** comme celles du magasin : un
/// enseignement dont la rubrique n'existe pas dans [types] s'affiche quand
/// même, sans libellé et avec la couleur de marque.
class InMemoryMediathequeRepository implements MediathequeRepository {
  InMemoryMediathequeRepository({
    List<Teaching>? teachings,
    List<TeachingType>? types,
  })  : _teachings = teachings ?? SampleData.teachings,
        _types = types ?? SampleData.teachingTypes;

  final List<Teaching> _teachings;
  final List<TeachingType> _types;

  @override
  Stream<List<TeachingView>> latestTeachings({
    required String locale,
    int? limit,
  }) {
    final sorted = _sorted(_teachings);
    final capped = limit != null && sorted.length > limit
        ? sorted.sublist(0, limit)
        : sorted;
    return Stream.value(_views(capped, locale));
  }

  @override
  Stream<List<TeachingView>> teachingsOfType(
    int teachingTypeId, {
    required String locale,
  }) {
    final matching =
        _teachings.where((t) => t.teachingTypeId == teachingTypeId);
    return Stream.value(_views(_sorted(matching), locale));
  }

  @override
  Stream<List<TeachingView>> teachingsMatching({
    required String locale,
    int? teachingTypeId,
    String? search,
  }) {
    final term = normalizeSearchTerm(search)?.toLowerCase();
    final matching = _teachings.where((t) {
      if (teachingTypeId != null && t.teachingTypeId != teachingTypeId) {
        return false;
      }
      if (term != null && !t.title.toLowerCase().contains(term)) return false;
      return true;
    });
    return Stream.value(_views(_sorted(matching), locale));
  }

  /// La même règle qu'en magasin : le slug du référentiel, ou rien.
  @override
  Stream<int?> rubricIdOfSlug(String slug) {
    for (final type in _types) {
      if (type.slug == slug) return Stream.value(type.id);
    }
    return Stream.value(null);
  }

  @override
  Stream<TeachingView?> teachingById(String id, {required String locale}) {
    for (final teaching in _teachings) {
      if (teaching.id == id) return Stream.value(_view(teaching, locale));
    }
    return Stream.value(null);
  }

  /// **Aucun invité en mode maquette**, et ce n'est pas un trou à combler :
  /// `SampleData` ne porte pas de pivot, et en inventer un ferait croire à une
  /// donnée. Une liste vide est de toute façon l'état de presque tout le
  /// catalogue, et la règle qu'elle exerce est la bonne — pas d'invité, aucune
  /// ligne ne se rend.
  @override
  Stream<List<String>> guestNames(String teachingId) => Stream.value(const []);

  @override
  Stream<List<HomeSectionView>> homeSections({required String locale}) {
    final sections = <HomeSectionView>[];
    for (final type in _types) {
      if (!type.visibleOnHome) continue;
      final count = _teachings.where((t) => t.teachingTypeId == type.id).length;
      // « Pas d'enseignement, pas de section » — la même règle que le magasin.
      if (count == 0) continue;
      sections.add(
        HomeSectionView.resolve(
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
    return Stream.value(List<HomeSectionView>.unmodifiable(sections));
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

  List<TeachingView> _views(List<Teaching> source, String locale) =>
      List<TeachingView>.unmodifiable(
        source.map((teaching) => _view(teaching, locale)),
      );

  TeachingView _view(Teaching teaching, String locale) {
    final type = _typeOf(teaching.teachingTypeId);
    return TeachingView.resolve(
      id: teaching.id,
      title: teaching.title,
      locale: locale,
      contributorName: teaching.author,
      teachingTypeId: teaching.teachingTypeId,
      typeLabel: type?.label,
      color: teaching.color,
      typeColor: type?.color,
      imageLandscapeUrl: teaching.imageLandscapeUrl,
      imagePortraitUrl: teaching.imagePortraitUrl,
      playlistUrl: teaching.playlistUrl,
      description: teaching.description,
      recordedAt: teaching.recordedAt,
      publishedAt: teaching.publishedAt,
      isFullService: teaching.isFullService,
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
