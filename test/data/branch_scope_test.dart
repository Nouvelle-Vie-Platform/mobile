/// **La préférence de branche : où elle vit, et comment elle voyage.**
///
/// Trois affirmations à tenir, et la troisième est celle qui se casse en silence
/// si l'on inverse une priorité :
///
/// 1. **elle survit à un redémarrage**, parce qu'elle vit dans `app_settings`,
///    donc dans le fichier de base — et un invité en dispose, sans compte ;
/// 2. **un membre la retrouve depuis son compte** sur un appareil qui n'a jamais
///    choisi. C'est à ça, et à rien d'autre, que sert la colonne
///    `preferredBranchId` : le serveur filtre sur le **paramètre de la requête**,
///    jamais sur elle ;
/// 3. **la décision locale gagne toujours.** Un miroir qui aurait autorité
///    défèrerait le geste qu'on vient de poser dès que sa recopie a échoué — et
///    l'échec de recopie est le cas normal, pas l'exception : hors ligne, c'est
///    le seul cas.
library;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/branch_scope/branch_scope.dart';
import 'package:maison_du_miracle/data/branch_scope/branch_scope_mirror.dart';
import 'package:maison_du_miracle/data/branch_scope/branch_scope_store.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/sync/branch_filter.dart';

import '../helpers/fake_api.dart';
import 'local/local_database_fixtures.dart';

