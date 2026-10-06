import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../screens/about_screen.dart';
import '../screens/agenda_screen.dart';
import '../screens/announcement_composer_screen.dart';
import '../screens/archived_chats_screen.dart';
import '../screens/auth/code_screen.dart';
import '../screens/auth/identifier_screen.dart';
import '../screens/auth/profile_form_screen.dart';
import '../screens/bible_screen.dart';
import '../screens/chat_search_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/donations_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/event_detail_screen.dart';
import '../screens/gathering_detail_screen.dart';
import '../screens/group_chat_screen.dart';
import '../screens/home_shell.dart';
import '../screens/legal_acceptance_screen.dart';
import '../screens/legal_document_screen.dart';
import '../screens/media_settings_screen.dart';
import '../screens/radio_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/media_library_screen.dart';
import '../screens/member_profile_screen.dart';
import '../screens/new_request_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/group_info_screen.dart';
import '../screens/media_viewer_screen.dart';
import '../screens/prayer_requests_screen.dart';
import '../screens/requests_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/teaching_detail_screen.dart';
import '../state/auth_providers.dart';
import '../state/legal_providers.dart';
import '../state/repository_providers.dart';
import '../widgets/app_background.dart';
import '../widgets/home_tab.dart';
import '../widgets/mini_player_host.dart';

/// Noms des routes nommées (à utiliser avec `context.goNamed` / `pushNamed`).
abstract final class AppRoute {
  static const splash = 'splash';

  /// **Le parcours d'authentification unifié** (connexion + inscription), et il
  /// n'a plus que **deux** écrans.
  ///
  /// `authWelcome` a disparu avec l'écran de bienvenue qu'il servait sur `/auth` :
  /// depuis le mode invité l'application ne s'ouvre plus sur l'authentification,
  /// cet écran n'était donc plus un accueil mais une page de garde devant un
  /// formulaire — et, n'ayant ni `appBar` ni `PopScope`, un cul-de-sac sur
  /// iPhone, qui n'a pas de bouton retour système. `/auth` sert désormais le
  /// formulaire lui-même.
  static const authIdentifier = 'auth-identifier';
  static const authCode = 'auth-code';
  static const profileEdit = 'profile-edit';
  static const profileDelete = 'profile-delete';
  static const mediaSettings = 'media-settings';
  static const downloads = 'downloads';
  static const home = 'home';
  static const profile = 'profile';

  /// **La Bible**, depuis l'icône en haut à droite de l'accueil. Une route neuve
  /// : la Bible était un onglet, elle n'avait donc rien ici. Elle est
  /// **ouverte** — la surface invitée décidée par le client la nomme.
  static const bible = 'bible';
  static const media = 'media';

  /// **New Life Radio** (#104). La route s'appelait `live` et servait un écran qui
  /// jouait la RTBF belge ; elle sert désormais l'antenne de l'église, et porte son
  /// nom. Le culte en direct redeviendra une fonctionnalité à part entière, avec
  /// son propre chantier — et sa propre route, qui ne sera pas celle-ci.
  static const radio = 'radio';
  static const teachingDetail = 'teaching';
  static const gatheringDetail = 'gathering';
  static const groupChat = 'group-chat';
  static const groupInfo = 'group-info';

  /// **Mes discussions archivées** (#146, M8).
  static const chatArchived = 'chat-archived';

  /// **Rechercher dans mes discussions** (#146, M8).
  static const chatSearch = 'chat-search';
  static const mediaViewer = 'media-viewer';
  static const memberProfile = 'member-profile';
  static const requests = 'requests';
  static const agenda = 'agenda';
  static const eventDetail = 'event';
  static const prayers = 'prayers';
  static const newRequest = 'new-request';
  static const donations = 'donations';
  static const notes = 'notes';

  /// Document légal en **consultation** — `kind ∈ {cgu, privacy}`.
  /// « À propos » a sa propre route : le ranger sous `/legal/` mentirait sur sa
  /// nature, et l'écran ne se réduit pas au document.
  static const legalDocument = 'legal';
  static const about = 'about';

