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
/// (#34), et les **annonces** avec #35 (`AnnouncementRepository`) : ce contrat
/// **rétrécit à chaque domaine branché**, jusqu'à disparaître.
abstract interface class ChurchRepository {
  List<CommunityGroup> groups();

  /// Les conversations du hub « Échanges » (groupes + messages privés mêlés,
  /// triées par récence).
  List<Conversation> conversations();

  /// Les groupes **à rejoindre** de la rangée de découverte.
  List<DiscoverGroup> groupsToJoin();

  List<PrayerRequest> prayers();
  List<SpiritualNote> notes();

  /// Messages d'une conversation donnée.
  List<ChatMessage> chatFor(Conversation conversation);
}

/// Implémentation en mémoire adossée aux [SampleData] (maquettes).
///
/// Sert de double pour le développement et les tests tant qu'aucun backend
/// n'est branché.
class InMemoryChurchRepository implements ChurchRepository {
  const InMemoryChurchRepository();

  @override
  List<CommunityGroup> groups() => SampleData.groups;

  @override
  List<Conversation> conversations() => SampleData.conversations;

  @override
  List<DiscoverGroup> groupsToJoin() => SampleData.groupsToJoin;

  @override
  List<PrayerRequest> prayers() => SampleData.prayers;

  @override
  List<SpiritualNote> notes() => SampleData.notes;

  @override
  List<ChatMessage> chatFor(Conversation conversation) => SampleData.chat;
}
