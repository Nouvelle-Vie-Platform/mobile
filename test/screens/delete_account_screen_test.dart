import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Key, Scrollable, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/screens/delete_account_screen.dart';
import 'package:maison_du_miracle/widgets/app_button.dart';

import '../helpers/pump_screen.dart';

/// Un dépôt d'auth qui compte les suppressions et peut les faire échouer.
class _SpyAuthRepository extends InMemoryAuthRepository {
  _SpyAuthRepository({this.failure});

  final Object? failure;
  int deleteCalls = 0;

  @override
  Future<User?> cachedUser() async => User(
        id: 'u_1',
        firstName: 'Fabrice',
        status: UserStatus.affiliated,
        profileComplete: true,
      );

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (failure != null) throw failure!;
  }
}

void main() {
  late AppDatabase database;
  late _SpyAuthRepository auth;

  Future<void> pump(WidgetTester tester, {Object? failure}) async {
    // Un écran de téléphone réel : sous le 800×600 par défaut du harnais, le
    // bouton tombe hors du viewport et `tap()` refuse de le toucher.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    auth = _SpyAuthRepository(failure: failure);
    await pumpScreen(
      tester,
      const DeleteAccountScreen(),
      database: database,
      auth: auth,
    );
  }

  /// Le bouton vit en bas d'un `ListView` **paresseux** : hors viewport, il
  /// n'est pas construit du tout. Chaque test doit donc l'amener à l'écran
  /// avant de le lire ou de le toucher.
  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  /// Coche la case puis touche le bouton, en amenant chacun à l'écran d'abord.
  Future<void> confirmAndSubmit(WidgetTester tester) async {
    await reveal(tester, DeleteAccountScreen.confirmKey);
    await tester.tap(find.byKey(DeleteAccountScreen.confirmKey));
    await tester.pump();
    await reveal(tester, DeleteAccountScreen.submitKey);
    await tester.tap(find.byKey(DeleteAccountScreen.submitKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  AppButton submit(WidgetTester tester) =>
      tester.widget<AppButton>(find.byKey(DeleteAccountScreen.submitKey));

  group('Écran de suppression de compte', () {
    testWidgets('le bouton est inerte tant que la case n\'est pas cochée',
        (tester) async {
      await pump(tester);
      await reveal(tester, DeleteAccountScreen.submitKey);

      // L'unique garde-fou de l'écran : sans lui, une route poussée par
      // erreur suffirait à tout perdre d'un seul toucher.
      expect(submit(tester).onPressed, isNull);

      await reveal(tester, DeleteAccountScreen.confirmKey);
      await tester.tap(find.byKey(DeleteAccountScreen.confirmKey));
      await tester.pump();
      await reveal(tester, DeleteAccountScreen.submitKey);

      expect(submit(tester).onPressed, isNotNull);
    });

    testWidgets('cocher puis valider supprime, et efface le magasin',
        (tester) async {
      await pump(tester);
      await database.into(database.syncCursors).insert(
            SyncCursorsCompanion.insert(
              collection: 'teachings',
              syncedAt: DateTime.utc(2026, 8, 14),
            ),
          );

      await confirmAndSubmit(tester);

      expect(auth.deleteCalls, 1);
      expect(await database.select(database.syncCursors).get(), isEmpty);
    });

    testWidgets('une panne laisse tout en place et garde la main',
        (tester) async {
      await pump(
        tester,
        failure: AuthException(AuthErrorCode.network, null),
      );
      await database.into(database.syncCursors).insert(
            SyncCursorsCompanion.insert(
              collection: 'teachings',
              syncedAt: DateTime.utc(2026, 8, 14),
            ),
          );

      await confirmAndSubmit(tester);

      // Le compte est toujours vivant côté serveur : effacer le téléphone
      // laisserait quelqu'un convaincu d'avoir disparu alors qu'il est inscrit.
      expect(
        await database.select(database.syncCursors).get(),
        isNotEmpty,
        reason:
            'le magasin ne doit rien perdre quand le serveur n\'a rien fait',
      );
      // L'écran reste, et il dit pourquoi.
      expect(find.byKey(DeleteAccountScreen.submitKey), findsOneWidget);
      expect(submit(tester).loading, isFalse);
    });
  });
}