  /// **La barrière de consentement.** Atteinte par le `redirect`, jamais par
  /// une navigation explicite — le nom existe pour la nommer, pas pour y aller.
  static const legalAccept = 'legal-accept';

  /// Composeur d'annonce, en **création**.
  static const announcementCompose = 'announcement-compose';

  /// Composeur d'annonce, en **modification** — l'identifiant en paramètre de
  /// chemin, comme `/teaching/:id` : l'écran résout la ligne dans le magasin, il
  /// ne reçoit pas de copie figée au moment du clic.
  static const announcementEdit = 'announcement-edit';
}

/// Arguments passés à [CodeScreen] via `extra`.
///
/// Pour les agents parallèles : naviguer avec
/// `context.goNamed(AppRoute.authCode, extra: CodeArgs(identifier: ..., channel: ...))`.
/// [CodeScreen] les relit via `GoRouterState.of(context).extra as CodeArgs?`.
@immutable
class CodeArgs {
  const CodeArgs({required this.identifier, required this.channel});

  /// Téléphone E.164 ou email déjà normalisé (celui envoyé à `requestCode`).
  final String identifier;
  final IdentifierChannel channel;
}

/// Le parcours d'authentification — **ouvert à tous**, et atteint par un geste.
///
/// Sous le mode invité ce n'est plus une liste d'exceptions dans une
/// application fermée, mais deux écrans comme les autres, poussés par
/// `requireSession()` quand un geste exige un compte. La constante ne sert plus
/// qu'à une chose : ramener à l'accueil un **membre** qui y reviendrait alors
/// qu'il est déjà connecté.
const _authLocations = {'/auth', '/auth/code'};

/// La barrière de consentement — écrite une fois, lue par la garde et par la
/// route.
const _legalGate = '/legal/accept';

/// **Les seuls écrans réservés aux membres.** Tout ce qui n'y figure pas est
/// ouvert, et le défaut penche de ce côté-là exprès : un écran ajouté demain
/// s'ouvre, il ne se ferme pas par accident. Fermer par oubli est invisible —
/// personne ne réclame un écran qu'il n'a jamais vu ; ouvrir par oubli se
/// remarque et se corrige en une ligne.
///
/// La surface **invitée** est donc tout le reste, et c'est la décision du
/// client : accueil, annonces en lecture, médiathèque, fiche d'enseignement,
/// fiche de rassemblement, agenda, New Life Radio, téléchargements, Bible, dons, CGU,
/// confidentialité, à propos.
///
/// **Les clés sont des motifs de route**, tels que `GoRouterState.fullPath` les
/// rend — jamais des chemins concrets : `/announcement/:id/edit` ne se
/// reconnaîtrait pas dans `/announcement/42/edit`, et la garde laisserait
/// passer exactement l'écran qu'elle croit fermer.
///
/// Trois entrées méritent leur justification :
/// - `/member-profile` n'est pas nommé dans la liste du client, mais c'est la
///   fiche d'**un autre membre**, atteinte depuis la communauté : elle
///   appartient à la même surface qu'Échanges. C'est le seul ajout par rapport
///   à la décision écrite, et il est réversible d'une ligne ;
/// - `/legal/accept` est la barrière de consentement. Un invité n'a rien à y
///   accepter (`pendingLegalAcceptancesProvider` rend une liste vide sans
///   utilisateur) ; l'y laisser entrer lui montrerait un écran dont rien ne le
///   ferait sortir, `PopScope(canPop: false)` compris ;
/// - la **consultation** des documents (`/legal/:kind`, `/about`) n'y est pas :
///   c'est précisément ce qu'on doit pouvoir lire sans compte.
const memberOnlyRoutes = <String>{
  // Le profil et ce qui en dépend.
  '/profile',
  '/profile/edit',
  '/profile/delete',
  // L'**écriture** d'une annonce — leur lecture est ouverte.
  '/announcement/compose',
  '/announcement/:id/edit',
  // Ce qui n'a aucun sens sans compte : des notes, des prières, des demandes.
  '/notes',
  '/prayers',
  '/new-request',
  '/requests',
  // Échanges. ⚠️ **Les clés sont des motifs de route** (`GoRouterState.fullPath`),
  // jamais des chemins concrets : depuis #96 ces trois-là portent un
  // `pathParameter`, et `/group-chat/42` ne se reconnaîtrait pas dans
  // `'/group-chat'`. La garde laisserait passer exactement l'écran qu'elle croit
  // fermer.
  '/group-chat/:id',
  '/group-info/:id',
  '/member-profile/:id',
  // M8 (#146) : mes archives et la recherche dans mes messages.
  '/chats/archived',
  '/chats/search',
  // La barrière de consentement.
  _legalGate,
};

