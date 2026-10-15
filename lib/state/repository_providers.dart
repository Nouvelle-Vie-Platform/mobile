import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/church_repository.dart';
import '../data/sample_data.dart';
import '../models/models.dart';

/// Fournit l'implémentation courante du [ChurchRepository].
///
/// **Il rétrécit, et c'est voulu.** Son contrat est synchrone : chaque domaine
/// que le back se met à servir en **sort** vers son propre repository
/// asynchrone (`AuthRepository`, `BranchRepository`, `CalendarRepository`,
/// `MediathequeRepository`, `GatheringRepository`, `AnnouncementRepository`, et
/// désormais `EchangesRepository` — #96 lui a pris les groupes, les conversations
/// et les discussions). Ce qui reste ici est **le dernier reste fictif de
/// l'application** : les requêtes de prière (les notes sont parties avec #190).
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

/// Requêtes de prière.
///
/// ⚠️ **Fictif, et le dernier à l'être** — décision 10 du cadrage de #96 :
/// `/prayers` garde sa route et son fictif, parce que tout retirer aurait retiré
/// une fonctionnalité aux membres pour une raison d'hygiène de code. Voir
/// `SampleData.prayers`, et ne rien brancher de neuf dessus.
final prayersProvider = Provider<List<PrayerRequest>>(
  (ref) => ref.watch(churchRepositoryProvider).prayers(),
);
