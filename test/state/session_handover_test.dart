/// **Ce qui se passe quand une session de membre s'ouvre — et quand elle se
/// ferme.**
///
/// Deux choses sont accrochées là, et une seule les accroche : la **fusion de la
/// progression d'écoute** et le **miroir de la préférence d'assemblée**. Trois
/// voies mènent à une session — code par SMS/e-mail, Google, Apple —, et le seul
/// invariant qui compte ici est qu'elles passent toutes par le même endroit. Deux
/// endroits qui réagissent, c'est une divergence annoncée : le jour où Google
/// cesse de lever `UnimplementedError`, sa connexion n'emporterait pas la
/// progression de l'invité, et personne ne s'en apercevrait — une progression
/// perdue ne lève rien.
///
/// Le versant fermeture est ici pour la même raison : **la déconnexion n'efface
/// rien**, décision explicite du client, et c'est le genre de règle qu'une
/// tranche voisine casse sans le vouloir.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/branch_scope/branch_scope_mirror.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/playback_dao.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/playback_progress_handover.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/branch_scope_providers.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/playback_doubles.dart';

const _content = '019f2c40-0000-7000-8000-000000000001';
const _localProgressId = '019f6b00-0000-7000-8000-0000000000ff';
const _accountProgressId = '019f6b00-0000-7000-8000-000000000001';

const _member = User(
  id: 'u_1',
  email: 'jean.kossi@email.com',
  firstName: 'Jean',
  status: UserStatus.newcomer,
  profileComplete: false,
);

/// Un invité qui devient membre, par l'une quelconque des **trois** voies.
///
/// `InMemoryAuthRepository` ne conviendrait pas : ses trois voies passent par des
/// délais simulés, et c'est l'ordre des appels qu'on regarde ici, pas leur durée.
class _Auth implements AuthRepository {
  User? user;

  Session _open() {
    user = _member;
    return const Session(token: 'oat_test', user: _member, isNewUser: false);
  }

  @override
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  }) async =>
      _open();

  @override
  Future<Session> signInWithGoogle() async => _open();

  @override
  Future<Session> signInWithApple() async => _open();

  @override
  Future<User?> cachedUser() async => user;

  @override
  Future<User?> currentUser() async => user;

  @override
  Future<void> rememberUser(User updated) async => user = updated;

  @override
  Future<void> signOut() async => user = null;

  @override
  Future<void> forgetSession() async => user = null;

  @override
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  }) async {}

  /// Aucun test de ce fichier ne supprime de compte : le double n'a qu'à
  /// satisfaire le contrat.
  @override
  Future<void> deleteAccount() async {}

  @override
  Future<User> updateProfile({
    UserTitle? title,
    String? firstName,
    String? lastName,
    int? branchId,
    UserStatus? status,
  }) =>
      throw UnimplementedError();
}

/// Miroir de compte qui compte ses lectures. C'est la seule façon de prouver que
/// `hydrateFromAccount` a bien été appelée — elle est muette et idempotente, elle
/// ne laisse aucune autre trace.
class _RecordingMirror implements BranchScopeMirror {
  int reads = 0;
  final List<int?> writes = [];

  @override
  Future<int?> read() async {
    reads++;
    return null;
  }

  @override
  Future<bool> write(int? branchId) async {
    writes.add(branchId);
    return true;
  }
}

/// Fusion qui **lève**, pour prouver qu'une connexion aboutit quand même.
class _ExplodingHandover implements PlaybackProgressHandover {
  @override
  Future<PlaybackHandoverReport> run() async =>
      throw StateError('fusion cassée');
}

