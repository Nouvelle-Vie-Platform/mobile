import '../models/models.dart';

/// Données fictives reproduisant le contenu des maquettes.
abstract final class SampleData {
  static const List<Announcement> announcements = [
    Announcement(
      title: 'Convention annuelle 2024',
      body: 'Trois jours de communion et de prière du 14 au 16 juin au Temple '
          'Central. Inscriptions ouvertes à l\'accueil.',
      date: 'Il y a 2 heures',
      tag: 'Important',
    ),
    Announcement(
      title: 'Nouvelle chorale jeunesse',
      body: 'Les répétitions débutent ce samedi à 16h. Rejoignez-nous !',
      date: 'Hier',
      tag: 'Jeunesse',
    ),
    Announcement(
      title: 'Collecte de dons solidaires',
      body: 'Apportez vivres et vêtements pour les familles dans le besoin '
          'jusqu\'à la fin du mois.',
      date: 'Il y a 3 jours',
      tag: 'Solidarité',
    ),
  ];

  static const List<ChurchEvent> events = [
    ChurchEvent(
      title: 'Culte de Gloire',
      day: '26',
      month: 'Mai',
      time: '15:00 - 17:00',
      place: 'Temple Central',
      tag: 'Culte',
    ),
    ChurchEvent(
      title: 'Veillée de Prière',
      day: '31',
      month: 'Mai',
      time: '20:00 - 00:00',
      place: 'Temple Central',
      tag: 'Prière',
    ),
  ];

  static const List<Teaching> teachings = [
    Teaching(
        title: 'La puissance de la prière',
        author: 'Pasteur Samuel',
        duration: '23:45',
        seed: 0),
    Teaching(
        title: 'La foi qui déplace les montagnes',
        author: 'Pasteur Samuel',
        duration: '36:10',
        seed: 1),
    Teaching(
        title: 'Marcher par l\'Esprit',
        author: 'Pasteur Mike',
        duration: '31:45',
        seed: 2),
    Teaching(
        title: 'Le tour du père',
        author: 'Pasteur Jonas',
        duration: '28:12',
        seed: 3),
  ];

  static const List<CommunityGroup> groups = [
    CommunityGroup(
        name: 'Jeunesse Nouvelle Vie', members: 125, role: 'Responsable'),
    CommunityGroup(name: 'Couples Bénis', members: 80),
    CommunityGroup(name: 'Chorale Harmonie', members: 45),
    CommunityGroup(name: 'Femmes d\'Impact', members: 67),
  ];

  static const List<PrayerRequest> prayers = [
    PrayerRequest(
      title: 'Pour ma famille',
      body: 'Que Dieu protège ma famille et pourvoie à leurs besoins.',
      status: 'Confidentielle',
      prayingCount: 12,
      age: 'Il y a 3 jours',
      confidential: true,
    ),
    PrayerRequest(
      title: 'Pour mon emploi',
      body: 'Je demande la sagesse et des portes ouvertes.',
      status: 'Confiée',
      prayingCount: 8,
      age: 'Il y a 3 jours',
      confidential: false,
    ),
  ];

  static const List<SpiritualNote> notes = [
    SpiritualNote(
        title: 'La foi qui déplace les montagnes',
        preview: 'Dieu veut que nous ayons une foi vivante et agissante...'),
    SpiritualNote(
        title: 'Culte du 19 Mai 2024',
        preview: 'Points importants à retenir du culte.'),
    SpiritualNote(
        title: 'Marcher par l\'Esprit',
        preview: 'Notes personnelles sur le message.'),
  ];

  static const List<ChatMessage> chat = [
    ChatMessage(
        author: 'Système',
        text: 'Réunion ce samedi à 16h au temple. Soyez tous présents !',
        time: '10:30',
        mine: false,
        system: true),
    ChatMessage(
        author: 'Estelle',
        text: 'Gloire à Dieu ! 🙌',
        time: '10:32',
        mine: false),
    ChatMessage(
        author: 'Moi',
        text: 'N\'oublions pas d\'inviter nos amis.',
        time: '10:34',
        mine: true),
    ChatMessage(
        author: 'David', text: 'Alléluia 🙏', time: '10:36', mine: false),
    ChatMessage(
        author: 'Sarah', text: 'À samedi alors !', time: '10:38', mine: false),
  ];
}
