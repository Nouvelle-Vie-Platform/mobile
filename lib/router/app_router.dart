import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../screens/agenda_screen.dart';
import '../screens/donations_screen.dart';
import '../screens/group_chat_screen.dart';
import '../screens/home_shell.dart';
import '../screens/live_screen.dart';
import '../screens/login_screen.dart';
import '../screens/media_library_screen.dart';
import '../screens/new_request_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/prayer_requests_screen.dart';
import '../screens/register_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/teaching_detail_screen.dart';
import '../state/repository_providers.dart';

/// Noms des routes nommées (à utiliser avec `context.goNamed` / `pushNamed`).
abstract final class AppRoute {
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const register = 'register';
  static const home = 'home';
  static const media = 'media';
  static const live = 'live';
  static const teachingDetail = 'teaching';
  static const groupChat = 'group-chat';
  static const agenda = 'agenda';
  static const prayers = 'prayers';
  static const newRequest = 'new-request';
  static const donations = 'donations';
  static const notes = 'notes';
}

/// Routeur de l'application (go_router).
///
/// Exposé via Riverpod pour pouvoir résoudre des dépendances (repository) lors
/// d'un accès direct à une route de détail sans argument (deep link).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        name: AppRoute.splash,
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        name: AppRoute.onboarding,
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        name: AppRoute.login,
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        name: AppRoute.register,
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        name: AppRoute.home,
        path: '/home',
        builder: (_, __) => const HomeShell(),
      ),
      GoRoute(
        name: AppRoute.media,
        path: '/media',
        builder: (_, __) => const MediaLibraryScreen(),
      ),
      GoRoute(
        name: AppRoute.live,
        path: '/live',
        builder: (_, __) => const LiveScreen(),
      ),
      GoRoute(
        name: AppRoute.teachingDetail,
        path: '/teaching',
        builder: (_, state) {
          // L'enseignement ciblé est passé via `extra` ; repli sur le premier
          // enseignement disponible en cas d'accès direct.
          final teaching =
              state.extra as Teaching? ?? ref.read(teachingsProvider).first;
          return TeachingDetailScreen(teaching: teaching);
        },
      ),
      GoRoute(
        name: AppRoute.groupChat,
        path: '/group-chat',
        builder: (_, state) {
          final group =
              state.extra as CommunityGroup? ?? ref.read(groupsProvider).first;
          return GroupChatScreen(group: group);
        },
      ),
      GoRoute(
        name: AppRoute.agenda,
        path: '/agenda',
        builder: (_, __) => const AgendaScreen(),
      ),
      GoRoute(
        name: AppRoute.prayers,
        path: '/prayers',
        builder: (_, __) => const PrayerRequestsScreen(),
      ),
      GoRoute(
        name: AppRoute.newRequest,
        path: '/new-request',
        builder: (_, __) => const NewRequestScreen(),
      ),
      GoRoute(
        name: AppRoute.donations,
        path: '/donations',
        builder: (_, __) => const DonationsScreen(),
      ),
      GoRoute(
        name: AppRoute.notes,
        path: '/notes',
        builder: (_, __) => const NotesScreen(),
      ),
    ],
  );
});