/// **La garde, écrite une fois et testable sans routeur.**
///
/// Elle vit hors du `redirect` pour une raison précise : c'est l'endroit du
/// dépôt où une erreur ne se voit pas — un écran fermé par accident ne fait
/// rougir aucun test, et personne ne réclame ce qu'il n'a jamais vu. Sortie en
/// fonction pure, elle se vérifie **route par route** contre la table déclarée
/// du routeur (`test/state/guest_guard_test.dart`), sans monter un seul écran.
///
/// [location] est le chemin concret (`GoRouterState.matchedLocation`),
/// [pattern] le motif de la route (`GoRouterState.fullPath`) — c'est lui qui
/// décide, le chemin ne servant qu'au splash et au parcours d'authentification.
String? redirectFor({
  required AuthStatus status,
  required String location,
  String? pattern,
  bool legalPending = false,
}) {
  switch (status) {
    case AuthStatus.unknown:
      // Une session de membre attend d'être résolue : rester sur le splash.
      // **Cet état ne se produit plus sur un coffre vide** — voir
      // `AuthController.build` —, et c'est ce qui retire l'écran d'attente du
      // premier lancement au lieu de le raccourcir.
      return location == '/' ? null : '/';
    case AuthStatus.guest:
      // **Public par défaut.** Le splash n'a rien à résoudre pour un invité :
      // il va droit à l'accueil.
      if (location == '/') return '/home';
      // Et les écrans réservés ramènent à l'**accueil invité**, jamais vers
      // `/auth`. Renvoyer vers la connexion serait le verrou qu'on retire : la
      // connexion se demande au moment du geste (`requireSession`), elle ne
      // s'impose pas à l'arrivée sur une route.
      return memberOnlyRoutes.contains(pattern ?? location) ? '/home' : null;
    case AuthStatus.authenticated:
      // **Rien ne change de ce côté-ci**, et c'est la contrainte du client :
      // « quand la personne s'est déjà connectée, tout se passe exactement
      // comme présentement ».
      //
      // Depuis splash ou parcours d'auth → accueil. `/profile/edit` et le
      // reste de l'app restent accessibles.
      if (location == '/' || _authLocations.contains(location)) return '/home';
      // **La barrière** : les versions acceptées couvrent-elles les versions
      // exigées ? La comparaison a déjà eu lieu — ici on ne fait que lire son
      // résultat, sans rien attendre.
      if (legalPending) {
        return location == _legalGate ? null : _legalGate;
      }
      // Barrière levée — ou jamais dressée : l'écran se retire **de
      // lui-même**, personne ne navigue. C'est le motif de la déconnexion, et
      // c'est aussi ce qui empêche `/legal/accept` d'être un cul-de-sac pour
      // qui l'atteindrait sans rien avoir à accepter : rien n'en sort, pas
      // même un retour Android.
      return location == _legalGate ? '/home' : null;
  }
}

