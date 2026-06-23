import '../../models/models.dart';
import '../sample_data.dart';

/// Contrat d'accès aux données de l'église.
///
/// Les écrans ne dépendent que de cette abstraction : pour brancher un vrai
/// backend (Firebase, API REST…), il suffira de fournir une autre
/// implémentation de [ChurchRepository] via le provider, sans toucher l'UI.
abstract interface class ChurchRepository {
  List<ChurchEvent> events();
  List<Teaching> teachings();
  List<CommunityGroup> groups();
  List<PrayerRequest> prayers();
  List<SpiritualNote> notes();

  /// Messages de la discussion d'un groupe donné.
  List<ChatMessage> chatFor(CommunityGroup group);
}

/// Implémentation en mémoire adossée aux [SampleData] (maquettes).
///
/// Sert de double pour le développement et les tests tant qu'aucun backend
/// n'est branché.
class InMemoryChurchRepository implements ChurchRepository {
  const InMemoryChurchRepository();

  @override
  List<ChurchEvent> events() => SampleData.events;

  @override
  List<Teaching> teachings() => SampleData.teachings;

  @override
  List<CommunityGroup> groups() => SampleData.groups;

  @override
  List<PrayerRequest> prayers() => SampleData.prayers;

  @override
  List<SpiritualNote> notes() => SampleData.notes;

  @override
  List<ChatMessage> chatFor(CommunityGroup group) => SampleData.chat;
}
