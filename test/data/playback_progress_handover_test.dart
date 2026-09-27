/// **La fusion de la progression à la connexion : la position la plus avancée
/// gagne.**
///
/// Ce fichier garde une règle que personne ne signalera si elle casse. Une
/// position qui **recule** ne lève rien, ne s'affiche pas, ne se journalise pas :
/// un fidèle rouvre un prêche et se retrouve dix minutes trop tôt, met ça sur le
/// compte de l'application, et refait défiler à la main. C'est exactement le
/// genre de défaut qui survit à une revue de code et à un test manuel.
///
/// Et rien, côté serveur, ne rattrapera l'erreur : son upsert écrit la position
/// reçue **sans la comparer** (vérifié dans `server-portal` —
/// `app/mediatheque/actions/report_playback_progress.ts` et
/// `app/shared/repositories/owned_content_repository.ts`). C'est ce qui rend ces
/// tests-ci nécessaires plutôt que défensifs ; ils pourront disparaître avec un
/// upsert monotone côté serveur (issue #421), pas avant.
///
/// Trois affirmations à tenir, et la troisième est celle qui se casse en silence
/// si l'on inverse un ordre :
///
/// 1. ce que le compte ignore **part** ;
/// 2. ce que le compte sait mieux **ne repart pas**, et ne le fait pas reculer ;
/// 3. l'arbitrage se fait sur une collection répliquée **fraîchement tirée**. Le
///    même code, comparant aux positions d'**avant** le cycle, pousserait une
///    position en retard sans qu'aucun de ces tests ne rougisse — sauf celui qui
///    fait arriver la ligne du compte *pendant* le cycle.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/playback_dao.dart';
import 'package:maison_du_miracle/data/repositories/playback_progress_handover.dart';
import 'package:maison_du_miracle/data/repositories/playback_progress_reporter.dart';

import 'local/local_database_fixtures.dart';

/// Rapporteur pilotable : il retient ce qui part, et le test décide de ce qui
/// n'arrive pas.
class _ScriptedReporter implements PlaybackProgressReporter {
  /// Ce qui a été **tenté**, dans l'ordre — refus compris.
  final List<PlaybackProgressReport> reports = [];

  /// Contenus dont le rapport « ne part pas » (hors ligne, 5xx).
  final Set<String> refuse = {};

  /// Contenus pour lesquels le rapporteur **lève** — ce qu'aucune
  /// implémentation ne fait, et dont la fusion doit se relever quand même.
  final Set<String> explode = {};

  @override
  Future<bool> report(PlaybackProgressReport report) async {
    if (explode.contains(report.contentId)) {
      throw StateError('rapporteur cassé');
    }
    reports.add(report);
    return !refuse.contains(report.contentId);
  }
}