/// Routeur de l'application (go_router).
///
/// Exposé via Riverpod pour résoudre des dépendances (repository) lors d'un
/// accès direct à une route de détail, et pour brancher les gardes `redirect`
/// sur [authProvider].
final routerProvider = Provider<GoRouter>((ref) {
  // Pont entre Riverpod et go_router : un ValueNotifier alimenté par
  // l'AuthState relance l'évaluation des `redirect` à chaque changement.
  final authListenable = ValueNotifier<AuthState>(ref.read(authProvider));
  ref.onDispose(authListenable.dispose);
  ref.listen<AuthState>(
    authProvider,
    (_, next) => authListenable.value = next,
  );

  // Le second pont, celui de la **barrière de consentement** (#56) : les genres
  // qu'il reste à accepter, calculés hors du `redirect`.
  //
  // Deux raisons de passer par un `ValueNotifier` plutôt que de lire le
  // provider dans la garde, et la seconde est la vraie :
  //
  // 1. c'est déjà le motif de l'authentification, et une garde a tout intérêt à
  //    n'avoir qu'une façon de lire son état ;
  // 2. **un `ref.listen` maintient le provider vivant**, donc abonné au flux du
  //    magasin. La garde lit alors une valeur déjà là — jamais un `Future`,
  //    jamais un `AsyncValue` en cours de chargement (ADR-0036, décision 1).
  //    Et c'est ce même abonnement qui fait réévaluer la garde quand la
  //    synchronisation ramène une révision : sans lui, une barrière publiée
  //    n'apparaîtrait qu'à la navigation suivante.
  final legalGateListenable = ValueNotifier<List<String>>(
    ref.read(pendingLegalAcceptancesProvider),
  );
  ref.onDispose(legalGateListenable.dispose);
  ref.listen<List<String>>(
    pendingLegalAcceptancesProvider,
    (_, next) => legalGateListenable.value = next,
  );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([authListenable, legalGateListenable]),
    // **Les fenêtres surgissantes, comptées pour le mini-lecteur** (#117) : un
    // dialogue ou une feuille du bas ne change pas la route, et la carte posée
    // au-dessus du `Navigator` flotterait sinon par-dessus leur barrière.
    // L'hôte le retrouve ici (`MiniPlayerPopupObserver.of`).
    observers: [MiniPlayerPopupObserver()],
    // La garde n'a plus de corps ici : elle vit dans [redirectFor], pour se
    // vérifier route par route sans monter un écran. Ce `redirect` ne fait que
    // lui passer ce que seul le routeur sait.
    redirect: (context, state) => redirectFor(
      status: authListenable.value.status,
      location: state.matchedLocation,
      pattern: state.fullPath,
      legalPending: legalGateListenable.value.isNotEmpty,
    ),
    routes: [
      GoRoute(
        name: AppRoute.splash,
        path: '/',
        builder: (_, __) => const AppBackground(child: SplashScreen()),
      ),
      // **`/auth` est le formulaire**, et non plus une page de garde devant lui.
      // Le chemin n'a pas bougé — c'est celui que `requireSession()` pousse, que
      // le 401 atteint, et une URL servie sur la cible web — seul son écran a
      // changé ; `/auth/identifier` disparaît avec l'étape qu'il dédoublait.
      GoRoute(
        name: AppRoute.authIdentifier,
        path: '/auth',
        builder: (_, __) => const AppBackground(child: IdentifierScreen()),
      ),
      GoRoute(
        name: AppRoute.authCode,
        path: '/auth/code',
        builder: (_, __) => const AppBackground(child: CodeScreen()),
      ),
      GoRoute(
        name: AppRoute.profileEdit,
        path: '/profile/edit',
        builder: (_, __) => const AppBackground(child: ProfileFormScreen()),
      ),
      // Suppression de compte — **une route et non un dialogue**, exigence
      // App Store 5.1.1(v). Déclarée après `/profile/edit` : go_router essaie
      // les routes dans l'ordre, et les deux chemins ne se recouvrent pas.
      GoRoute(
        name: AppRoute.profileDelete,
        path: '/profile/delete',
        builder: (_, __) => const AppBackground(child: DeleteAccountScreen()),
      ),
      // Réglages média — poussée depuis le Profil, où elle a remplacé
      // l'hexagone des dons.
      GoRoute(
        name: AppRoute.mediaSettings,
        path: '/settings/media',
        builder: (_, __) => const AppBackground(child: MediaSettingsScreen()),
      ),
      // Page Téléchargements — poussée depuis le Profil, où elle a pris la
      // place de l'hexagone « Ma branche » (#193, F12). L'écran observe le
      // magasin `downloads` ; il ne reçoit aucun argument.
      GoRoute(
        name: AppRoute.downloads,
        path: '/downloads',
        builder: (_, __) => const AppBackground(child: DownloadsScreen()),
      ),
      GoRoute(
        name: AppRoute.home,
        path: '/home',
        // `?tab=<nom>` (#140) : l'onglet de départ. Seul le retour d'un fil
        // ouvert par une notification s'en sert — `/home?tab=community`, la
        // liste des Échanges. Un nom inconnu retombe sur l'accueil.
        builder: (_, state) => AppBackground(
          child: HomeShell(
            initialTab:
                HomeTab.values.asNameMap()[state.uri.queryParameters['tab']],
          ),
        ),
      ),
      // Profil **en plus de l'onglet**, et non à sa place : l'onglet est la
      // porte d'entrée, cette route-ci reste le lien profond (`/profile` est une
      // URL servie sur la cible web) et sert le même écran avec une flèche de
      // retour. Elle garde sa place dans `memberOnlyRoutes` ; l'onglet, lui, est
      // gardé au geste par `requireSession()` — une garde de route n'a aucune
      // prise sur un onglet.
      GoRoute(
        name: AppRoute.profile,
        path: '/profile',
        builder: (_, __) =>
            const AppBackground(child: ProfileScreen(showBack: true)),
      ),
      // La Bible, **poussée** depuis l'en-tête de l'accueil. Aucune garde : elle
      // appartient à la surface invitée, et l'écran est provisoire.
      GoRoute(
        name: AppRoute.bible,
        path: '/bible',
        builder: (_, __) => const AppBackground(child: BibleScreen()),
      ),
      // Composeur d'annonce — deux chemins, un seul écran. Ils ne se disputent
      // rien : `/announcement/compose` a un segment, `/announcement/:id/edit`
      // en a trois. **Aucune garde de route** : l'affordance n'existe déjà que
      // pour les membres d'un compte officiel, et le serveur revérifie à chaque
      // écriture — une garde côté client ferait passer une copie locale de
      // permissions pour la source de vérité.
      GoRoute(
        name: AppRoute.announcementCompose,
        path: '/announcement/compose',
        builder: (_, __) =>
            const AppBackground(child: AnnouncementComposerScreen()),
      ),
      GoRoute(
        name: AppRoute.announcementEdit,
        path: '/announcement/:id/edit',
        builder: (_, state) => AppBackground(
          child: AnnouncementComposerScreen(
            announcementId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        name: AppRoute.media,
        path: '/media',
        // `?rubrique=` porte le **slug** d'une rubrique, et c'est ce qui répare
        // le « Voir tout » d'une section d'accueil : il poussait `/media` nu,
        // donc la médiathèque **non filtrée** — appuyer sur « Voir tout » de
        // « Prières » affichait tout le catalogue.
        //
        // Un slug et non un identifiant, et le nom du paramètre est celui que le
        // site public emploie déjà (`?rubrique=`, figé par le cadrage § 12.6) :
        // c'est ce qui survit au renommage d'une rubrique, et ce qu'un lien
        // partagé ou une notification saurait transporter. Un slug que le magasin
        // ne connaît pas ne ramène rien — jamais le catalogue entier.
        builder: (_, state) => AppBackground(
          child: MediaLibraryScreen(
            initialRubric: state.uri.queryParameters['rubrique'],
          ),
        ),
      ),
      GoRoute(
        name: AppRoute.radio,
        path: '/radio',
        builder: (_, __) => const AppBackground(child: RadioScreen()),
      ),
      GoRoute(
        name: AppRoute.teachingDetail,
        path: '/teaching/:id',
        builder: (_, state) {
          // La route porte l'**identifiant**, jamais l'objet : c'est l'écran
          // qui résout, dans la source de vérité, à chaque build. Passer un
          // `Teaching` par `extra` en aurait fait une copie figée au clic, que
          // ni une rétractation ni une mise à jour n'auraient rattrapée.
          //
          // Plus de repli non plus : `.first` n'était pas un garde-fou mais un
          // aveu — `/teaching` sans argument n'avait aucun moyen de désigner
          // *quel* enseignement, et levait de toute façon sur liste vide. Un
          // identifiant est présent (go_router garantit le paramètre de
          // chemin) ou absent, et absent qui ne résout rien est un contenu
          // retiré, traité par l'écran.
          return AppBackground(
            child:
                TeachingDetailScreen(teachingId: state.pathParameters['id']!),
          );
        },
      ),
      GoRoute(
        name: AppRoute.gatheringDetail,
        path: '/gathering/:id',
        builder: (_, state) {
          // **Une route par famille, et l'identifiant seul dessus.** Pas de
          // `/content/:famille/:id` : le chemin dirait alors au client qu'il
          // lui revient de trancher entre deux collections, exactement ce que
          // la clé de collection sert à ne pas avoir à faire. Ici la route
          // désigne la collection, et l'écran lit **un** provider.
          return AppBackground(
            child:
                GatheringDetailScreen(gatheringId: state.pathParameters['id']!),
          );
        },
      ),
      // **L'identifiant, jamais l'objet** (#96). Les trois routes d'Échanges
      // portaient un objet en `extra`, avec repli sur « la première
      // conversation » en cas d'accès direct. Ce repli n'était pas un garde-fou :
      // c'était l'aveu que `/group-chat` ne désignait **aucune** conversation en
      // particulier, et il levait de toute façon dès que `SampleData` a disparu.
      //
      // Trois raisons de la bascule, dans l'ordre d'importance : un objet en
      // `extra` est une copie figée hors du magasin, qui continuerait d'afficher
      // un fil que la modération a retiré ; **un réveil push (tranche 2) et un
      // lien profond n'ont qu'une chaîne à transmettre** ; et un identifiant est
      // présent ou absent, il n'y a rien à quoi se replier — un identifiant qui ne
      // résout rien n'est pas une erreur technique, c'est une absence, et ça
      // s'affiche.
      GoRoute(
        name: AppRoute.groupChat,
        path: '/group-chat/:id',
        builder: (_, state) => AppBackground(
          child: GroupChatScreen(
            groupId: state.pathParameters['id']!,
            // M8 (#146) : ouvert depuis la recherche, sur le message trouvé.
            focusMessageId: state.uri.queryParameters['message'],
          ),
        ),
      ),
      GoRoute(
        name: AppRoute.chatArchived,
        path: '/chats/archived',
        builder: (_, __) => const AppBackground(child: ArchivedChatsScreen()),
      ),
      GoRoute(
        name: AppRoute.chatSearch,
        path: '/chats/search',
        builder: (_, __) => const AppBackground(child: ChatSearchScreen()),
      ),
      GoRoute(
        name: AppRoute.groupInfo,
        path: '/group-info/:id',
        builder: (_, state) => AppBackground(
          child: GroupInfoScreen(groupId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        name: AppRoute.mediaViewer,
        path: '/media-viewer',
        builder: (_, state) {
          final args = state.extra as MediaViewerArgs? ??
              const MediaViewerArgs(urls: [], index: 0);
          // ⚠️ **Plus aucun écran n'ouvre cette route depuis #96** : les médias
          // partagés d'une fiche de groupe étaient des images inventées, et ils
          // sont retirés jusqu'à la tranche 3, où ils seront **les images du
          // fil** (décision 10 : « vide en 1, rempli en 3 »). La route, l'écran
          // et leur configuration native restent en place — c'est la destination
          // que la tranche 3 câblera, et la détruire pour la réécrire à
          // l'identique ne gagnerait rien.
          //
          // `onDownload` sera branché une fois le mécanisme de téléchargement
          // choisi (plugin d'enregistrement galerie / partage). Tant qu'il est
          // nul, la visionneuse ouvre les médias sans bouton télécharger.
          return MediaViewerScreen(args: args);
        },
      ),
      GoRoute(
        name: AppRoute.memberProfile,
        path: '/member-profile/:id',
        builder: (_, state) => AppBackground(
          child: MemberProfileScreen(memberId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        name: AppRoute.requests,
        path: '/requests',
        builder: (_, __) => const AppBackground(child: RequestsScreen()),
      ),
      GoRoute(
        name: AppRoute.agenda,
        path: '/agenda',
        builder: (_, __) => const AppBackground(child: AgendaScreen()),
      ),
      GoRoute(
        name: AppRoute.eventDetail,
        path: '/event',
        builder: (_, state) {
          // L'évènement ciblé est passé via `extra` ; repli sur le premier
          // évènement disponible en cas d'accès direct (lien, restauration
          // d'état) — la route ne doit jamais planter faute d'argument.
          final event =
              state.extra as ChurchEvent? ?? ref.read(eventsProvider).first;
          return AppBackground(child: EventDetailScreen(event: event));
        },
      ),
      GoRoute(
        name: AppRoute.prayers,
        path: '/prayers',
        builder: (_, __) => const AppBackground(child: PrayerRequestsScreen()),
      ),
      GoRoute(
        name: AppRoute.newRequest,
        path: '/new-request',
        builder: (_, __) => const AppBackground(child: NewRequestScreen()),
      ),
      GoRoute(
        name: AppRoute.donations,
        path: '/donations',
        builder: (_, __) => const AppBackground(child: DonationsScreen()),
      ),
      GoRoute(
        name: AppRoute.notes,
        path: '/notes',
        builder: (_, __) => const AppBackground(child: NotesScreen()),
      ),
      // Les trois destinations documentaires du menu latéral.
      //
      // La consultation est servie depuis #55 : `LegalDocumentScreen` lit le
      // magasin et rend `ContentAbsence.notSynced` devant un document qui n'est
      // pas encore arrivé. `/about` a sa **propre** route depuis #57 : son
      // écran ne se réduit pas au document servi — il porte la version du
      // binaire, que le serveur ne peut pas connaître, et s'affiche donc même
      // sans document en magasin.
      //
      // Aucune garde ici : la barrière d'acceptation (`/legal/accept`) est un
      // `redirect`, pas une route de consultation.
      // **Avant `/legal/:kind`, et l'ordre n'est pas cosmétique** : go_router
      // essaie les routes dans l'ordre déclaré, et `/legal/accept` se ferait
      // sinon avaler par le paramètre de chemin — la barrière rendrait alors la
      // CGU en consultation, avec un bouton retour et aucune case.
      GoRoute(
        name: AppRoute.legalAccept,
        path: _legalGate,
        builder: (_, __) => const AppBackground(child: LegalAcceptanceScreen()),
      ),
      GoRoute(
        name: AppRoute.legalDocument,
        path: '/legal/:kind',
        builder: (_, state) => AppBackground(
          child: LegalDocumentScreen(kind: state.pathParameters['kind']!),
        ),
      ),
      GoRoute(
        name: AppRoute.about,
        path: '/about',
        builder: (_, __) => const AppBackground(child: AboutScreen()),
      ),
    ],
  );
});
