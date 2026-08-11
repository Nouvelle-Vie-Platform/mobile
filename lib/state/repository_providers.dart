import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/church_repository.dart';
import '../data/sample_data.dart';
import '../models/models.dart';

/// Fournit l'implémentation courante du [ChurchRepository].
///
/// **Il rétrécit, et c'est voulu.** Son contrat est synchrone : chaque domaine
/// que le back se met à servir en **sort** vers son propre repository
/// asynchrone (`AuthRepository`, `BranchRepository`, `CalendarRepository`,
/// `MediathequeRepository`, `GatheringRepository`, et désormais
/// `AnnouncementRepository`). Ce qui reste ici n'est que ce qui est encore
/// fictif : groupes, requêtes de prière, notes et discussions.
final churchRepositoryProvider = Provider<ChurchRepository>(
  (ref) => const InMemoryChurchRepository(),
);

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
