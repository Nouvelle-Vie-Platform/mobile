import '../models/models.dart';

/// Instant passé, exprimé en UTC comme le ferait le backend.
DateTime _ago(Duration since) => DateTime.now().toUtc().subtract(since);

/// Instant futur, exprimé en UTC comme le ferait le backend.
DateTime _inFuture(Duration until) => DateTime.now().toUtc().add(until);

/// Forme d'onde fictive « précalculée par le back » (valeurs 0–100).
const List<int> _waveformExhortation = [
  12, 20, 34, 48, 61, 55, 40, 33, 47, 66, //
  78, 84, 72, 58, 44, 30, 22, 29, 41, 57,
  70, 82, 91, 76, 63, 49, 36, 25, 18, 14,
  22, 31,
];

/// Données fictives reproduisant le contenu des maquettes.
abstract final class SampleData {
  /// Statuts de l'onglet « Annonces ».
  ///
  /// `static final` (et non `const`) : les [DateTime] sont calculés au premier
  /// accès pour que l'horodatage relatif reste réaliste.
  ///
  /// Le jeu couvre toutes les formes attendues : texte seul, texte long,
  /// vocal seul, vocal + texte, vidéo, image seule, expiration (passée et à
  /// venir) et statut épinglé.
  static final List<Announcement> announcements = [
    // Épinglé + bouton d'action.
    Announcement(
      id: 'veillee-priere',
      publishedAt: _ago(const Duration(minutes: 45)),
      title: 'Veillée de prière',
      body: 'Vendredi de 20h à minuit au Temple Central. Venons chercher la '
          'face de Dieu ensemble.',
      author: 'Pasteur Samuel',
      tag: 'Prière',
      isPinned: true,
      backgroundColor: 0xFF223B8C,
      actionLabel: 'Voir l\'agenda',
      actionRoute: 'agenda',
    ),
    // Texte seul, très récent.
    Announcement(
      id: 'mot-du-matin',
      publishedAt: _ago(const Duration(minutes: 7)),
      body: 'Ce que Dieu a promis, Il est assez puissant pour l\'accomplir.',
      author: 'Pasteur Samuel',
      tag: 'Parole',
      backgroundColor: 0xFF3B5BD0,
    ),
    // Texte long : déborde l'écran, doit défiler.
    Announcement(
      id: 'temoignage-famille',
      publishedAt: _ago(const Duration(hours: 3)),
      title: 'Un témoignage qui fortifie',
      body:
          'La famille Adjovi tient à rendre grâce à Dieu devant toute l\'assemblée. '
          'Après dix-huit mois de recherche d\'emploi, de portes fermées et de '
          'soirées passées à prier avec le groupe de maison du quartier, une '
          'proposition est arrivée là où personne ne l\'attendait.\n\n'
          'Ils rappellent que la communauté ne les a jamais laissés seuls : '
          'visites, repas partagés, appels le soir, jeûnes du mercredi. Ce que '
          'l\'Église a semé dans la discrétion, Dieu l\'a fait lever au grand '
          'jour.\n\n'
          'Un temps d\'action de grâces leur sera consacré dimanche prochain, '
          'à la fin du culte. Venez nombreux les entourer, et apportez avec '
          'vous les sujets que vous portez depuis trop longtemps : le même Dieu '
          'répond encore aujourd\'hui.',
      author: 'Cellule d\'accompagnement',
      tag: 'Témoignage',
      backgroundColor: 0xFF1FA971,
    ),
    // Vocal seul, waveform fournie par le back.
    Announcement(
      id: 'exhortation-vocale',
      publishedAt: _ago(const Duration(hours: 5)),
      author: 'Pasteur Mike',
      tag: 'Exhortation',
      audio: const StatusAudio(
        url: 'https://media.maisondumiracle.org/statuts/exhortation-mike.m4a',
        durationMs: 42000,
        waveform: _waveformExhortation,
      ),
      backgroundColor: 0xFF7A5AF8,
    ),
    // Vocal + texte, waveform absente → repli déterministe côté UI.
    Announcement(
      id: 'chorale-repetition',
      publishedAt: _ago(const Duration(hours: 26)),
      title: 'Chorale Harmonie',
      body: 'Écoutez le passage que nous répétons samedi à 16h.',
      author: 'Sœur Estelle',
      tag: 'Jeunesse',
      audio: const StatusAudio(
        url: 'https://media.maisondumiracle.org/statuts/chorale-extrait.m4a',
        durationMs: 28000,
      ),
      backgroundColor: 0xFFE53935,
    ),
    // Vidéo (poster requis).
    Announcement(
      id: 'convention-teaser',
      publishedAt: _ago(const Duration(days: 2)),
      title: 'Convention annuelle',
      body: 'Trois jours de communion et de prière au Temple Central.',
      author: 'Maison du Miracle',
      tag: 'Important',
      video: const StatusVideo(
        url: 'https://media.maisondumiracle.org/statuts/convention.mp4',
        poster: 'https://picsum.photos/seed/convention/800/1400',
        durationMs: 24000,
      ),
    ),
    // Expiration à venir : reste visible jusqu'à la fin de la collecte.
    Announcement(
      id: 'collecte-solidaire',
      publishedAt: _ago(const Duration(hours: 9)),
      title: 'Collecte de dons solidaires',
      body: 'Apportez vivres et vêtements pour les familles dans le besoin.',
      author: 'Diaconat',
      tag: 'Solidarité',
      backgroundImage: 'https://picsum.photos/seed/solidarite/800/1400',
      expiresAt: _inFuture(const Duration(days: 2)),
      actionLabel: 'Faire un don',
      actionRoute: 'donations',
    ),
    // Image seule (ni titre ni corps) : l'affiche parle d'elle-même.
    Announcement(
      id: 'affiche-jeunesse',
      publishedAt: _ago(const Duration(days: 4)),
      author: 'Jeunesse Nouvelle Vie',
      tag: 'Affiche',
      backgroundImage: 'https://picsum.photos/seed/jeunesse/800/1400',
      durationMs: 6000,
    ),
    // Expiration dépassée : filtré par le provider, jamais affiché.
    Announcement(
      id: 'repetition-annulee',
      publishedAt: _ago(const Duration(days: 3)),
      title: 'Répétition annulée',
      body: 'La répétition d\'hier soir est reportée. Merci de votre '
          'compréhension.',
      author: 'Chorale Harmonie',
      tag: 'Info',
      expiresAt: _ago(const Duration(hours: 2)),
    ),
    // Plus d'une semaine : bascule sur une date courte localisée.
    Announcement(
      id: 'retraite-spirituelle',
      publishedAt: _ago(const Duration(days: 12)),
      title: 'Retraite spirituelle',
      body: 'Retour en images sur trois jours de jeûne et de louange.',
      author: 'Maison du Miracle',
      tag: 'Médias',
      backgroundColor: 0xFF223B8C,
      actionLabel: 'Voir la médiathèque',
      actionRoute: 'media',
    ),
  ];

