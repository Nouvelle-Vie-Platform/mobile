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

/// Annonces de l'église.
final announcementsProvider = Provider<List<Announcement>>(
  (ref) => ref.watch(churchRepositoryProvider).announcements(),
);

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
