/// **Mon assemblée** (#184) — la page à elle, et la ligne du Profil qui y mène.
///
/// Même règle que la page Qualité dont elle sort : pas de flux Drift sous
/// horloge factice. La préférence et la liste se lisent ponctuellement
/// (`preferredBranchProvider`, `branchScopeChoicesProvider`), et toute écriture
/// ou relecture de la base passe par `runAsync`.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/branch_scope/branch_scope.dart';
import 'package:maison_du_miracle/data/branch_scope/branch_scope_mirror.dart';
import 'package:maison_du_miracle/data/branch_scope/branch_scope_store.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/branch_scope_screen.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/state/branch_scope_providers.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/pump_screen.dart';

void main() {
  late AppDatabase database;

  /// Deux assemblées en base, et éventuellement une préférence.
  Future<void> seed(WidgetTester tester, {int? preferred}) async {
    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() async {
      await database.into(database.branches).insert(branchRow(1, 'Lomé'));
      await database.into(database.branches).insert(branchRow(2, 'Kara'));
      if (preferred != null) {
        await database.settingsDao.setPreferredBranch(preferred);
      }
    });
  }

  /// La façade, sans réseau ni cycle de synchronisation : le miroir réel
  /// partirait sur une socket que le harnais refuse.
  Override inertScope() => branchScopeProvider.overrideWith(
        (ref) => BranchScope(
          store: BranchScopeStore(database),
          mirror: const InertBranchScopeMirror(),
          resynchronize: () async {},
        ),
      );

  IconData radioIcon(WidgetTester tester, int? branchId) => tester
      .widget<Icon>(find.descendant(
        of: find.byKey(BranchScopeScreen.optionKey(branchId)),
        matching: find.byType(Icon),
      ))
      .icon!;

  group('La page Mon assemblée', () {
    testWidgets('« Toutes » et les assemblées du magasin', (tester) async {
      await seed(tester);
      await pumpScreen(
        tester,
        const BranchScopeScreen(),
        database: database,
        overrides: [inertScope()],
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      expect(find.text('Mon assemblée'), findsOneWidget);
      expect(find.byKey(BranchScopeScreen.optionKey(null)), findsOneWidget);
      expect(find.byKey(BranchScopeScreen.optionKey(1)), findsOneWidget);
      expect(find.byKey(BranchScopeScreen.optionKey(2)), findsOneWidget);
      expect(radioIcon(tester, null), Icons.radio_button_checked);
    });

    testWidgets('choisir une assemblée l\'enregistre et la coche',
        (tester) async {
      await seed(tester);
      await pumpScreen(
        tester,
        const BranchScopeScreen(),
        database: database,
        overrides: [inertScope()],
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      await tester.tap(find.byKey(BranchScopeScreen.optionKey(2)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();

      final stored = await tester.runAsync(
        () => database.settingsDao.readPreferredBranch(),
      );
      expect(stored, 2);
      expect(radioIcon(tester, 2), Icons.radio_button_checked);
      expect(radioIcon(tester, null), Icons.radio_button_unchecked);
    });
  });

  group('La ligne du Profil', () {
    GoRouter router() => GoRouter(
          initialLocation: '/hote',
          routes: [
            GoRoute(
              path: '/hote',
              builder: (_, __) => const Scaffold(body: ProfileScreen()),
            ),
            GoRoute(
              name: AppRoute.branchScope,
              path: '/settings/branch',
              builder: (_, __) => const Scaffold(body: Text('PAGE_BRANCHE')),
            ),
          ],
        );

    Future<void> pumpProfile(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 4800);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final r = router();
      addTearDown(r.dispose);
      await pumpRouter(tester, r, database: database);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    testWidgets('« Mon assemblée », l\'assemblée choisie en sous-titre',
        (tester) async {
      await seed(tester, preferred: 1);
      await pumpProfile(tester);

      final tile = find.byKey(ProfileScreen.branchScopeKey);
      expect(
        find.descendant(of: tile, matching: find.text('Mon assemblée')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.text('Lomé')),
        findsOneWidget,
      );
    });

    testWidgets('sans choix : « Toutes les assemblées »', (tester) async {
      await seed(tester);
      await pumpProfile(tester);

      expect(
        find.descendant(
          of: find.byKey(ProfileScreen.branchScopeKey),
          matching: find.text('Toutes les assemblées'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('la toucher ouvre la page', (tester) async {
      await seed(tester);
      await pumpProfile(tester);

      await tester.tap(find.byKey(ProfileScreen.branchScopeKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('PAGE_BRANCHE'), findsOneWidget);
    });
  });
}
