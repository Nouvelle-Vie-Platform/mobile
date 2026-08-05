import '../models/models.dart';

/// Instant passé, exprimé en UTC comme le ferait le backend.
DateTime _ago(Duration since) => DateTime.now().toUtc().subtract(since);

/// Instant futur, exprimé en UTC comme le ferait le backend.
DateTime _inFuture(Duration until) => DateTime.now().toUtc().add(until);

/// **Jour** d'enregistrement d'une fixture — sans heure, comme ce que le back
/// sert en `YYYY-MM-DD`. Ancré en UTC pour qu'aucun fuseau ne le déplace d'un
/// jour à l'affichage.
DateTime _day(int daysAgo) {
  final moment = DateTime.now().toUtc().subtract(Duration(days: daysAgo));
  return DateTime.utc(moment.year, moment.month, moment.day);
}

/// Fuseau de la branche de Lomé — UTC+0 toute l'année, sans heure d'été.
const String _lome = 'Africa/Lome';

/// Prochaine occurrence d'un jour de semaine à [hour], **en UTC**.
///
/// Lomé étant à UTC+0, l'heure murale togolaise *est* l'heure UTC : un
/// évènement à 15 h au temple se sert bien `15:00Z`.
DateTime _nextWeekdayAt(int weekday, int hour) {
  final now = DateTime.now().toUtc();
  final today = DateTime.utc(now.year, now.month, now.day, hour);
  final candidate = today.add(Duration(days: (weekday - today.weekday) % 7));
  return candidate.isAfter(now)
      ? candidate
      : candidate.add(const Duration(days: 7));
}

/// Prochain culte dominical (15 h à Lomé).
final DateTime _culte = _nextWeekdayAt(DateTime.sunday, 15);

