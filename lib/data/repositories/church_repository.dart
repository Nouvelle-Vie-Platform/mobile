import '../../models/models.dart';
import '../sample_data.dart';

/// Contrat d'accès aux données **encore fictives** de l'église.
///
/// Volontairement **synchrone** : ce qu'il sert n'existe qu'en mémoire. Les
/// domaines branchés sur le backend en **sortent** un par un, chacun dans son
/// repository dédié et asynchrone (`AuthRepository`, `BranchRepository`, et
/// bientôt `CalendarRepository`). Passer toute cette interface en `Future`
/// pour le premier domaine servi par HTTP casserait d'un coup les cinq autres
/// et tous leurs écrans, pour aucun gain.
///
/// L'agenda est déjà parti ([ChurchEvent], #16), la médiathèque aussi
/// ([Teaching], #30 → `MediathequeRepository`), les rassemblements ensuite
/// (#34), les **annonces** avec #35 (`AnnouncementRepository`) et la rubrique
/// **« Échanges »** avec #96 (`EchangesRepository`) : ce contrat **rétrécit à
/// chaque domaine branché**, jusqu'à disparaître.
///
/// ⚠️ **Il ne reste que deux méthodes, et c'est le dernier reste fictif de
/// l'application.** Les requêtes de prière et les notes — décision 10 du cadrage
/// de #96 : tout retirer, espace de prière compris, aurait été plus net d'un
/// `grep`, mais aurait **retiré une fonctionnalité aux membres** pour une raison
/// d'hygiène de code. La route `/prayers` reste donc servie, et reste fictive.
///
/// Le mur de prière existe côté serveur (`prayer_wall`, enregistré au registre de
/// synchronisation) : le branchement n'attend qu'une table locale, un DAO et un
/// repository. **Rien de neuf ne doit se brancher ici.**
abstract interface class ChurchRepository {
  List<PrayerRequest> prayers();
  List<SpiritualNote> notes();
}

/// Implémentation en mémoire adossée aux [SampleData] (maquettes).
///
/// ⚠️ **Elle était, jusqu'à #96, le seul double en mémoire câblé en production
/// sans condition** — tous les autres sont derrière `AppEnv.useBackend`. Elle y
/// servait quatre groupes, sept conversations et le même fil de cinq messages
/// pour **toutes** les discussions, sur une application par ailleurs branchée.
/// Ce qu'elle sert désormais ne ment plus à personne : deux domaines que le
/// serveur ne sert pas encore au mobile.
class InMemoryChurchRepository implements ChurchRepository {
  const InMemoryChurchRepository();

  @override
  List<PrayerRequest> prayers() => SampleData.prayers;

  @override
  List<SpiritualNote> notes() => SampleData.notes;
}
