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
/// L'agenda est déjà parti : [ChurchEvent] ne se lit plus ici (cf. #16).
abstract interface class ChurchRepository {
  List<Announcement> announcements();
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
  List<Announcement> announcements() => SampleData.announcements;

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
