import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/church_repository.dart';
import '../data/sample_data.dart';
import '../models/models.dart';

/// Fournit l'implémentation courante du [ChurchRepository].
///
/// Pour brancher un vrai backend, on surchargera ce provider (override) avec
/// une autre implémentation — aucun écran n'a besoin de changer.
final churchRepositoryProvider = Provider<ChurchRepository>(
  (ref) => const InMemoryChurchRepository(),
);

/// Annonces (statuts) de l'église, prêtes à l'affichage.
///
/// Le repository renvoie la liste brute ; c'est ici qu'on applique le cycle de
/// vie du feed :
/// - les statuts dont `expiresAt` est passé **disparaissent** (pas de grisé) ;
/// - tri : épinglés d'abord, puis `publishedAt` décroissant.
final announcementsProvider = Provider<List<Announcement>>((ref) {
  final now = DateTime.now().toUtc();
  final visible = ref
      .watch(churchRepositoryProvider)
      .announcements()
      .where((a) => a.expiresAt == null || a.expiresAt!.isAfter(now))
      .toList()
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final byDate = b.publishedAt.compareTo(a.publishedAt);
      if (byDate != 0) return byDate;
      // `List.sort` n'est pas stable en Dart : sans départage, deux statuts
      // publiés à la même seconde changeraient d'ordre d'un tri à l'autre.
      return a.id.compareTo(b.id);
    });
  return List<Announcement>.unmodifiable(visible);
});

/// Évènements de l'agenda.
///
/// **Provider de transition, à supprimer.** Remplacé par
/// `upcomingEventsProvider` et `monthEventsProvider`
/// (`state/calendar_providers.dart`), adossés au `CalendarRepository` dédié et
/// asynchrone livré par #16.
///
/// Il ne survit ici que parce que `home_screen.dart` et `agenda_screen.dart` le
/// lisent encore de façon **synchrone** : leur bascule vers l'`AsyncValue` est
/// le travail des issues #17 et #19, et le retirer maintenant casserait deux
/// écrans pour rien. Rien de neuf ne doit s'y brancher ; il disparaît avec le
/// dernier de ses deux lecteurs.
final eventsProvider = Provider<List<ChurchEvent>>((ref) => SampleData.events);

/// Enseignements / médiathèque.
final teachingsProvider = Provider<List<Teaching>>(
  (ref) => ref.watch(churchRepositoryProvider).teachings(),
);

/// Résout un enseignement par son identifiant, ou `null` s'il n'existe plus.
///
/// C'est le point d'entrée des écrans de détail : ils reçoivent un identifiant
/// par la route et relisent la donnée **ici**, dans la source de vérité, à
/// chaque build. Passer l'objet par `extra` en faisait une copie figée au
/// moment du clic — un contenu rétracté pendant la lecture restait affiché.
///
/// `null` n'est pas une erreur technique : c'est l'une des quatre absences que
/// l'application doit distinguer (« contenu retiré », cf. `ContentAbsence`).
/// L'identifiant a été valide, il ne l'est plus.
///
/// L'interface ne bougera pas quand le magasin local remplacera
/// [teachingsProvider] : même signature, même `null`.
final teachingByIdProvider = Provider.family<Teaching?, String>((ref, id) {
  for (final teaching in ref.watch(teachingsProvider)) {
    if (teaching.id == id) return teaching;
  }
  return null;
});

/// Enseignements d'une rubrique donnée, dans l'ordre du repository.
///
/// Les rubriques de l'accueil se découpent ici (et non dans le repository) :
/// le contrat de données reste une simple liste, la mise en rayon est une
/// affaire de présentation — même principe que [announcementsProvider].
List<Teaching> _byRubric(Ref ref, TeachingRubric rubric) =>
    List<Teaching>.unmodifiable(
      ref.watch(teachingsProvider).where((t) => t.rubric == rubric),
    );

/// Messages du dimanche (rubrique « Message du dimanche »).
final sundayTeachingsProvider = Provider<List<Teaching>>(
  (ref) => _byRubric(ref, TeachingRubric.dimanche),
);

/// Études bibliques (rubrique « Étude biblique »).
final bibleStudiesProvider = Provider<List<Teaching>>(
  (ref) => _byRubric(ref, TeachingRubric.etude),
);

/// Enregistrements centrés sur la prière (rubrique « Temps de prière »).
final prayerTeachingsProvider = Provider<List<Teaching>>(
  (ref) => _byRubric(ref, TeachingRubric.priere),
);

/// Section « Derniers enseignements » — **les plus récents, toutes rubriques
/// confondues**, à l'exclusion des cultes entiers.
///
/// Ce n'est plus une rubrique mais un **tri** : `libre` a été retiré du
/// référentiel serveur précisément parce qu'il déguisait un tri en espèce.
///
/// Le tri porte sur [Teaching.recordedAt], le jour du culte — et non sur la
/// date de parution. Un enseignement de dimanche dernier publié ce matin doit
/// se ranger à sa place dans l'histoire de l'église, pas en tête sous prétexte
/// qu'on vient de le mettre en ligne ; c'est la date que le membre reconnaît.
///
/// Les **cultes entiers** en sont exclus : ils durent des heures et
/// écraseraient une liste faite pour picorer. Ils restent atteignables par leur
/// propre rubrique et par la médiathèque.
///
/// Contrairement à la version précédente, cette liste **n'exclut plus** ce qui
/// est mis en avant plus haut : la déduplication reposait sur une rubrique
/// fourre-tout qui n'existe plus, et un enseignement peut légitimement être à
/// la fois récent et mis en avant.
final latestTeachingsProvider = Provider<List<Teaching>>((ref) {
  final teachings = ref
      .watch(teachingsProvider)
      .where((teaching) => !teaching.isFullService)
      .toList()
    ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  return List<Teaching>.unmodifiable(teachings);
});

/// Groupes communautaires.
final groupsProvider = Provider<List<CommunityGroup>>(
  (ref) => ref.watch(churchRepositoryProvider).groups(),
);

/// Requêtes de prière.
final prayersProvider = Provider<List<PrayerRequest>>(
  (ref) => ref.watch(churchRepositoryProvider).prayers(),
);

/// Notes spirituelles.
final notesProvider = Provider<List<SpiritualNote>>(
  (ref) => ref.watch(churchRepositoryProvider).notes(),
);

/// Messages de discussion d'un groupe (paramétré par le groupe ciblé).
final chatProvider = Provider.family<List<ChatMessage>, CommunityGroup>(
  (ref, group) => ref.watch(churchRepositoryProvider).chatFor(group),
);
