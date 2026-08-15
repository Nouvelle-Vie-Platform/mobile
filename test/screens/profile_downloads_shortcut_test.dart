/// **Le relabel du premier hexagone du Profil** (#193, F12).
///
/// La rangée `[Ma branche · Notes · Agenda · Qualité]` voit son **premier**
/// hexagone devenir « Téléchargements » (route `/downloads`). Les trois autres
/// hexagones — et le nom de branche de l'en-tête — sont inchangés.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';

import '../helpers/pump_screen.dart';

/// Un écran-repère par destination, reconnaissable à son texte.
Widget _marker(String label) => Scaffold(body: Center(child: Text(label)));

GoRouter _router() => GoRouter(
      initialLocation: '/hote',
      routes: [
        GoRoute(
          path: '/hote',
          // L'hôte observe `authProvider`, comme le routeur de l'application :
          // sans cela le provider ne serait construit qu'au premier `ref.read`.
          builder: (_, __) => Consumer(
            builder: (context, ref, __) {
              ref.watch(authProvider);
              return const Scaffold(body: ProfileScreen());
            },
          ),
        ),
        GoRoute(
          name: AppRoute.downloads,
          path: '/downloads',
          builder: (_, __) => _marker('PAGE_DOWNLOADS'),
        ),
        GoRoute(
          name: AppRoute.notes,
          path: '/notes',
          builder: (_, __) => _marker('PAGE_NOTES'),
        ),
        GoRoute(
          name: AppRoute.agenda,
          path: '/agenda',
          builder: (_, __) => _marker('PAGE_AGENDA'),
        ),
        GoRoute(
          name: AppRoute.mediaSettings,
          path: '/settings/media',
          builder: (_, __) => _marker('PAGE_MEDIA'),
        ),
      ],
    );

void main() {
  group('Le premier hexagone du Profil', () {
    testWidgets('porte « Téléchargements » et mène à /downloads',
        (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await pumpRouter(tester, router);

      expect(find.text('Téléchargements'), findsOneWidget);

      await tester.tap(find.text('Téléchargements'));
      await tester.pumpAndSettle();

      expect(find.text('PAGE_DOWNLOADS'), findsOneWidget);
    });

    testWidgets('les trois autres hexagones sont inchangés', (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await pumpRouter(tester, router);

      // Notes, Agenda, Qualité restent en place…
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Qualité'), findsOneWidget);

      // …et « Notes » mène toujours à sa page, preuve qu'on n'a pas déplacé les
      // autres raccourcis en relabelant le premier.
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE_NOTES'), findsOneWidget);
    });
  });
}
