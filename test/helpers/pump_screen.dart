import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';

/// Monte un écran isolé dans un environnement minimal (ProviderScope + thème).
///
/// Utilise `pump()` (et non `pumpAndSettle`) car certains écrans affichent des
/// animations infinies (ex. le spinner du splash) qui ne se stabilisent jamais.
///
/// [overrides] permet d'injecter des providers de test (ex. un faux
/// repository) pour vérifier le câblage des données. Ils sont appliqués
/// **après** les repli ci-dessous, et peuvent donc les remplacer.
///
/// Les repositories d'auth et de branches sont forcés sur leurs
/// implémentations **en mémoire** : les versions HTTP ouvriraient une socket
/// dès le montage (`GET /auth/me`, `GET /sync/branches`) et `flutter test`
/// répond **400 à tout accès réseau**.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
        branchRepositoryProvider
            .overrideWithValue(const InMemoryBranchRepository()),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pump();
  // Laisse expirer les minuteries de résolution de session (mock ~300 ms, via
  // `authProvider`) pour éviter les « pending timer » au teardown. On avance
  // l'horloge plutôt que `pumpAndSettle` (certains écrans animent à l'infini).
  await tester.pump(const Duration(seconds: 1));
}
