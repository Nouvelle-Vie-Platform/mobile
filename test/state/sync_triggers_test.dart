import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/app.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/sync_scheduler.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../helpers/pump_screen.dart';

/// **Les trois déclencheurs, vus depuis l'application** — et non depuis le
/// planificateur.
///
/// `test/sync/sync_scheduler_test.dart` prouve que `SyncScheduler` réagit aux
/// trois. Ça ne dit rien de ce qui compte ici : que *quelqu'un* l'appelle. Un
/// déclencheur non câblé ne casse aucun test de socle et ne lève rien à
/// l'exécution — il laisse simplement le magasin en l'état, et un magasin qui
/// ne se remplit pas est une application **muette**, pas une erreur visible.
void main() {
  const report = SyncReport(
    pulled: [],
    resynced: [],
    skipped: [],
    untouched: [],
    pages: 0,
    scopeVersion: null,
  );

  group('Ouverture et retour au premier plan', () {
    testWidgets('l\'application lance un cycle à son premier frame',
        (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      var cycles = 0;
      final scheduler = SyncScheduler(() async {
        cycles++;
        return report;
      });
      addTearDown(scheduler.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncSchedulerProvider.overrideWithValue(scheduler)],
          child: const MaisonDuMiracleApp(),
        ),
      );
      await tester.pump();

      expect(cycles, 1);
      expect(scheduler.lastTrigger, SyncTrigger.appStart);

      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
        'le retour au premier plan en lance un second : l\'abonnement au '
        'cycle de vie survit au premier frame', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      var cycles = 0;
      final scheduler = SyncScheduler(() async {
        cycles++;
        return report;
      });
      addTearDown(scheduler.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncSchedulerProvider.overrideWithValue(scheduler)],
          child: const MaisonDuMiracleApp(),
        ),
      );
      await tester.pump();
      expect(cycles, 1);

      // L'application part en arrière-plan, puis revient. C'est le vrai chemin
      // — le cycle de vie passe par la liaison, pas par un appel direct au
      // planificateur : c'est ce qui vérifie que `start()` l'a bien abonné, et
      // que le provider (non `autoDispose`) l'a gardé en vie.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(cycles, 1, reason: 'partir en arrière-plan ne synchronise pas');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(cycles, 2);
      expect(scheduler.lastTrigger, SyncTrigger.foreground);

      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('Tirer-pour-rafraîchir, depuis la médiathèque', () {
    /// Tire l'écran vers le bas et laisse l'indicateur aller au bout de son
    /// animation (apparition, maintien, disparition).
    Future<void> pullDown(WidgetTester tester, Finder scrollable) async {
      await tester.fling(scrollable, const Offset(0, 320), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('tirer sur le catalogue déclenche un cycle', (tester) async {
      var pulls = 0;
      await pumpScreen(
        tester,
        const MediaLibraryScreen(),
        overrides: [
          pullToRefreshProvider.overrideWithValue(() async => pulls++),
        ],
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
      // La liste du catalogue est désormais un `ListView` et non un
      // `CustomScrollView` : l'écran ne porte plus trois sections empilées en
      // slivers, il porte **une** liste (#82). Et c'est la seule ici — la barre
      // d'onglets n'existe pas sans menu, et le double en mémoire en rend un vide.
      await pullDown(tester, find.byType(ListView));

      expect(pulls, 1);
    });

    testWidgets(
        'le geste existe aussi sur un catalogue **vide** — c\'est là qu\'il '
        'sert', (tester) async {
      var pulls = 0;
      await pumpScreen(
        tester,
        const MediaLibraryScreen(),
        // Premier lancement : la synchronisation d'ouverture est tombée sur un
        // réseau absent, le magasin est vide. Un état centré et immobile
        // n'aurait offert aucune prise pour redemander.
        mediatheque: InMemoryMediathequeRepository(teachings: [], types: []),
        overrides: [
          pullToRefreshProvider.overrideWithValue(() async => pulls++),
        ],
      );

      await pullDown(tester, find.byType(SingleChildScrollView));

      expect(pulls, 1);
    });
  });
}
