import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/http_auth_repository.dart';

import '../helpers/fake_api.dart';
import 'local/local_database_fixtures.dart';

void main() {
  group('DELETE /auth/me — le contrat', () {
    late FakeAdapter adapter;
    late HttpAuthRepository repository;
    late ApiClient api;

    void serve(ResponseBody Function(RequestOptions options) reply) {
      adapter = FakeAdapter(reply);
      api.dio.httpClientAdapter = adapter;
    }

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      api = ApiClient.instance;
      repository = HttpAuthRepository(client: api);
      serve((_) => jsonReply(204, null));
    });

    test('part en DELETE sur /auth/me, sans corps ni paramètre', () async {
      await repository.deleteAccount();

      expect(adapter.lastRequest.method, 'DELETE');
      expect(adapter.lastRequest.path, '/auth/me');
      expect(adapter.lastRequest.data, isNull);
      // Aucun identifiant nulle part : c'est ce qui rend cette route incapable
      // de supprimer quelqu'un d'autre.
      expect(adapter.lastRequest.queryParameters, isEmpty);
    });

    test('un 401 compte comme un succès', () async {
      // Le serveur révoque tous les tokens dans la transaction : un second
      // appel, ou un token qui venait d'expirer, reçoit 401. Il n'existe pas
      // d'état « déjà supprimé » à distinguer — dans les deux cas il n'y a plus
      // de session, et l'appelant doit pouvoir enchaîner sur l'effacement.
      serve((_) => errorReply(401, 'E_UNAUTHORIZED_ACCESS'));

      await expectLater(repository.deleteAccount(), completes);
    });

    test('une panne réseau lève — le compte est encore vivant', () async {
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'pas de réseau',
          ));

      // C'est ce qui empêche d'effacer le téléphone d'un compte qui existe
      // toujours : quelqu'un se croirait disparu alors qu'il est inscrit.
      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', AuthErrorCode.network)),
      );
    });

    test('un 500 lève aussi', () async {
      serve((_) => errorReply(500, 'E_INTERNAL_SERVER_ERROR'));

      await expectLater(
        repository.deleteAccount(),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('eraseEverything — la contrepartie locale', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
    });

    /// Un magasin qui ressemble à celui d'un fidèle : du catalogue, sa
    /// progression d'écoute (répliquée **et** locale seule), et des curseurs.
    Future<void> seed() async {
      await db.into(db.teachings).insert(teachingRow('t-1'));
      await db.into(db.playbackProgress).insert(
            PlaybackProgressCompanion.insert(
              id: 'p-1',
              teachingId: 't-1',
              positionSeconds: 1200,
            ),
          );
      await db.into(db.localPlaybackPositions).insert(
            LocalPlaybackPositionsCompanion.insert(
              contentId: 't-1',
              progressId: 'p-1',
              positionSeconds: 1200,
              updatedAt: DateTime.utc(2026, 8, 14),
            ),
          );
      await db.into(db.syncCursors).insert(
            SyncCursorsCompanion.insert(
              collection: 'teachings',
              cursor: const Value('un-curseur-opaque'),
              syncedAt: DateTime.utc(2026, 8, 14),
            ),
          );
    }

    test('vide les lignes ET les curseurs, et repose l\'état global', () async {
      await seed();

      // Garde-fou du test lui-même : sans données, il ne prouverait rien.
      expect(await db.select(db.teachings).get(), isNotEmpty);
      expect(await db.select(db.playbackProgress).get(), isNotEmpty);
      expect(await db.select(db.syncCursors).get(), isNotEmpty);

      await db.eraseEverything();

      expect(await db.select(db.teachings).get(), isEmpty);
      // La progression d'écoute est le cœur du sujet : le serveur l'a effacée
      // de son côté, il n'enverra donc **jamais** de rétraction pour la retirer
      // d'ici. Si elle survit, la personne suivante reprend un prêche là où la
      // précédente s'était arrêtée.
      expect(await db.select(db.playbackProgress).get(), isEmpty);
      expect(await db.select(db.localPlaybackPositions).get(), isEmpty);
      expect(
        await db.select(db.syncCursors).get(),
        isEmpty,
        reason: 'un curseur qui survit à ses lignes est un trou permanent : le '
            'manifeste répondrait « rien de neuf » et la collection ne se '
            'remplirait plus jamais',
      );

      // La ligne d'état global doit repartir : sans elle, la première
      // allocation de jeton d'écriture du compte suivant lèverait.
      final state = await db.select(db.syncState).get();
      expect(state, hasLength(1));
      expect(state.single.scopeVersion, isNull);
    });
  });
}