void main() {
  group('Le magasin local', () {
    late AppDatabase db;
    late BranchScopeStore store;

    setUp(() {
      db = openTestDatabase();
      addTearDown(db.close);
      store = BranchScopeStore(db);
    });

    test('rien de choisi = toutes les branches, et aucune ligne écrite',
        () async {
      // L'absence de ligne **est** le défaut, comme pour les réglages média :
      // une valeur écrite d'office serait indiscernable d'un choix, et changer le
      // défaut plus tard ne toucherait plus personne.
      expect(await db.select(db.appSettings).get(), isEmpty);
      expect(await store.read(), isNull);
      expect(await store.hasChoice(), isFalse);
    });

    test('la préférence survit à un redémarrage', () async {
      await store.choose(4);

      // Une autre instance sur la même base : c'est ce que voit l'application
      // relancée. Le réglage n'a besoin d'aucun réseau pour être retrouvé, ce qui
      // est le point — un invité n'a pas de compte où le chercher.
      expect(await BranchScopeStore(db).read(), 4);
      expect(await BranchScopeStore(db).hasChoice(), isTrue);
    });

    test('« toutes » explicitement choisi s\'écrit, et se distingue du vide',
        () async {
      await store.choose(4);
      await store.choose(null);

      // Sur le fil, les deux se comportent pareil (aucun `branch_id`). Mais seul
      // « je n'ai jamais choisi » autorise à adopter ce que le compte propose : la
      // ligne écrite est ce qui garde la distinction disponible.
      expect(await store.read(), isNull);
      expect(await store.hasChoice(), isTrue);
    });

    test('une valeur illisible vaut « toutes », jamais une exception',
        () async {
      await db.settingsDao.setPendingPlays('sans rapport');
      await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(
              key: 'preferred_branch_id',
              value: 'Kpalimé',
            ),
          );

      // La panne va du côté **large** : une base bricolée ne doit pas vider le
      // catalogue de quelqu'un, parce qu'un catalogue vide ne se plaint pas.
      expect(await store.read(), isNull);
    });

    test('poser une préférence marque les quatre collections à remplacer',
        () async {
      expect(await store.choose(4), isTrue);

      for (final key in kBranchScopedCollections) {
        expect(await db.syncDao.resyncToken(key), isNotNull, reason: key);
      }
      // La liste des jetons a exactement la taille du registre : pas un de plus.
      expect(
        await db.select(db.resyncTokens).get(),
        hasLength(kBranchScopedCollections.length),
      );
    });
  });

  group('Le miroir du compte', () {
    late FakeAdapter adapter;
    late ApiClient api;
    late HttpBranchScopeMirror mirror;

    void serve(ResponseBody Function(RequestOptions options) reply) {
      adapter = FakeAdapter(reply);
      api.dio.httpClientAdapter = adapter;
    }

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'jeton-de-membre',
        'auth_token_kind': 'member',
      });
      api = ApiClient.instance;
      mirror = HttpBranchScopeMirror(client: api);
    });

    test('la lecture prend `preferredBranchId` sur `GET /auth/me`', () async {
      serve((_) => jsonReply(200, {...userPayload, 'preferredBranchId': 3}));

      expect(await mirror.read(), 3);
      expect(adapter.lastRequest.path, '/auth/me');
    });

    test('un compte sans préférence rend `null`, pas zéro', () async {
      serve((_) => jsonReply(200, userPayload));

      expect(await mirror.read(), isNull);
    });

    test('l\'écriture passe par `PUT /auth/profile`, en camelCase', () async {
      serve((_) => jsonReply(200, userPayload));

      expect(await mirror.write(3), isTrue);
      expect(adapter.lastRequest.method, 'PUT');
      expect(adapter.lastRequest.path, '/auth/profile');
      // `camelCase` : c'est un **corps** d'API. Le `snake_case` du `branch_id` de
      // `/sync` est celui des query strings et du protocole delta ; les confondre
      // donnerait un champ que VineJS refuserait, en silence puisque l'appel est
      // muet.
      expect(adapter.lastBody, {'preferredBranchId': 3});
    });

    test('« toutes » s\'écrit explicitement `null`, il ne s\'omet pas',
        () async {
      serve((_) => jsonReply(200, userPayload));

      await mirror.write(null);
      // L'omission signifierait « je n'y touche pas » — la convention de
      // `updateProfile` pour `branchId`. Le compte garderait alors pour toujours
      // la dernière branche choisie, et « toutes les branches » serait
      // impossible à recopier.
      expect(adapter.lastBody.containsKey('preferredBranchId'), isTrue);
      expect(adapter.lastBody['preferredBranchId'], isNull);
    });

    test('un porteur d\'appareil n\'appelle pas ces routes', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'jeton-appareil',
        'auth_token_kind': 'device',
      });
      serve((_) => jsonReply(200, userPayload));

      expect(await mirror.read(), isNull);
      expect(await mirror.write(3), isFalse);
      // Aucune requête : un 401 sur un porteur d'appareil déclencherait un
      // renouvellement de jeton **et** un rejeu, soit deux requêtes de plus pour
      // un échec certain. Un invité n'a pas de compte où retrouver son réglage,
      // et son réglage n'en a pas besoin.
      expect(adapter.requests, isEmpty);
    });

    test('sans jeton du tout, rien ne part', () async {
      FlutterSecureStorage.setMockInitialValues({});
      serve((_) => jsonReply(200, userPayload));

      expect(await mirror.read(), isNull);
      expect(adapter.requests, isEmpty);
    });

    test('le miroir est muet : ni exception, ni détail', () async {
      serve((_) => errorReply(500, 'E_INTERNAL_SERVER_ERROR'));

      expect(await mirror.read(), isNull);
      expect(await mirror.write(3), isFalse);
      // Visible au diagnostic seulement — sans ce témoin, un miroir qui ne
      // miroiterait plus rien passerait pour un miroir discret.
      expect(mirror.lastFailure, isNotNull);
    });
  });

  group('La façade', () {
    late AppDatabase db;
    late BranchScopeStore store;
    late _RecordingMirror mirror;
    late int cycles;
    late BranchScope scope;

    setUp(() {
      db = openTestDatabase();
      addTearDown(db.close);
      store = BranchScopeStore(db);
      mirror = _RecordingMirror();
      cycles = 0;
      scope = BranchScope(
        store: store,
        mirror: mirror,
        resynchronize: () async => cycles++,
      );
    });

    test('choisir pose la préférence, resynchronise, puis met au miroir',
        () async {
      await scope.choose(4);

      expect(await store.read(), 4);
      expect(cycles, 1);
      expect(mirror.written, [4]);
      for (final key in kBranchScopedCollections) {
        expect(await db.syncDao.resyncToken(key), isNotNull, reason: key);
      }
    });

    test('un choix identique ne resynchronise pas et ne rappelle pas le compte',
        () async {
      await scope.choose(4);
      await scope.choose(4);

      expect(cycles, 1);
      expect(mirror.written, [4]);
    });

    test('une resynchronisation qui échoue ne perd pas le réglage', () async {
      scope = BranchScope(
        store: store,
        mirror: mirror,
        resynchronize: () async => throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/sync'),
          reason: 'avion',
        ),
      );

      await scope.choose(4);

      // Le réglage est **acquis au premier temps**, qui est local. Le jeton de
      // resync survit, et le remplacement se fera au premier cycle qui
      // aboutira — c'est tout son intérêt.
      expect(await store.read(), 4);
      expect(await db.syncDao.resyncToken('teachings'), isNotNull);
    });

    test('un appareil neuf adopte la branche du compte', () async {
      mirror.remote = 7;

      await scope.hydrateFromAccount();

      // Le cas « autre appareil » et le cas « réinstallation » : c'est à ça que
      // sert la colonne. Et l'adoption passe par `choose`, donc **avec** la
      // remise à zéro des curseurs — sinon le catalogue resterait celui du
      // périmètre large.
      expect(await store.read(), 7);
      expect(await db.syncDao.resyncToken('announcements'), isNotNull);
      expect(cycles, 1);
    });

    test('un appareil qui a déjà choisi ne se fait pas corriger', () async {
      await scope.choose(4);
      mirror.remote = 7;
      cycles = 0;

      await scope.hydrateFromAccount();

      // La décision locale gagne. Sans cette règle, un réglage posé hors ligne
      // — donc jamais recopié — serait annulé à la réouverture du panneau, et
      // le fidèle verrait son geste défait sans explication.
      expect(await store.read(), 4);
      expect(cycles, 0);
    });

    test('réglé en invité puis connecté : la préférence remonte au compte',
        () async {
      await scope.choose(4);
      mirror
        ..written.clear()
        ..remote = null;

      await scope.hydrateFromAccount();

      // L'autre moitié de la règle. Sans elle, se connecter laisserait le
      // réglage d'un invité local pour toujours, et lui ferait croire que son
      // église ne le suit pas d'un appareil à l'autre.
      expect(mirror.written, [4]);
      expect(await store.read(), 4);
    });

    test('un compte vide n\'écrase pas un « toutes » choisi ici', () async {
      await scope.choose(null);
      mirror.written.clear();

      await scope.hydrateFromAccount();

      expect(await store.read(), isNull);
      // Rien à remonter : « toutes » recopié est déjà un `null`, et le compte en
      // porte un.
      expect(mirror.written, isEmpty);
    });

    test('oublier une branche morte la retire aussi du compte', () async {
      await scope.choose(4);
      mirror.written.clear();

      await scope.forget();

      expect(await store.read(), isNull);
      // Sans cette recopie, le prochain démarrage irait rechercher la même
      // branche morte dans le compte et rejouerait le même 422, indéfiniment.
      expect(mirror.written, [null]);
    });
  });
}

/// Miroir qui retient ce qu'on lui écrit et rend ce qu'on lui pose.
class _RecordingMirror implements BranchScopeMirror {
  int? remote;
  final List<int?> written = [];

  @override
  Future<int?> read() async => remote;

  @override
  Future<bool> write(int? branchId) async {
    written.add(branchId);
    remote = branchId;
    return true;
  }
}
