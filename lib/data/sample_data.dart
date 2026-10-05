import '../models/announcement_view.dart';
import '../models/legal_document_view.dart';
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

/// Les trois fonds de statut de la maquette, sous la **forme servie** par le
/// référentiel `status_backgrounds` : trois arrêts de dégradé et une encre, tous
/// dérivés côté serveur (ADR-0030). Le client les lit, il ne les recalcule pas.
final StatusBackdrop _brandBackdrop = StatusBackdrop.read(
  baseColor: '#223B8C',
  topColor: '#2E4CAE',
  bottomColor: '#16265C',
  ink: 'light',
)!;

final StatusBackdrop _deepBlueBackdrop = StatusBackdrop.read(
  baseColor: '#3B5BD0',
  topColor: '#5474E6',
  bottomColor: '#26409B',
  ink: 'light',
)!;

final StatusBackdrop _tealBackdrop = StatusBackdrop.read(
  baseColor: '#0F6E5C',
  topColor: '#178A74',
  bottomColor: '#0A4E41',
  ink: 'light',
)!;

/// Données fictives reproduisant le contenu des maquettes.
///
/// **Sa place, depuis #33 : les tests, les captures d'écran et le mode
/// maquette — plus le chemin applicatif.** Aucun écran ni widget ne la lit
/// (`grep SampleData lib/screens lib/widgets` doit rester vide) : la
/// médiathèque est peinte par le **magasin local**, que la synchronisation
/// remplit, et `SampleData.teachings` n'est plus servi que par le double en
/// mémoire de `MediathequeRepository`, lui-même choisi par
/// `AppEnv.useBackend`.
///
/// Elle ne disparaît pas pour autant, et ce n'est pas un compromis : le double
/// en mémoire doit avoir de quoi exercer **les mêmes règles de lecture** que le
/// magasin (cascade de couleur, repli de langue, jointure tolérante), et un
/// jeu de données écrit à la main est le seul moyen d'en garder les cas
/// limites lisibles — une rubrique absente, une couleur nulle, un
/// enseignement sans rubrique.
///
/// Ce qu'elle ne doit **pas** contenir : un champ que le serveur ne sert pas.
/// Trois en sont sortis avec #33 (`duration`, `verse`, `seed`, cf. `Teaching`)
/// — une fixture plus riche que la source fabrique des écrans qui marchent en
/// maquette et se vident en production.
abstract final class SampleData {
  /// Statuts de l'onglet « Annonces ».
  ///
  /// `static final` (et non `const`) : les [DateTime] sont calculés au premier
  /// accès pour que l'horodatage relatif reste réaliste.
  ///
  /// Les valeurs passent par [AnnouncementView.resolve] **sous leur forme
  /// serveur** — deux colonnes de nom séparées, des couleurs en `#RRGGBB`, une
  /// encre en chaîne : le double en mémoire doit exercer exactement les règles
  /// de lecture du magasin, sinon un bug de repli d'en-tête ou d'URL resterait
  /// invisible jusqu'à la production.
  ///
  /// Le jeu couvre les cas limites qui comptent : un statut épinglé, un statut
  /// sans titre, un texte long qui déborde, un fond image, un **fond absent**
  /// (teinte dérivée du hash de l'identifiant), un **compte absent du magasin**
  /// (en-tête qui ne se rend pas), une expiration à venir et une expiration
  /// dépassée.
  ///
  /// Ce qu'il ne contient **pas** : ni durée d'affichage ni bouton d'action — le
  /// serveur n'en sert aucun, et une fixture plus riche que la source fabrique
  /// des écrans qui marchent en maquette et se vident en production (#33). Ni
  /// piste audio ni vidéo non plus, alors que le serveur en sert depuis #130 :
  /// un média de statut est une playlist HLS **transcodée**, et une URL
  /// inventée ne jouerait rien — le lecteur réel retomberait sur l'horloge.
  static final List<AnnouncementView> announcements = [
    // Épinglé, fond de marque.
    AnnouncementView.resolve(
      id: 'veillee-priere',
      publishedAt: _ago(const Duration(minutes: 45)),
      title: 'Veillée de prière',
      body: 'Vendredi de 20h à minuit au Temple Central. Venons chercher la '
          'face de Dieu ensemble.',
      accountName: 'Maison du Miracle — Temple Central',
      accountShortName: 'Maison du Miracle',
      isPinned: true,
      backdrop: _brandBackdrop,
    ),
    // Sans titre : bloc de texte centré façon WhatsApp.
    AnnouncementView.resolve(
      id: 'mot-du-matin',
      publishedAt: _ago(const Duration(minutes: 7)),
      body: 'Ce que Dieu a promis, Il est assez puissant pour l\'accomplir.',
      accountName: 'Maison du Miracle — Temple Central',
      accountShortName: 'Maison du Miracle',
      backdrop: _deepBlueBackdrop,
    ),
    // Texte long : déborde l'écran, doit défiler.
    AnnouncementView.resolve(
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
      accountName: 'Cellule d\'accompagnement',
      backdrop: _tealBackdrop,
    ),
    // **Aucun fond servi** : le rendu retombe sur la teinte dérivée du hash de
    // l'identifiant. Le repli doit être exercé en maquette, pas seulement en
    // test — c'est ce que verra un fidèle dont le référentiel des fonds n'est
    // pas encore arrivé.
    AnnouncementView.resolve(
      id: 'chorale-repetition',
      publishedAt: _ago(const Duration(hours: 26)),
      title: 'Chorale Harmonie',
      body: 'Répétition samedi à 16h, salle du fond. Merci d\'être à l\'heure.',
      accountName: 'Chorale Harmonie',
    ),
    // **Compte absent du magasin** : l'en-tête ne se rend pas, et le statut
    // s'affiche quand même. Jamais de « Compte inconnu ».
    AnnouncementView.resolve(
      id: 'annonce-sans-compte',
      publishedAt: _ago(const Duration(hours: 20)),
      body: 'Le culte de dimanche débutera à 14h30, exceptionnellement.',
      backdrop: _brandBackdrop,
    ),
    // Fond image + expiration à venir : reste visible jusqu'à la fin de la
    // collecte.
    AnnouncementView.resolve(
      id: 'collecte-solidaire',
      publishedAt: _ago(const Duration(hours: 9)),
      title: 'Collecte de dons solidaires',
      body: 'Apportez vivres et vêtements pour les familles dans le besoin.',
      accountName: 'Diaconat',
      backgroundImageUrl: 'https://picsum.photos/seed/solidarite/800/1400',
      expiresAt: _inFuture(const Duration(days: 2)),
    ),
    // Image seule (ni titre ni corps) : l'affiche parle d'elle-même.
    AnnouncementView.resolve(
      id: 'affiche-jeunesse',
      publishedAt: _ago(const Duration(days: 4)),
      accountName: 'Jeunesse Nouvelle Vie',
      backgroundImageUrl: 'https://picsum.photos/seed/jeunesse/800/1400',
    ),
    // **Expiration dépassée** : filtrée par le provider, jamais affichée. Le
    // serveur, lui, continue de la servir — c'est au client de la retirer.
    AnnouncementView.resolve(
      id: 'repetition-annulee',
      publishedAt: _ago(const Duration(days: 3)),
      title: 'Répétition annulée',
      body: 'La répétition d\'hier soir est reportée. Merci de votre '
          'compréhension.',
      accountName: 'Chorale Harmonie',
      expiresAt: _ago(const Duration(hours: 2)),
    ),
    // Plus d'une semaine : bascule sur une date courte localisée.
    AnnouncementView.resolve(
      id: 'retraite-spirituelle',
      publishedAt: _ago(const Duration(days: 12)),
      title: 'Retraite spirituelle',
      body: 'Retour en images sur trois jours de jeûne et de louange.',
      accountName: 'Maison du Miracle — Temple Central',
      accountShortName: 'Maison du Miracle',
      backdrop: _brandBackdrop,
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

  /// **Rubriques de rassemblement** — le référentiel `gathering_types`, la
  /// seconde famille de la médiathèque (issue #34).
  ///
  /// Elles réutilisent [TeachingType] comme forme de fixture, et c'est
  /// délibéré : ces modèles de maquette ne sont jamais rendus à l'écran — le
  /// modèle de lecture (`GatheringSectionView`) s'interpose — et le serveur
  /// lui-même range les deux familles dans **une seule table**, discriminée par
  /// une colonne qui ne voyage pas. Les dédoubler aurait doublé la surface de la
  /// maquette pour zéro différence de comportement.
  ///
  /// Les identifiants **recouvrent exprès** ceux de [teachingTypes] : les deux
  /// référentiels sont deux collections distinctes, rien ne garantit que leurs
  /// SERIAL soient disjoints, et un double qui l'aurait supposé aurait masqué le
  /// jour où une jointure se trompe de table.
  static const List<TeachingType> gatheringTypes = [
    TeachingType(
      id: 1,
      slug: 'concerts',
      label: {'fr': 'Concerts', 'en': 'Concerts', 'ee': 'Hadzidziwo'},
      color: 0xFF0F6E5C,
      position: 1,
      layout: 'hero',
    ),
    TeachingType(
      id: 2,
      slug: 'conventions',
      label: {'fr': 'Conventions', 'en': 'Conventions', 'ee': 'Takpekpewo'},
      // Couleur nulle : la cascade descend jusqu'au bleu de marque.
      position: 2,
      layout: 'carousel',
    ),
    TeachingType(
      id: 5,
      slug: 'croisades',
      label: {'fr': 'Croisades', 'en': 'Crusades'},
      color: 0xFFB45309,
      position: 3,
      visibleOnHome: false,
      layout: 'list',
    ),
  ];

  /// **Rassemblements**, du plus récent au plus ancien.
  ///
  /// Mêmes partis pris que [teachings] : identifiants UUIDv7 **écrits en dur**
  /// (la navigation porte l'identifiant, un identifiant régénéré casserait tout
  /// lien déjà ouvert), couleur **brute** (`null` = « hérite de ma rubrique »),
  /// et un dernier élément **sans rubrique ni couleur** pour que le cas
  /// « rassemblement sans rubrique » soit visible en mode maquette.
  static final List<Teaching> gatherings = [
    Teaching(
        id: '019f3a10-1c00-7a11-9c01-2b1f8d4e0001',
        title: 'Nuit de gloire — concert de louange',
        recordedAt: _day(6),
        publishedAt: _ago(const Duration(days: 6)),
        author: 'Chorale Harmonie',
        color: 0xFF0F6E5C,
        imageLandscapeUrl: 'https://picsum.photos/seed/gloire/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/gloire/384/635',
        description:
            'Une soirée entière portée par la louange : l\'assemblée, la '
            'chorale et les musiciens, jusque tard dans la nuit.',
        teachingTypeId: 1),
    Teaching(
        id: '019f3a10-1c00-7a11-9c01-2b1f8d4e0002',
        title: 'Adoration sans fin',
        recordedAt: _day(20),
        publishedAt: _ago(const Duration(days: 20)),
        author: 'Chorale Harmonie',
        // Couleur nulle : hérite de celle de sa rubrique (`concerts`).
        imageLandscapeUrl: 'https://picsum.photos/seed/adoration/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/adoration/384/635',
        description:
            'Deux heures d\'adoration continue, enregistrées au temple '
            'central.',
        teachingTypeId: 1),
    Teaching(
        id: '019f3a10-1c00-7a11-9c01-2b1f8d4e0003',
        title: 'Convention nationale 2026 — ouverture',
        recordedAt: _day(34),
        publishedAt: _ago(const Duration(days: 34)),
        author: 'Pasteur Samuel',
        imageLandscapeUrl: 'https://picsum.photos/seed/convention/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/convention/384/635',
        description:
            'La séance d\'ouverture de la convention : accueil des délégations '
            'et message d\'orientation pour l\'année.',
        teachingTypeId: 2),
    Teaching(
        id: '019f3a10-1c00-7a11-9c01-2b1f8d4e0004',
        title: 'Forum des jeunes — sortir du bruit',
        recordedAt: _day(48),
        publishedAt: _ago(const Duration(days: 48)),
        author: 'Pasteur Mike',
        // Ni couleur, ni rubrique : la cascade descend jusqu'au bleu de
        // marque, et l'écran doit rester lisible sans libellé de rubrique.
        imageLandscapeUrl: 'https://picsum.photos/seed/forum/1024/602',
        imagePortraitUrl: 'https://picsum.photos/seed/forum/384/635',
        description:
            'Une journée avec les jeunes de l\'église : témoignages, ateliers '
            'et prière.'),
  ];

  // ⚠️ **Il n'y a plus ici ni groupe, ni conversation, ni fil de discussion**
  // (#96). `groups`, `conversations`, `groupsToJoin` et `chat` ont été retirés :
  // la rubrique « Échanges » est peinte par le **magasin local**, que la
  // synchronisation remplit depuis cinq collections répliquées — `profiles`,
  // `groups`, `group_members`, `group_join_requests`, `group_messages`.
  //
  // Ce n'était pas du confort d'hygiène. `InMemoryChurchRepository` était le
  // **seul** double en mémoire câblé en production **sans condition** — tous les
  // autres sont derrière `AppEnv.useBackend` —, et il servait le même fil de cinq
  // messages pour **toutes** les conversations. Une application branchée montrait
  // donc quatre groupes qui n'existaient pas.
  //
  // Les fixtures de ces cinq collections vivent désormais là où se vérifie leur
  // forme : `test/helpers/sync_fixtures.dart`, relevée sur le code du serveur.

  /// **Les requêtes de prière — LE DERNIER RESTE FICTIF DE L'APPLICATION.**
  ///
  /// Avec [notes], c'est tout ce qui subsiste de `ChurchRepository`, et c'est une
  /// décision explicite du cadrage de #96 (décision 10) : « on retire ce qui ne
  /// peut pas être vrai, on garde ce qui le deviendra ». La route `/prayers` reste
  /// servie et reste fictive — tout retirer aurait été plus net d'un `grep`, mais
  /// aurait **retiré une fonctionnalité aux membres** pour une raison d'hygiène de
  /// code.
  ///
  /// Le mur de prière existe côté serveur (`prayer_wall`, `partition: 'branch'`,
  /// enregistré au registre de synchronisation) : il n'y a donc rien à inventer le
  /// jour où on le branchera, seulement une table locale, un DAO et un repository
  /// — le chemin qu'#96 vient de parcourir pour Échanges.
  ///
  /// ⚠️ **Rien de neuf ne doit s'y brancher.** Un écran adossé à cette fixture est
  /// un écran qui se videra en production.
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

  /// Les **documents légaux** du mode maquette, sous la forme **servie** :
  /// sections brutes, cartes de traduction entières, corps en Markdown
  /// restreint.
  ///
  /// Deux d'entre eux sont incomplets à dessein. `privacy` n'a qu'une section
  /// sur deux traduite en éwé : c'est ce qui rend **visible en mode maquette**
  /// la règle du repli en bloc — le document sort intégralement en français, et
  /// non « majoritairement en éwé » (ADR-0035). `about` n'a pas de
  /// `lastMandatoryVersion` : accepter une présentation n'a pas de sens, et le
  /// genre n'entre jamais dans la barrière.
  static final List<LegalDocument> legalDocuments = [
    LegalDocument(
      kind: LegalDocumentKind.terms,
      version: 3,
      lastMandatoryVersion: 3,
      publishedAt: DateTime.utc(2026, 3, 9, 9),
      updatedAt: DateTime.utc(2026, 3, 9, 9),
      sections: const [
        LegalSection(
          key: 'objet',
          heading: {'fr': 'Objet', 'en': 'Purpose', 'ee': 'Taɖodzinu'},
          body: {
            'fr': 'L\'application est éditée par l\'**Église Évangélique '
                'Nouvelle Vie – Maison du Miracle**. Elle donne accès aux '
                'messages, à l\'agenda et aux annonces de l\'église.',
            'en': 'This app is published by **Église Évangélique Nouvelle Vie '
                '– Maison du Miracle**.',
            'ee': 'Sɔlemeha **Église Évangélique Nouvelle Vie – Maison du '
                'Miracle** ye tsɔ dɔwɔna sia ɖo anyi.',
          },
        ),
        LegalSection(
          key: 'compte',
          heading: {
            'fr': 'Votre compte',
            'en': 'Your account',
            'ee': 'Wò akɔnta'
          },
          body: {
            'fr': 'Vous vous engagez à :\n'
                '- fournir des informations exactes\n'
                '- garder votre code de connexion pour vous',
            'en': 'You agree to:\n'
                '- provide accurate information\n'
                '- keep your sign-in code to yourself',
            'ee': 'Èlɔ̃ be :\n'
                '- nàna nyatakaka siwo le eteƒe\n'
                '- nàdzra wò ŋkɔŋlɔdzesi ɖo na ɖokuiwò',
          },
        ),
        LegalSection(
          key: 'contact',
          heading: {'fr': 'Contact', 'en': 'Contact', 'ee': 'Kadodo'},
          body: {
            'fr': 'Écrivez à '
                '[contact@nouvelle-vie.tg](mailto:contact@nouvelle-vie.tg).',
            'en': 'Write to '
                '[contact@nouvelle-vie.tg](mailto:contact@nouvelle-vie.tg).',
            'ee': 'Ŋlɔ na '
                '[contact@nouvelle-vie.tg](mailto:contact@nouvelle-vie.tg).',
          },
        ),
      ],
    ),
    LegalDocument(
      kind: LegalDocumentKind.privacy,
      version: 2,
      lastMandatoryVersion: 2,
      publishedAt: DateTime.utc(2026, 2, 14, 9),
      updatedAt: DateTime.utc(2026, 2, 14, 9),
      sections: const [
        LegalSection(
          key: 'donnees',
          heading: {
            'fr': 'Vos données',
            'en': 'Your data',
            'ee': 'Wò nyatakakawo',
          },
          body: {
            'fr': 'Nous collectons :\n'
                '- votre nom\n'
                '- votre numéro de téléphone ou votre adresse e-mail\n'
                '- votre branche de rattachement',
            'en': 'We collect:\n'
                '- your name\n'
                '- your phone number or e-mail address\n'
                '- your home branch',
            'ee': 'Míeƒoa nu siawo nu ƒu :\n'
                '- wò ŋkɔ\n'
                '- wò kaƒomɔ ƒe xexlẽdzesi alo wò e-mail\n'
                '- sɔleme si me nèle',
          },
        ),
        // **Pas de traduction en éwé** : une seule absence, et tout le document
        // bascule en français. Le mode maquette exerce ainsi la règle.
        LegalSection(
          key: 'conservation',
          heading: {'fr': 'Conservation', 'en': 'Retention'},
          body: {
            'fr':
                'Vos données sont conservées *trois ans* après votre dernière '
                    'connexion, puis supprimées.',
            'en':
                'Your data is kept for *three years* after your last sign-in, '
                    'then deleted.',
          },
        ),
      ],
    ),
    LegalDocument(
      kind: LegalDocumentKind.about,
      version: 1,
      publishedAt: DateTime.utc(2026, 1, 4, 9),
      updatedAt: DateTime.utc(2026, 1, 4, 9),
      sections: const [
        LegalSection(
          key: 'presentation',
          heading: {
            'fr': 'Notre église',
            'en': 'Our church',
            'ee': 'Míaƒe sɔleme',
          },
          body: {
            'fr': 'L\'Église Évangélique Nouvelle Vie – Maison du Miracle '
                'accueille chaque dimanche à 15 h au temple central de Lomé.',
            'en':
                'Église Évangélique Nouvelle Vie – Maison du Miracle welcomes '
                    'you every Sunday at 3 p.m. in central Lomé.',
            'ee': 'Église Évangélique Nouvelle Vie – Maison du Miracle xɔa '
                'amewo Kɔsiɖagbe ɖe sia ɖe ga 15 me le Lomé.',
          },
        ),
      ],
    ),
  ];

  /// Identifiants « déjà connus » : le mock renvoie `isNewUser: false` pour
  /// ceux-ci (→ accueil direct). Emails en minuscules.
  static const List<String> knownIdentifiers = [
    '+22890123456',
    'jean.kossi@email.com',
  ];

  // Le fil fictif `chat` **a disparu** avec #96 : la messagerie de groupe est
  // branchée, et son modèle de lecture est `GroupMessageView`
  // (`models/echanges_view.dart`), dont l'origine se lit sur le couple
  // `(authorId, isSystem)`. Une fixture à `author`/`time` déjà résolus ne pouvait
  // pas porter les trois origines, et c'est précisément le cas qu'il fallait
  // rendre visible.
}