void main() {
  const content = '019f2c40-0000-7000-8000-000000000001';
  const otherContent = '019f2c40-0000-7000-8000-000000000002';
  const accountProgressId = '019f6b00-0000-7000-8000-000000000001';
  const localProgressId = '019f6b00-0000-7000-8000-0000000000ff';
  final accountUpdatedAt = DateTime.utc(2026, 5, 24, 14, 31);

  late AppDatabase db;
  late PlaybackDao dao;
  late _ScriptedReporter reporter;

  /// Combien de fois la fusion a demandé un cycle de synchronisation.
  var pulls = 0;

  setUp(() {
    db = openTestDatabase();
    dao = db.playbackDao;
    reporter = _ScriptedReporter();
    pulls = 0;
  });

  tearDown(() => db.close());

  /// La ligne **répliquée**, posée comme la synchronisation la pose — par
  /// `SyncDao`, jamais par le DAO de lecture, qui n'a aucune écriture vers cette
  /// table (et c'est le garde-fou de la règle 4 du moteur).
  Future<void> givenAccountProgress({
    String id = accountProgressId,
    String teachingId = content,
    required int positionSeconds,
    bool completed = false,
    DateTime? updatedAt,
  }) {
    return db.syncDao.applyPage(
      db.syncDao.playbackProgressCollection,
      upserts: [
        PlaybackProgressCompanion.insert(
          id: id,
          teachingId: teachingId,
          positionSeconds: positionSeconds,
          completed: Value(completed),
          updatedAt: Value(updatedAt ?? accountUpdatedAt),
        ),
      ],
      cursor: 'c-progress',
    );
  }

  /// La position **à chaud**, telle que le lecteur l'écrit — pour un invité comme
  /// pour un membre : la table ne distingue pas les deux, et ne peut pas.
  Future<void> givenLocalPosition({
    String contentId = content,
    String progressId = localProgressId,
    required int positionSeconds,
    bool completed = false,
  }) {
    return dao.saveLocalPosition(
      contentId: contentId,
      progressId: progressId,
      positionSeconds: positionSeconds,
      completed: completed,
      at: DateTime.utc(2026, 9, 27, 10),
    );
  }

  /// La fusion, avec un cycle de synchronisation simulé.
  ///
  /// [fresh] = le cycle a abouti. [duringPull] est ce que le cycle **ramène** :
  /// c'est le seul moyen de prouver que la comparaison se fait sur les positions
  /// d'après le tirage.
  StorePlaybackProgressHandover handover({
    bool fresh = true,
    Future<void> Function()? duringPull,
  }) {
    return StorePlaybackProgressHandover(
      dao: dao,
      reporter: reporter,
      pullAccountProgress: () async {
        pulls++;
        await duringPull?.call();
        return fresh;
      },
    );
  }

  group('La règle, sans base ni réseau', () {
    PlaybackHandover candidate({
      required int local,
      bool localCompleted = false,
      int? account,
      bool accountCompleted = false,
    }) {
      return PlaybackHandover(
        contentId: content,
        progressId: localProgressId,
        localPositionSeconds: local,
        localCompleted: localCompleted,
        accountPositionSeconds: account,
        accountCompleted: accountCompleted,
      );
    }

    test('le compte ne sait rien : tout ce qui a été écouté est du gain', () {
      expect(
        verdictFor(candidate(local: 942)),
        PlaybackMergeVerdict.handOver,
      );
    });

    test('un contenu ouvert puis refermé ne vaut pas un aller-retour', () {
      expect(verdictFor(candidate(local: 0)), PlaybackMergeVerdict.agreed);
    });

    test('la plus avancée gagne, dans les deux sens', () {
      expect(
        verdictFor(candidate(local: 900, account: 300)),
        PlaybackMergeVerdict.handOver,
      );
      expect(
        verdictFor(candidate(local: 300, account: 900)),
        PlaybackMergeVerdict.raiseLocal,
      );
      expect(
        verdictFor(candidate(local: 900, account: 900)),
        PlaybackMergeVerdict.agreed,
      );
    });

    test('le compte a terminé : plus rien ne se rapporte', () {
      final finished = candidate(
        local: 1000,
        account: 900,
        accountCompleted: true,
      );

      expect(verdictFor(finished), PlaybackMergeVerdict.raiseLocal);
      // …et relever ne peut pas **abaisser** : le compte est en retard de cent
      // secondes, seul son `completed` nous manquait.
      expect(mergedPositionSeconds(finished), 1000);
      expect(mergedCompleted(finished), isTrue);
    });

    test('terminé ici et pas là-bas : la complétion part', () {
      expect(
        verdictFor(candidate(local: 900, localCompleted: true, account: 900)),
        PlaybackMergeVerdict.handOver,
      );
    });
  });

  group('Ce qui ne coûte rien', () {
    test(
      'rien en local : aucun cycle demandé, aucun octet envoyé',
      () async {
        // Le cas de la très grande majorité des connexions. Une fusion qui
        // demanderait un cycle pour apprendre qu'elle n'a rien à faire ferait
        // payer un aller-retour réseau à chaque ouverture de session.
        final report = await handover().run();

        expect(pulls, 0);
        expect(reporter.reports, isEmpty);
        expect(report.candidates, 0);
      },
    );
  });

  group('La position la plus avancée gagne', () {
    test('le compte ne connaît rien : la trace locale part telle quelle',
        () async {
      await givenLocalPosition(positionSeconds: 942);

      final report = await handover().run();

      expect(reporter.reports, hasLength(1));
      expect(reporter.reports.single.contentId, content);
      expect(reporter.reports.single.positionSeconds, 942);
      expect(reporter.reports.single.completed, isFalse);
      // L'identité frappée par ce client, faute d'en connaître une autre.
      expect(reporter.reports.single.progressId, localProgressId);
      expect(report.handedOver, [content]);
      expect(report.accountIsFresh, isTrue);
    });

    test('l\'invité plus avancé écrase le compte, sous l\'identité du compte',
        () async {
      await givenAccountProgress(positionSeconds: 300);
      await givenLocalPosition(positionSeconds: 900);

      await handover().run();

      expect(reporter.reports, hasLength(1));
      expect(reporter.reports.single.positionSeconds, 900);
      // Dès que le serveur connaît une ligne pour ce contenu, c'est **son** `id`
      // qui repart : en frapper un second créerait une seconde ligne.
      expect(reporter.reports.single.progressId, accountProgressId);
    });

    test(
      'l\'invité moins avancé ne fait pas reculer le compte — et la reprise de '
      'cet appareil monte à la position du compte',
      () async {
        // **Le test central.** Trente minutes écoutées sur un second téléphone,
        // cinq minutes écoutées en invité sur celui-ci : se connecter ne doit pas
        // ramener le compte à cinq minutes.
        await givenAccountProgress(positionSeconds: 1800);
        await givenLocalPosition(positionSeconds: 300);

        final report = await handover().run();

        expect(
          reporter.reports,
          isEmpty,
          reason: 'aucune position en retard ne part vers le compte',
        );
        expect(report.handedOver, isEmpty);
        expect(report.raised, [content]);

        // La ligne locale est relevée, et c'est ce qui ferme la dernière porte
        // par laquelle la position pouvait reculer : sans ce relèvement, la
        // reprise repartirait à 300 s (la ligne locale est la plus **récente**),
        // et le premier rapport du lecteur écraserait le compte avec cette
        // valeur-là.
        final local = await dao.localPositionFor(content);
        expect(local?.positionSeconds, 1800);
        expect(local?.progressId, accountProgressId);

        final resume = await dao.resumeFor(content);
        expect(resume?.positionSeconds, 1800);
      },
    );

    test('la même seconde des deux côtés : rien ne part', () async {
      await givenAccountProgress(positionSeconds: 900);
      await givenLocalPosition(positionSeconds: 900);

      final report = await handover().run();

      expect(reporter.reports, isEmpty);
      expect(report.raised, isEmpty);
      expect(report.handedOver, isEmpty);
    });

    test(
      'le compte a terminé : on ne rapporte plus, et la position locale ne '
      'descend pas pour autant',
      () async {
        await givenAccountProgress(positionSeconds: 900, completed: true);
        await givenLocalPosition(positionSeconds: 1000);

        await handover().run();

        expect(reporter.reports, isEmpty);
        final local = await dao.localPositionFor(content);
        expect(local?.completed, isTrue);
        expect(local?.positionSeconds, 1000);
      },
    );

    test('une écoute jamais commencée ne part pas', () async {
      await givenLocalPosition(positionSeconds: 0);

      await handover().run();

      expect(reporter.reports, isEmpty);
    });
  });

  group('Le compte doit avoir été relu, sinon on ne touche à rien', () {
    test('un cycle qui échoue : rien ne part, rien n\'est écrit', () async {
      await givenLocalPosition(positionSeconds: 900);

      final report = await handover(fresh: false).run();

      // Ne rien faire perd une commodité ; pousser à l'aveugle abîme la donnée —
      // l'upsert du serveur écrit la position reçue, même en retard (vérifié :
      // `report_playback_progress.ts` + `owned_content_repository.ts`). La fusion
      // repartira à la prochaine ouverture de session.
      expect(reporter.reports, isEmpty);
      expect(report.accountIsFresh, isFalse);
      expect(report.candidates, 1);
      expect((await dao.localPositionFor(content))?.positionSeconds, 900);
    });

    test(
      'la comparaison se fait sur ce que le cycle vient de ramener',
      () async {
        // La ligne du compte n'existe **pas** au moment où la fusion commence :
        // elle arrive pendant le cycle, comme en production. Une fusion qui
        // comparerait aux positions d'avant pousserait 300 s contre 1800 s.
        await givenLocalPosition(positionSeconds: 300);

        await handover(
          duringPull: () => givenAccountProgress(positionSeconds: 1800),
        ).run();

        expect(reporter.reports, isEmpty);
        expect((await dao.localPositionFor(content))?.positionSeconds, 1800);
      },
    );
  });

  group('Ce qui est transféré ne repart pas', () {
    test(
      'la ligne répliquée revenue **est** la marque du transfert',
      () async {
        // Aucune colonne « déjà poussé » n'existe, et c'est délibéré : l'accusé
        // de réception, c'est la ligne que le flux delta ramène.
        await givenLocalPosition(positionSeconds: 900);
        await handover().run();
        expect(reporter.reports, hasLength(1));

        // Le cycle suivant ramène la ligne, sous l'identité que le client avait
        // frappée.
        await givenAccountProgress(
          id: localProgressId,
          positionSeconds: 900,
          updatedAt: DateTime.utc(2026, 9, 27, 11),
        );

        await handover().run();

        expect(
          reporter.reports,
          hasLength(1),
          reason: 'la connexion suivante ne repousse pas ce que le compte a',
        );
      },
    );
  });

  group('L\'application tuée en plein transfert', () {
    test(
      'ce qui n\'est pas parti repart, ce qui est parti ne repart pas',
      () async {
        await givenLocalPosition(contentId: content, positionSeconds: 900);
        await givenLocalPosition(
          contentId: otherContent,
          progressId: '019f6b00-0000-7000-8000-0000000000fe',
          positionSeconds: 120,
        );
        // Le second n'est jamais parti : réseau coupé, ou application tuée entre
        // les deux poussées — de l'extérieur, c'est le même état.
        reporter.refuse.add(otherContent);

        final first = await handover().run();
        expect(first.handedOver, [content]);
        expect(first.deferred, [otherContent]);

        // Le delta ramène ce qui est passé, et lui seul.
        await givenAccountProgress(
          id: localProgressId,
          positionSeconds: 900,
          updatedAt: DateTime.utc(2026, 9, 27, 11),
        );
        reporter.refuse.clear();
        reporter.reports.clear();

        final second = await handover().run();

        expect(second.handedOver, [otherContent]);
        expect(
          reporter.reports.map((r) => r.contentId),
          [otherContent],
          reason: 'le contenu déjà rangé par le serveur ne repart pas',
        );
      },
    );
  });

  group('Le silence', () {
    test('un rapporteur qui lève ne retient pas les autres contenus', () async {
      await givenLocalPosition(contentId: content, positionSeconds: 900);
      await givenLocalPosition(
        contentId: otherContent,
        progressId: '019f6b00-0000-7000-8000-0000000000fe',
        positionSeconds: 120,
      );
      reporter.explode.add(content);

      // Ne lève pas : une connexion ne peut pas échouer parce qu'une commodité a
      // échoué.
      final report = await handover().run();

      expect(report.deferred, [content]);
      expect(report.handedOver, [otherContent]);
    });

    test('deux fusions concurrentes n\'en font qu\'une', () async {
      await givenLocalPosition(positionSeconds: 900);
      final fusion = handover();

      final both = await Future.wait([fusion.run(), fusion.run()]);

      expect(pulls, 1);
      expect(reporter.reports, hasLength(1));
      expect(both.first.handedOver, [content]);
    });
  });
}