void main() {
  late AppDatabase db;
  late PlaybackDao dao;
  late _Auth auth;
  late FakePlaybackProgressReporter reporter;
  late _RecordingMirror mirror;
  var pulls = 0;

  setUp(() {
    db = openTestDatabase();
    dao = db.playbackDao;
    auth = _Auth();
    reporter = FakePlaybackProgressReporter();
    mirror = _RecordingMirror();
    pulls = 0;
  });

  tearDown(() => db.close());

  /// Le conteneur de production, aux doubles près. Deux surcharges portent tout
  /// le poids de ce fichier :
  ///
  /// - [accountProgressPullProvider], parce que c'est le seul moyen d'exercer la
  ///   **vraie** fusion — vraie base, vrai DAO, vraie règle — sans ouvrir de
  ///   socket ;
  /// - [playbackProgressReporterProvider], pour la raison qui vaut partout
  ///   ailleurs : son défaut est l'implémentation HTTP dès que
  ///   `AppEnv.useBackend` est vrai, et il l'est hors surcharge.
  ProviderContainer container({
    PlaybackProgressHandover? handover,
    bool accountIsFresh = true,
  }) =>
      ProviderContainer.test(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          startupVaultProvider.overrideWithValue(StartupVault.noMemberSession),
          authRepositoryProvider.overrideWithValue(auth),
          playbackProgressReporterProvider.overrideWithValue(reporter),
          branchScopeMirrorProvider.overrideWithValue(mirror),
          accountProgressPullProvider.overrideWithValue(() async {
            pulls++;
            return accountIsFresh;
          }),
          if (handover != null)
            playbackProgressHandoverProvider.overrideWithValue(handover),
        ],
      );

  /// Ce qu'un invité a écouté : une position à chaud, et rien dans la collection
  /// répliquée — un porteur anonyme n'y a pas de ligne.
  Future<void> givenGuestProgress({int positionSeconds = 942}) {
    return dao.saveLocalPosition(
      contentId: _content,
      progressId: _localProgressId,
      positionSeconds: positionSeconds,
      at: DateTime.utc(2026, 9, 27, 10),
    );
  }

  Future<void> givenAccountProgress({
    required int positionSeconds,
    DateTime? updatedAt,
  }) {
    return db.syncDao.applyPage(
      db.syncDao.playbackProgressCollection,
      upserts: [
        PlaybackProgressCompanion.insert(
          id: _accountProgressId,
          teachingId: _content,
          positionSeconds: positionSeconds,
          updatedAt: Value(updatedAt ?? DateTime.utc(2026, 5, 24, 14, 31)),
        ),
      ],
      cursor: 'c-progress',
    );
  }

  /// Les **trois** voies, et rien qui les distingue de ce point de vue-ci.
  final voies = <String, Future<Session> Function(AuthController)>{
    'le code par SMS/e-mail': (controller) => controller.verifyCode(
          identifier: 'jean.kossi@email.com',
          code: '123456',
        ),
    'Google': (controller) => controller.signInWithGoogle(),
    'Apple': (controller) => controller.signInWithApple(),
  };

  group('À la connexion, la progression invitée part vers le compte', () {
    for (final voie in voies.entries) {
      test('par ${voie.key}', () async {
        await givenGuestProgress();
        final scope = container();
        final controller = scope.read(authProvider.notifier);

        await voie.value(controller);
        // L'adoption n'est **pas** attendue par l'application — entrer ne doit
        // pas dépendre d'un aller-retour réseau. Un test, lui, l'attend plutôt
        // que de deviner un nombre de tours de boucle.
        await controller.adoption;

        expect(scope.read(authProvider).isAuthenticated, isTrue);
        expect(reporter.reports, hasLength(1));
        expect(reporter.reports.single.contentId, _content);
        expect(reporter.reports.single.positionSeconds, 942);
        expect(pulls, 1);
      });
    }

    test('et un invité, lui, ne pousse rien', () async {
      await givenGuestProgress();
      final scope = container();
      scope.read(authProvider);
      await Future<void>.delayed(Duration.zero);

      expect(scope.read(authProvider).isGuest, isTrue);
      expect(reporter.reports, isEmpty);
      expect(pulls, 0);
    });
  });

  group('La connexion aboutit, quoi qu\'il arrive à la fusion', () {
    test('une poussée qui ne part pas laisse entrer quand même', () async {
      await givenGuestProgress();
      reporter.delivered = false;
      final scope = container();
      final controller = scope.read(authProvider.notifier);

      final session = await controller.verifyCode(
        identifier: 'jean.kossi@email.com',
        code: '123456',
      );
      await controller.adoption;

      expect(session.user.id, 'u_1');
      expect(scope.read(authProvider).isAuthenticated, isTrue);
      // Elle a été tentée, et elle repartira à la prochaine ouverture de
      // session : la position est toujours en local, personne ne l'a effacée.
      expect(reporter.reports, hasLength(1));
      expect((await dao.localPositionFor(_content))?.positionSeconds, 942);
    });

    test('une fusion qui lève ne renvoie personne à l\'écran de connexion',
        () async {
      await givenGuestProgress();
      final scope = container(handover: _ExplodingHandover());
      final controller = scope.read(authProvider.notifier);

      await controller.verifyCode(
        identifier: 'jean.kossi@email.com',
        code: '123456',
      );
      await controller.adoption;

      expect(scope.read(authProvider).isAuthenticated, isTrue);
    });

    test('un cycle de synchronisation qui échoue ne pousse rien', () async {
      // Ne rien faire perd une commodité ; pousser sans savoir ce que le compte
      // porte ferait peut-être reculer une reprise.
      await givenGuestProgress();
      final scope = container(accountIsFresh: false);
      final controller = scope.read(authProvider.notifier);

      await controller.signInWithApple();
      await controller.adoption;

      expect(scope.read(authProvider).isAuthenticated, isTrue);
      expect(reporter.reports, isEmpty);
    });
  });

  group('Le miroir de la préférence d\'assemblée', () {
    test('est consulté à l\'ouverture d\'une session de membre', () async {
      final scope = container();
      final controller = scope.read(authProvider.notifier);

      await controller.signInWithGoogle();
      await controller.adoption;

      // `hydrateFromAccount()` existait, était testée, et n'avait **aucun
      // appelant** : le miroir ne servait à personne en production.
      expect(mirror.reads, 1);
    });

    test('et ne part jamais pour un invité', () async {
      final scope = container();
      scope.read(authProvider);
      await Future<void>.delayed(Duration.zero);

      expect(scope.read(authProvider).isGuest, isTrue);
      expect(mirror.reads, 0);
    });
  });

  group('La déconnexion n\'efface rien', () {
    test('la progression redevient simplement locale', () async {
      // Décision explicite du client, assumée y compris sur un téléphone
      // partagé. Prouvée en **relisant une position**, pas affirmée : la
      // collection répliquée cesse d'être alimentée, la table locale répond.
      await givenAccountProgress(positionSeconds: 600);
      await givenGuestProgress(positionSeconds: 942);
      final scope = container();
      final controller = scope.read(authProvider.notifier);
      await controller.signInWithGoogle();
      await controller.adoption;

      await controller.signOut();

      expect(scope.read(authProvider).isGuest, isTrue);
      final resume = await dao.resumeFor(_content);
      expect(resume, isNotNull);
      expect(resume!.positionSeconds, 942);
      expect(
        resume.source,
        PlaybackResumeSource.local,
        reason: 'c\'est la table locale seule qui répond, désormais',
      );
      // Et la ligne répliquée est toujours là : le client n'efface jamais de sa
      // propre initiative une ligne d'une collection synchronisée.
      expect(await dao.syncedProgressFor(_content), isNotNull);
    });
  });
}