  static const List<ChurchEvent> events = [
    ChurchEvent(
      title: 'Culte de Gloire',
      weekday: 'Dimanche',
      day: '26',
      month: 'Mai',
      time: '15:00 - 17:00',
      place: 'Temple Central',
      tag: 'Culte',
    ),
    ChurchEvent(
      title: 'Veillée de Prière',
      weekday: 'Vendredi',
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
        seed: 0,
        color: 0xFF3B5BD0,
        image: 'https://picsum.photos/seed/priere/600/800',
        description:
            'La prière n\'est pas une formalité religieuse : c\'est un dialogue '
            'vivant avec Dieu qui transforme nos vies et nos circonstances.',
        verse: 'Jacques 5:16'),
    Teaching(
        title: 'La foi qui déplace les montagnes',
        author: 'Pasteur Samuel',
        duration: '36:10',
        seed: 1,
        color: 0xFFE53935,
        image: 'https://picsum.photos/seed/foi/600/800',
        description:
            'La véritable foi nous connecte aux promesses de Dieu et permet de '
            'voir des résultats extraordinaires dans l\'impossible.',
        verse: 'Matthieu 17:20'),
    Teaching(
        title: 'Marcher par l\'Esprit',
        author: 'Pasteur Mike',
        duration: '31:45',
        seed: 2,
        color: 0xFF1FA971,
        image: 'https://picsum.photos/seed/esprit/600/800',
        description:
            'Apprendre à être conduit par l\'Esprit de Dieu au quotidien, dans '
            'nos décisions comme dans notre caractère.',
        verse: 'Galates 5:25'),
    Teaching(
        title: 'Le tour du père',
        author: 'Pasteur Jonas',
        duration: '28:12',
        seed: 3,
        color: 0xFF7A5AF8,
        image: 'https://picsum.photos/seed/pere/600/800',
        description:
            'Le cœur du Père céleste pour ses enfants : un amour qui restaure, '
            'relève et accueille sans condition.',
        verse: 'Luc 15:20'),
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

  /// Branches locales de l'église (liste statique en phase mock ; remplacée
  /// par `GET /branches` en phase backend).
  static const List<Branch> branches = [
    Branch(id: 'lome', name: 'Église Mère – Lomé', city: 'Lomé'),
    Branch(id: 'agoe', name: 'Bethel – Agoè', city: 'Agoè'),
    Branch(id: 'kara', name: 'Béthesda – Kara', city: 'Kara'),
    Branch(id: 'paris', name: 'Diaspora – Paris', city: 'Paris'),
  ];

  /// Identifiants « déjà connus » : le mock renvoie `isNewUser: false` pour
  /// ceux-ci (→ accueil direct). Emails en minuscules.
  static const List<String> knownIdentifiers = [
    '+22890123456',
    'jean.kossi@email.com',
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
