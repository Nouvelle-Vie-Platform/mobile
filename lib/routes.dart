import 'package:flutter/widgets.dart';

import 'screens/agenda_screen.dart';
import 'screens/donations_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/home_shell.dart';
import 'screens/live_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_request_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/prayer_requests_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/teaching_detail_screen.dart';

/// Table de routage de l'application.
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const live = '/live';
  static const teachingDetail = '/teaching';
  static const groupChat = '/group-chat';
  static const agenda = '/agenda';
  static const prayers = '/prayers';
  static const newRequest = '/new-request';
  static const donations = '/donations';
  static const notes = '/notes';

  static Map<String, WidgetBuilder> get table => {
        splash: (_) => const SplashScreen(),
        onboarding: (_) => const OnboardingScreen(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        home: (_) => const HomeShell(),
        live: (_) => const LiveScreen(),
        teachingDetail: (_) => const TeachingDetailScreen(),
        groupChat: (_) => const GroupChatScreen(),
        agenda: (_) => const AgendaScreen(),
        prayers: (_) => const PrayerRequestsScreen(),
        newRequest: (_) => const NewRequestScreen(),
        donations: (_) => const DonationsScreen(),
        notes: (_) => const NotesScreen(),
      };
}
