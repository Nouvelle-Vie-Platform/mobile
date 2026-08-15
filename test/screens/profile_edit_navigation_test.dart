import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/auth/profile_form_screen.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/widgets/menu_tile.dart';

import '../helpers/pump_screen.dart';

/// Une session ouverte, dont on choisit si le profil est complet.
class _Auth extends InMemoryAuthRepository {
  _Auth({required this.complete});

  final bool complete;

  User get _fixture => User(
        id: 'u_1',
        firstName: 'Fabrice',
        status: UserStatus.affiliated,
        profileComplete: complete,
      );

  @override
  Future<User?> cachedUser() async => _fixture;

  /// **Les deux, pas seulement le cache.** `AuthController` revalide en fond ;
  /// sans cette surcharge, la revalidation écrase l'utilisateur du cache par
  /// celui du double en mémoire — nul — et l'écran repasse en mode complétion.
  @override
  Future<User?> currentUser() async => _fixture;
}

void main() {
  group('Le doublon d\'accès à la modification', () {
    testWidgets('la liste du Profil ne porte plus « Modifier mon profil »',
        (tester) async {
      // `ProfileScreen` n'est pas un `Scaffold` : il vit dans celui de la
      // coquille, et ses `InkWell` exigent un `Material` au-dessus d'eux.
      await pumpScreen(
        tester,
        const Scaffold(body: ProfileScreen()),
        auth: _Auth(complete: true),
      );

      // Le bouton du bandeau bleu reste le seul chemin depuis cet écran : deux
      // entrées vers la même page, à un écran d'écart, se remarquent comme un
      // doublon.
      final labels = tester
          .widgetList<MenuTile>(find.byType(MenuTile))
          .map((tile) => tile.label)
          .toList();
      expect(labels, isNot(contains('Modifier mon profil')));
      // La liste reste une liste de réglages, elle n'a pas été vidée.
      expect(labels, isNotEmpty);
    });
  });

  group('Le retour depuis le formulaire', () {
    /// Monte le formulaire **empilé par go_router**, comme le fait
    /// `pushNamed` depuis l'onglet Profil.
    ///
    /// Un vrai `GoRouter` et non un `Navigator.push` : `context.pop()` et
    /// `context.canPop()` sont les extensions de **go_router**, qui consultent
    /// sa pile à lui. Un test bâti sur le `Navigator` nu ne prouverait rien de
    /// ce qui se passe dans l'application.
    Future<void> pushForm(WidgetTester tester, {required bool complete}) async {
      // Un écran assez haut pour que les deux boutons du bas du formulaire
      // soient construits **et** atteignables : sous le 800×600 par défaut du
      // harnais, `tap()` refuse de les toucher.
      tester.view.physicalSize = const Size(1170, 5400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/hote',
        routes: [
          GoRoute(
            path: '/hote',
            // **L'hôte observe `authProvider`**, comme le routeur de
            // l'application le fait dès le démarrage. Sans cela le provider ne
            // serait construit qu'au premier `ref.read` — celui de
            // `ProfileFormScreen.initState` — qui lirait donc un état non
            // encore résolu et croirait le profil incomplet.
            builder: (context, __) => Consumer(
              builder: (context, ref, __) {
                ref.watch(authProvider);
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('ouvrir'),
                      onPressed: () => context.push('/profile/edit'),
                      child: const Text('ouvrir'),
                    ),
                  ),
                );
              },
            ),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (_, __) => const ProfileFormScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await pumpRouter(tester, router, auth: _Auth(complete: complete));
      await tester.tap(find.byKey(const Key('ouvrir')));
      await tester.pumpAndSettle();
    }

    testWidgets('une flèche de retour apparaît quand l\'écran est empilé',
        (tester) async {
      await pushForm(tester, complete: true);

      // Elle n'a rien à câbler : `AppBar` la pose dès qu'il y a quelque chose à
      // dépiler. C'est `go` — qui remplaçait la route — qui la faisait
      // disparaître.
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('renoncer ramène à l\'écran d\'où l\'on vient', (tester) async {
      await pushForm(tester, complete: true);
      expect(find.byType(ProfileFormScreen), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileFormScreen), findsNothing);
      expect(find.byKey(const Key('ouvrir')), findsOneWidget);
    });

    testWidgets('profil incomplet : « Plus tard », et il ramène aussi',
        (tester) async {
      // **Le cas qui se ratait.** La décision se prenait sur le mode d'édition,
      // donc celui qui complétait son profil depuis la bannière était jeté sur
      // l'accueil alors qu'il venait du Profil.
      await pushForm(tester, complete: false);

      expect(find.text('Plus tard'), findsOneWidget);
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileFormScreen), findsNothing);
      expect(find.byKey(const Key('ouvrir')), findsOneWidget);
    });
  });
}
