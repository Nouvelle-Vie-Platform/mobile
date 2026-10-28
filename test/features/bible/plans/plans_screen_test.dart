/// **Les plans, à travers le vrai routeur** (M5, #203) : « Plus › Plans de
/// lecture », commencer un plan intégré, cocher la lecture du jour à la main,
/// la carte « Mon plan en cours » à l'accueil du module — en invité, sans un
/// octet sur le fil.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/features/bible/plans/plan_logic.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_providers.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_screen.dart';
import 'package:maison_du_miracle/features/bible/plans/plans_widgets.dart';
import 'package:maison_du_miracle/features/bible/shell/bible_shell.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/features/bible/home/home_view.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/guest_app.dart';

final Override _radioOff = radioRepositoryProvider.overrideWithValue(
  const FixedRadioRepository(RadioAntenna.unknown),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  late FakeAdapter wire;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    wire = FakeAdapter(
      (o) => throw StateError('requête HTTP interdite : ${o.method} ${o.path}'),
    );
    ApiClient.instance.dio.httpClientAdapter = wire;
  });

  testWidgets(
      'Accueil › Plans : commencer les Psaumes, cocher le jour, la carte',
      (tester) async {
    await tester.runAsync(() async {
      final container = guestContainer(extra: [
        _radioOff,
        bibleTodayProvider.overrideWithValue(DateTime(2026, 10, 13)),
      ]);
      final router = await pumpGuestApp(tester, container);
      router.push('/bible?tab=home');
      await _settle(tester);

      // La carte de l'accueil : Mon espace n'a plus de ligne Plans (#265).
      final card = find.byKey(BibleHomeKeys.shortcut('plans'));
      await tester.ensureVisible(card);
      await _settle(tester);
      await tester.tap(card);
      await _settle(tester);
      expect(find.byType(BiblePlansScreen), findsOneWidget);

      final ps = find.byKey(BiblePlansScreen.builtinKey(BuiltinPlanCode.ps30));
      await tester.scrollUntilVisible(ps, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(ps);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('bible_plans_start')));
      await _settle(tester);

      expect(find.byType(BiblePlanDetailScreen), findsOneWidget);
      expect(find.byKey(ChallengeBar.barKey), findsOneWidget);
      expect(find.byKey(BiblePlanDetailScreen.todayKey), findsOneWidget);

      final markDone = find.byKey(const Key('bible_plans_mark_done'));
      await tester.ensureVisible(markDone);
      await _settle(tester);
      await tester.tap(markDone);
      await _settle(tester);
      final db = container.read(appDatabaseProvider);
      final row = await db.select(db.localBiblePlanEnrollments).getSingle();
      expect(row.planCode, 'ps-30');
      expect(row.startedOn, '2026-10-13');
      expect(jsonDecode(row.completedDays!), [0]);
      expect(container.read(biblePlanReadingDoneTodayProvider), isTrue);

      // L'accueil du module montre le plan en cours.
      router.pop();
      await _settle(tester);
      router.pop();
      await _settle(tester);
      await tester.tap(find.byKey(BibleShell.tabKey(BibleModuleTab.home)));
      await _settle(tester);
      // Sous le corps de l'accueil (M7) : on descend jusqu'à elle.
      await tester.scrollUntilVisible(
        find.byKey(BiblePlanHomeCard.cardKey),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(BiblePlanHomeCard.cardKey), findsOneWidget);

      // Seul le geste « ouvert » du verset du jour (M7) est parti.
      expect(
        wire.requests.map((r) => r.path),
        everyElement(endsWith('/bible/verse-of-day/events')),
      );
    });
  });
}