/// Prochaine veillée de prière (vendredi 20 h à Lomé).
final DateTime _veillee = _nextWeekdayAt(DateTime.friday, 20);

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

  /// Agenda fictif — dates **relatives à maintenant** (une maquette figée en
  /// « Mai 2024 » afficherait un agenda périmé). `static final` : [DateTime]
  /// n'est pas constructible en constante.
  ///
  /// La fin se déduit du début (`+ durée`) et n'est **jamais** recalculée à
  /// part : un dimanche à 16 h, « prochain dimanche 15 h » bascule à la semaine
  /// suivante alors que « prochain dimanche 17 h » est encore aujourd'hui — la
  /// fin précéderait le début.
  static final List<ChurchEvent> events = [
    ChurchEvent(
      id: 'evt-culte-gloire',
      startsAt: _culte,
      endsAt: _culte.add(const Duration(hours: 2)),
      timezone: _lome,
      branchId: 1,
      title: const {'fr': 'Culte de Gloire', 'en': 'Glory Service'},
      place: 'Temple Central',
      category: const EventCategory(
        id: 1,
        label: {'fr': 'Culte', 'en': 'Service'},
        tone: 'culte',
      ),
    ),
    ChurchEvent(
      id: 'evt-veillee-priere',
      startsAt: _veillee,
      endsAt: _veillee.add(const Duration(hours: 4)),
      timezone: _lome,
      branchId: 1,
      title: const {'fr': 'Veillée de Prière', 'en': 'Prayer Vigil'},
      place: 'Temple Central',
      category: const EventCategory(
        id: 2,
        label: {'fr': 'Prière', 'en': 'Prayer'},
        tone: 'info',
      ),
    ),
  ];

  /// Référentiel fictif des **rubriques**, miroir de `teaching_types`.
  ///
  /// Il existe pour que le mode maquette (`AppEnv.useBackend` faux) fasse la
  /// même jointure que le magasin, et donc applique les mêmes règles de
  /// lecture : sans rubriques ici, la cascade de couleur et le repli de libellé
  /// ne seraient jamais exercés hors backend, et l'on découvrirait leurs bugs
  /// en production.
  ///
  /// Trois choix délibérés dans ce jeu :
  /// - `archives` est **masquée de l'accueil** (`visibleOnHome: false`) et n'a
  ///   **pas de couleur** : elle exerce à la fois la rubrique retirée de la
  ///   vitrine et le dernier maillon de la cascade (le bleu de marque) ;
  /// - `archives` n'a **pas de traduction éwé** : c'est le repli de `pick` qui
  ///   est mis à l'épreuve, pas seulement le chemin heureux ;
  /// - les trois [layout] possibles sont représentés — le ticket #32 compose
  ///   l'accueil avec, celui-ci se contente de les porter.
  static const List<TeachingType> teachingTypes = [
    TeachingType(
      id: 1,
      slug: 'dimanche',
      label: {
        'fr': 'Messages du dimanche',
        'en': 'Sunday messages',
        'ee': 'Kɔsiɖagbe nyawo',
      },
      color: 0xFF223B8C,
      position: 1,
      layout: 'hero',
    ),
    TeachingType(
      id: 2,
      slug: 'etude',
      label: {
        'fr': 'Études bibliques',
        'en': 'Bible studies',
        'ee': 'Biblia srɔ̃srɔ̃',
      },
      color: 0xFF7A5AF8,
      position: 2,
      layout: 'carousel',
    ),
    TeachingType(
      id: 3,
      slug: 'priere',
      label: {
        'fr': 'Moments de prière',
        'en': 'Prayer times',
        'ee': 'Gbedodoɖa ɣeyiɣiwo',
      },
      color: 0xFF1FA971,
      position: 3,
      layout: 'list',
    ),
    TeachingType(
      id: 4,
      slug: 'archives',
      label: {'fr': 'Archives', 'en': 'Archives'},
      position: 4,
      visibleOnHome: false,
      layout: 'list',
    ),
  ];

  /// Enseignements, du plus récent au plus ancien.
  ///
  /// Le [Teaching.teachingTypeId] désigne une rubrique de [teachingTypes] —
  /// un **entier nu**, comme sur le fil : rien n'oblige la cible à exister, et
  /// le dernier de la liste n'en porte aucune, exprès. Il vérifie que
  /// l'enseignement s'affiche quand même, sans rubrique et sans intervenant
  /// résolu.
  ///
  /// La [Teaching.color] est **brute** : `null` veut dire « hérite de ma
  /// rubrique », pas « pas de couleur ». Plusieurs enseignements la laissent
  /// nulle pour que la cascade soit visible en mode maquette.
  ///
  /// Les [Teaching.id] sont des **UUIDv7 écrits en dur, et ils doivent le
  /// rester** : la navigation ne passe plus l'objet mais son identifiant
  /// (`/teaching/:id`). Un identifiant régénéré à chaque lancement — un
  /// `Uuid().v7()` appelé ici, un index de liste — casserait tout lien déjà
  /// ouvert et rendrait l'écran de détail « contenu retiré » au moindre
  /// rechargement. Ordre des horodatages : décroissant, comme la liste.
  ///
  /// `final` et non `const` : les dates (`recordedAt`, `publishedAt`) ne sont
  /// pas constructibles en constante.
  static final List<Teaching> teachings = [
    // ── Messages du dimanche ────────────────────────────────────────────────
    Teaching(
        id: '0195cfbf-ac00-7a60-9eb6-46f7b38cf45a',
        title: 'Dieu a le dernier mot',
        recordedAt: _day(3),
        isFullService: true,
        publishedAt: _ago(const Duration(days: 3)),
        author: 'Pasteur Samuel',
        color: 0xFF223B8C,
        imageLandscapeUrl: 'https://picsum.photos/seed/dimanche/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/dimanche/384/635',
        description:
            'Là où les circonstances semblent avoir tranché, Dieu garde la '
            'parole finale sur nos vies, nos familles et nos projets.',
        teachingTypeId: 1),
    Teaching(
        id: '0195abb3-2800-7f50-924d-12ee32477961',
        title: 'Une maison bâtie sur le roc',
        recordedAt: _day(10),
        publishedAt: _ago(const Duration(days: 10)),
        author: 'Pasteur Mike',
        // Couleur nulle : hérite de celle de sa rubrique (`dimanche`).
        imageLandscapeUrl: 'https://picsum.photos/seed/roc/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/roc/384/635',
        description:
            'Ce qui tient debout dans la tempête n\'est pas ce qui brille, '
            'mais ce qui est fondé sur la Parole mise en pratique.',
        teachingTypeId: 1),
    Teaching(
        id: '019587a6-a400-710b-9048-8a20d30288e7',
        title: 'Le temps de la faveur',
        recordedAt: _day(17),
        publishedAt: _ago(const Duration(days: 17)),
        author: 'Pasteur Samuel',
        color: 0xFF1FA971,
        imageLandscapeUrl: 'https://picsum.photos/seed/faveur/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/faveur/384/635',
        description:
            'Il y a des saisons que Dieu fixe lui-même : reconnaître le temps '
            'de sa faveur, c\'est cesser de courir après ce qu\'Il donne.',
        teachingTypeId: 1),
    // ── Études bibliques ────────────────────────────────────────────────────
    Teaching(
        id: '0195639a-2000-7554-902f-d58a5f53f301',
        title: 'Romains : vivre par la grâce',
        recordedAt: _day(24),
        isFullService: true,
        publishedAt: _ago(const Duration(days: 24)),
        author: 'Pasteur Jonas',
        color: 0xFF7A5AF8,
        imageLandscapeUrl: 'https://picsum.photos/seed/romains/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/romains/384/635',
        description:
            'Première étape d\'un parcours dans l\'épître aux Romains : la '
            'justification par la foi, verset après verset.',
        teachingTypeId: 2),
    Teaching(
        id: '01953f8d-9c00-7d09-99c9-3f722eef070e',
        title: 'Les alliances de Dieu, pas à pas',
        recordedAt: _day(31),
        publishedAt: _ago(const Duration(days: 31)),
        author: 'Pasteur Mike',
        color: 0xFFE53935,
        imageLandscapeUrl: 'https://picsum.photos/seed/alliance/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/alliance/384/635',
        description:
            'D\'Abraham à la nouvelle alliance : comprendre le fil que Dieu '
            'tire d\'un bout à l\'autre de l\'Écriture.',
        teachingTypeId: 2),
    Teaching(
        id: '01951b81-1800-7e8e-8f59-d2437dbd48a3',
        title: 'Prier avec les Psaumes',
        recordedAt: _day(38),
        publishedAt: _ago(const Duration(days: 38)),
        author: 'Sœur Estelle',
        // Couleur nulle : hérite de celle de sa rubrique (`etude`).
        imageLandscapeUrl: 'https://picsum.photos/seed/psaumes/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/psaumes/384/635',
        description:
            'Les Psaumes mettent des mots sur ce que nous n\'osons pas dire : '
            'apprendre à en faire notre langue de prière.',
        teachingTypeId: 2),
    // ── Temps de prière ─────────────────────────────────────────────────────
    Teaching(
        id: '0194f774-9400-7124-aeb4-a337eaf5c04f',
        title: 'Veillée : le cri du matin',
        recordedAt: _day(45),
        publishedAt: _ago(const Duration(days: 45)),
        author: 'Pasteur Samuel',
        color: 0xFF1B2A6B,
        imageLandscapeUrl: 'https://picsum.photos/seed/veillee/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/veillee/384/635',
        description:
            'Une nuit entière portée devant Dieu : quelques mots d\'exhortation, '
            'puis la prière de l\'assemblée jusqu\'au lever du jour.',
        teachingTypeId: 3),
    Teaching(
        id: '0194d368-1000-792b-a9de-9c5d1427c9d4',
        title: 'Intercession pour la nation',
        recordedAt: _day(52),
        publishedAt: _ago(const Duration(days: 52)),
        author: 'Pasteur Jonas',
        color: 0xFF0F766E,
        imageLandscapeUrl: 'https://picsum.photos/seed/intercession/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/intercession/384/635',
        description:
            'Nous nous tenons sur la brèche pour le pays, les autorités et la '
            'paix de nos villes.',
        teachingTypeId: 3),
    Teaching(
        id: '0194af5b-8c00-7d6a-9b36-6afbc65a478b',
        title: 'Prière pour les familles',
        recordedAt: _day(59),
        publishedAt: _ago(const Duration(days: 59)),
        author: 'Sœur Estelle',
        color: 0xFF9333EA,
        imageLandscapeUrl: 'https://picsum.photos/seed/familles/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/familles/384/635',
        description:
            'Un temps de prière pour les foyers : les couples, les enfants et '
            'ceux qui portent seuls leur maison.',
        teachingTypeId: 3),
    // ── Hors rubrique ───────────────────────────────────────────────────────
    Teaching(
        id: '01948b4f-0800-7bd7-835f-7081a853c4bb',
        title: 'La puissance de la prière',
        recordedAt: _day(66),
        publishedAt: _ago(const Duration(days: 66)),
        author: 'Pasteur Samuel',
        color: 0xFF3B5BD0,
        imageLandscapeUrl: 'https://picsum.photos/seed/priere/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/priere/384/635',
        description:
            'La prière n\'est pas une formalité religieuse : c\'est un dialogue '
            'vivant avec Dieu qui transforme nos vies et nos circonstances.',
        teachingTypeId: 2),
    Teaching(
        id: '01946742-8400-7fe2-9661-d853031937a8',
        title: 'La foi qui déplace les montagnes',
        recordedAt: _day(73),
        publishedAt: _ago(const Duration(days: 73)),
        author: 'Pasteur Samuel',
        color: 0xFFE53935,
        imageLandscapeUrl: 'https://picsum.photos/seed/foi/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/foi/384/635',
        description:
            'La véritable foi nous connecte aux promesses de Dieu et permet de '
            'voir des résultats extraordinaires dans l\'impossible.',
        teachingTypeId: 3),
    Teaching(
        id: '01944336-0000-7f97-b43a-7a7fa48b2364',
        title: 'Marcher par l\'Esprit',
        recordedAt: _day(80),
        publishedAt: _ago(const Duration(days: 80)),
        author: 'Pasteur Mike',
        color: 0xFF1FA971,
        imageLandscapeUrl: 'https://picsum.photos/seed/esprit/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/esprit/384/635',
        description:
            'Apprendre à être conduit par l\'Esprit de Dieu au quotidien, dans '
            'nos décisions comme dans notre caractère.',
        teachingTypeId: 1),
    Teaching(
        id: '01941f29-7c00-740c-88cd-f0b19cc920f6',
        title: 'Le tour du père',
        recordedAt: _day(80),
        publishedAt: _ago(const Duration(days: 80)),
        author: 'Pasteur Jonas',
        // Ni couleur, ni rubrique : la cascade descend jusqu'au bleu de
        // marque, et l'écran doit rester lisible sans libellé de rubrique.
        imageLandscapeUrl: 'https://picsum.photos/seed/pere/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/pere/384/635',
        description:
            'Le cœur du Père céleste pour ses enfants : un amour qui restaure, '
            'relève et accueille sans condition.'),
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

  // Les branches ne sont **plus** des données fictives : elles viennent du
  // serveur (`GET /sync/branches`, voir `BranchRepository`). En garder une
  // copie ici, c'était un second référentiel à tenir à jour — et le risque
  // d'afficher des branches qui n'existent pas.

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
