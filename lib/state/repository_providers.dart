import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/church_repository.dart';
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
final eventsProvider = Provider<List<ChurchEvent>>(
  (ref) => ref.watch(churchRepositoryProvider).events(),
);

/// Enseignements / médiathèque.
final teachingsProvider = Provider<List<Teaching>>(
  (ref) => ref.watch(churchRepositoryProvider).teachings(),
);

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
