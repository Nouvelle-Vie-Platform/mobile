import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../screens/about_screen.dart';
import '../screens/agenda_screen.dart';
import '../screens/announcement_composer_screen.dart';
import '../screens/auth/code_screen.dart';
import '../screens/auth/identifier_screen.dart';
import '../screens/auth/profile_form_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/donations_screen.dart';
import '../screens/event_detail_screen.dart';
import '../screens/gathering_detail_screen.dart';
import '../screens/group_chat_screen.dart';
import '../screens/home_shell.dart';
import '../screens/legal_acceptance_screen.dart';
import '../screens/legal_document_screen.dart';
import '../screens/live_screen.dart';
import '../screens/media_library_screen.dart';
import '../screens/new_request_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/prayer_requests_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/teaching_detail_screen.dart';
import '../state/auth_providers.dart';
import '../state/legal_providers.dart';
import '../state/repository_providers.dart';
import '../widgets/app_background.dart';

/// Noms des routes nommées (à utiliser avec `context.goNamed` / `pushNamed`).
abstract final class AppRoute {
  static const splash = 'splash';
  // Parcours d'authentification unifié (login + inscription).
  static const authWelcome = 'auth-welcome';
  static const authIdentifier = 'auth-identifier';
  static const authCode = 'auth-code';
  static const profileEdit = 'profile-edit';
  static const profileDelete = 'profile-delete';
  static const home = 'home';
  static const media = 'media';
  static const live = 'live';
  static const teachingDetail = 'teaching';
  static const gatheringDetail = 'gathering';
  static const groupChat = 'group-chat';
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

/// Emplacements autorisés tant que l'utilisateur n'est pas authentifié.
const _authLocations = {'/auth', '/auth/identifier', '/auth/code'};

/// La barrière de consentement — écrite une fois, lue par la garde et par la
/// route.
const _legalGate = '/legal/accept';

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
    redirect: (context, state) {
      final auth = authListenable.value;
      final loc = state.matchedLocation;
      switch (auth.status) {
        case AuthStatus.unknown:
          // Session pas encore résolue : rester sur le splash.
          return loc == '/' ? null : '/';
        case AuthStatus.unauthenticated:
          return _authLocations.contains(loc) ? null : '/auth';
        case AuthStatus.authenticated:
          // Depuis splash ou parcours d'auth → accueil. `/profile/edit` et le
          // reste de l'app restent accessibles.
          if (loc == '/' || _authLocations.contains(loc)) return '/home';
          // **La barrière** : les versions acceptées couvrent-elles les
          // versions exigées ? La comparaison a déjà eu lieu — ici on ne fait
          // que lire son résultat, sans rien attendre.
          if (legalGateListenable.value.isNotEmpty) {
            return loc == _legalGate ? null : _legalGate;
          }
          // Barrière levée — ou jamais dressée : l'écran se retire **de
          // lui-même**, personne ne navigue. C'est le motif de la déconnexion,
          // et c'est aussi ce qui empêche `/legal/accept` d'être un cul-de-sac
          // pour qui l'atteindrait sans rien avoir à accepter : rien n'en sort,
          // pas même un retour Android.
          return loc == _legalGate ? '/home' : null;
      }
    },
    routes: [
      GoRoute(
        name: AppRoute.splash,
        path: '/',
        builder: (_, __) => const AppBackground(child: SplashScreen()),
      ),
      GoRoute(
        name: AppRoute.authWelcome,
        path: '/auth',
        builder: (_, __) => const AppBackground(child: WelcomeScreen()),
      ),
      GoRoute(
        name: AppRoute.authIdentifier,
        path: '/auth/identifier',
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
      GoRoute(
        name: AppRoute.home,
        path: '/home',
        builder: (_, __) => const AppBackground(child: HomeShell()),
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
        builder: (_, __) => const AppBackground(child: MediaLibraryScreen()),
      ),
      GoRoute(
        name: AppRoute.live,
        path: '/live',
        builder: (_, __) => const AppBackground(child: LiveScreen()),
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
      GoRoute(
        name: AppRoute.groupChat,
        path: '/group-chat',
        builder: (_, state) {
          final group =
              state.extra as CommunityGroup? ?? ref.read(groupsProvider).first;
          return AppBackground(child: GroupChatScreen(group: group));
        },
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
