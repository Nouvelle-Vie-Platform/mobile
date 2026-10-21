// **Les cinq déclencheurs du rapport de progression, et le seuil de « terminé ».**
//
// Aucun moteur audio ici, et c'est délibéré : l'enregistreur n'a pas d'horloge
// et ne joue rien — le lecteur lui **pousse** sa position. Les tests jouent donc
// le rôle du lecteur, seconde par seconde, ce qu'aucun `just_audio` ne
// permettrait sous `flutter test` (`setUrl` y lève `MissingPluginException`).
//
// Deux exigences dominent le fichier. **L'écriture locale est continue et
// gratuite** — c'est elle qui sauve la place d'un fidèle dont le système tue
// l'application. **L'appel réseau est espacé**, et muet : hors ligne, 401, 5xx,
// rien ne s'affiche et rien ne bloque l'écoute.

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/playback_dao.dart';
import 'package:maison_du_miracle/data/repositories/playback_progress_recorder.dart';
import 'package:maison_du_miracle/data/repositories/playback_progress_reporter.dart';

import 'local/local_database_fixtures.dart';

const String _contentId = '019f2c40-0000-7000-8000-000000000001';
const String _mintedId = '019f6b00-0000-7000-8000-0000000000ff';
const String _syncedId = '019f6b00-0000-7000-8000-000000000001';

/// Rapporteur double : il note ce qu'on lui donne, et ne parle à personne.
class _RecordingReporter implements PlaybackProgressReporter {
  final List<PlaybackProgressReport> sent = [];

  /// Quand il est posé, chaque rapport échoue — comme un rapporteur réel qui
  /// n'a pas trouvé de réseau. Il ne **lève** pas : le contrat de
  /// [PlaybackProgressReporter] est de ne jamais lever.
  bool offline = false;

  /// Chaque essai, parti ou non : c'est ce qui coûte une requête.
  int attempts = 0;

  PlaybackProgressReport get last => sent.last;

  @override
  Future<bool> report(PlaybackProgressReport report) async {
    attempts++;
    if (offline) return false;
    sent.add(report);
    return true;
  }
}

/// Rapporteur qui **lève**, ce que le contrat interdit : la seconde ceinture de
/// l'enregistreur doit tenir quand même. Une erreur de programmation ne doit pas
/// plus interrompre un prêche qu'une coupure réseau.
class _ThrowingReporter implements PlaybackProgressReporter {
  int calls = 0;

  @override
  Future<bool> report(PlaybackProgressReport report) async {
    calls++;
    throw StateError('le rapporteur a un bug');
  }
}

void main() {
  late AppDatabase db;
  late PlaybackDao dao;
  late _RecordingReporter reporter;

  setUp(() {
    db = openTestDatabase();
    dao = db.playbackDao;
    reporter = _RecordingReporter();
  });

  tearDown(() => db.close());

  Future<PlaybackProgressRecorder> openRecorder({
    PlaybackProgressReporter? withReporter,
    bool partialSource = false,
  }) =>
      PlaybackProgressRecorder.open(
        dao: dao,
        reporter: withReporter ?? reporter,
        contentId: _contentId,
        partialSource: partialSource,
        mintId: () => _mintedId,
      );

  /// Joue [seconds] secondes, une par une, comme le ferait un lecteur.
  Future<void> play(
    PlaybackProgressRecorder recorder, {
    required int from,
    required int to,
    Duration? duration,
  }) async {
    for (var s = from + 1; s <= to; s++) {
      await recorder.onPosition(
        Duration(seconds: s),
        duration: duration,
        isPlaying: true,
      );
    }
  }

  Future<void> givenSyncedProgress({
    required int positionSeconds,
    bool completed = false,
    required DateTime updatedAt,
  }) =>
      db.syncDao.applyPage(
        db.syncDao.playbackProgressCollection,
        upserts: [
          PlaybackProgressCompanion.insert(
            id: _syncedId,
            teachingId: _contentId,
            positionSeconds: positionSeconds,
            completed: Value(completed),
            updatedAt: Value(updatedAt),
          ),
        ],
        cursor: 'c-progress',
      );

  group('L\'ouverture : où reprendre, et sous quel identifiant', () {
    test('un contenu neuf frappe son UUIDv7 et repart de zéro', () async {
      final recorder = await openRecorder();

      expect(recorder.resume, isNull);
      expect(recorder.progressId, _mintedId);
      expect(recorder.position, Duration.zero);
    });

    test('en production l\'identifiant frappé est un vrai UUIDv7', () async {
      final recorder = await PlaybackProgressRecorder.open(
        dao: dao,
        reporter: reporter,
        contentId: _contentId,
      );

      // Version 7 : le treizième caractère hexadécimal du canonique. Le serveur
      // le valide (`uuidV7()` dans son validateur) et refuserait un v4.
      expect(recorder.progressId, hasLength(36));
      expect(recorder.progressId[14], '7');
    });

    test(
      'un contenu déjà connu du serveur reprend à sa position, sous son '
      'identifiant à lui',
      () async {
        await givenSyncedProgress(
          positionSeconds: 942,
          updatedAt: DateTime.utc(2026, 5, 24, 14),
        );

        final recorder = await openRecorder();

        expect(recorder.resume!.position, const Duration(seconds: 942));
        expect(recorder.progressId, _syncedId);
      },
    );

    test(
      'une reprise venue de la synchro n\'est pas réapprise au serveur au '
      'premier geste',
      () async {
        await givenSyncedProgress(
          positionSeconds: 942,
          updatedAt: DateTime.utc(2026, 5, 24, 14),
        );
        final recorder = await openRecorder();

        await recorder.onPaused();

        // Rien n'a bougé depuis, et le serveur le sait déjà : la radio reste
        // éteinte.
        expect(reporter.sent, isEmpty);
      },
    );

    test(
      'une reprise venue de la table locale, elle, n\'a peut-être jamais '
      'réussi à partir : on retente',
      () async {
        await dao.saveLocalPosition(
          contentId: _contentId,
          progressId: _mintedId,
          positionSeconds: 300,
        );
        final recorder = await openRecorder();

        await recorder.onPaused();

        expect(reporter.sent, hasLength(1));
        expect(reporter.last.positionSeconds, 300);
      },
    );
  });

  group('L\'écriture locale est continue et gratuite', () {
    test('chaque seconde franchie remplace la ligne locale', () async {
      final recorder = await openRecorder();

      await play(recorder, from: 0, to: 7);

      final rows = await db.select(db.localPlaybackPositions).get();
      expect(rows, hasLength(1));
      expect(rows.single.positionSeconds, 7);
      expect(rows.single.progressId, _mintedId);
      // Et pas un seul appel réseau : sept secondes de temps joué sont loin des
      // trente du pas périodique.
      expect(reporter.sent, isEmpty);
    });

    test('une position qui ne change pas de seconde n\'écrit pas deux fois',
        () async {
      final recorder = await openRecorder();
      await recorder.onPosition(
        const Duration(milliseconds: 4200),
        isPlaying: true,
      );
      await recorder.onPosition(
        const Duration(milliseconds: 4400),
        isPlaying: true,
      );

      final rows = await db.select(db.localPlaybackPositions).get();
      expect(rows.single.positionSeconds, 4);
    });

    test('la position à chaud survit à la fermeture de l\'enregistreur',
        () async {
      final first = await openRecorder();
      await play(first, from: 0, to: 12);

      // L'application est tuée par le système, puis rouverte : le second
      // enregistreur retrouve la place sans qu'aucun cycle de synchronisation
      // n'ait eu lieu.
      final second = await openRecorder();

      expect(second.resume!.position, const Duration(seconds: 12));
      expect(second.resume!.source, PlaybackResumeSource.local);
      expect(second.progressId, _mintedId);
    });
  });

  group('Le rapport périodique : ~30 s de temps JOUÉ, et plus de 5 s', () {
    test('trente secondes jouées déclenchent un rapport, pas avant', () async {
      final recorder = await openRecorder();

      await play(recorder, from: 0, to: 29);
      expect(reporter.sent, isEmpty);

      await play(recorder, from: 29, to: 30);
      expect(reporter.sent, hasLength(1));
      expect(reporter.last.positionSeconds, 30);
      expect(reporter.last.progressId, _mintedId);
      expect(reporter.last.contentId, _contentId);
      expect(reporter.last.completed, isFalse);
    });

    test('le compteur repart à zéro après un rapport', () async {
      final recorder = await openRecorder();

      await play(recorder, from: 0, to: 90);

      // Trois rapports, à 30, 60 et 90 — et pas un de plus.
      expect(reporter.sent.map((r) => r.positionSeconds), [30, 60, 90]);
    });

    test(
      'une pause de dix minutes ne produit pas vingt rapports : le temps '
      'compté est le temps joué',
      () async {
        final recorder = await openRecorder();
        await play(recorder, from: 0, to: 30);
        expect(reporter.sent, hasLength(1));

        // Le lecteur continue de pousser sa position — elle ne bouge pas.
        for (var i = 0; i < 600; i++) {
          await recorder.onPosition(
            const Duration(seconds: 30),
            isPlaying: false,
          );
        }

        expect(reporter.sent, hasLength(1));
      },
    );

    test(
      'trente secondes accumulées sur place ne partent pas : il faut aussi '
      'plus de cinq secondes de déplacement',
      () async {
        final recorder = await openRecorder();
        await play(recorder, from: 0, to: 30);
        reporter.sent.clear();

        // Un va-et-vient d'une seconde, quarante fois : quarante secondes de
        // temps joué, mais on n'a pas bougé.
        for (var i = 0; i < 40; i++) {
          await recorder.onPosition(
            const Duration(seconds: 31),
            isPlaying: true,
          );
          await recorder.onPosition(
            const Duration(seconds: 30),
            isPlaying: true,
          );
        }

        expect(reporter.sent, isEmpty);
      },
    );

    test('un saut en avant compte comme du temps joué, et fait rapporter',
        () async {
      // C'est voulu : après un saut, c'est exactement le moment où l'on veut
      // que le serveur sache où l'on en est.
      final recorder = await openRecorder();

      await recorder.onPosition(const Duration(seconds: 600), isPlaying: true);

      expect(reporter.sent, hasLength(1));
      expect(reporter.last.positionSeconds, 600);
    });

    test('jamais de sondage : aucune horloge dans l\'enregistreur', () {
      // Même garde-fou que « jamais de polling » du socle de synchronisation :
      // un `Timer.periodic` ajouté « pour être sûr » ne casse aucun test de
      // comportement, il réveille seulement la radio d'un téléphone.
      final code = File(
        'lib/data/repositories/playback_progress_recorder.dart',
      )
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .where((line) => !line.trimLeft().startsWith('///'))
          .join('\n');

      expect(code, isNot(contains('Timer')));
      expect(code, isNot(contains('Stream.periodic')));
    });
  });

  group('Les quatre autres déclencheurs', () {
    test('la pause rapporte, sans attendre les trente secondes', () async {
      final recorder = await openRecorder();
      await play(recorder, from: 0, to: 8);

      await recorder.onPaused();

      expect(reporter.sent, hasLength(1));
      expect(reporter.last.positionSeconds, 8);
    });

    test('la sortie de l\'écran rapporte', () async {
      final recorder = await openRecorder();
      await play(recorder, from: 0, to: 8);

      await recorder.onLeft();

      expect(reporter.sent.single.positionSeconds, 8);
    });

    test(
      'AppLifecycleState.paused rapporte — et ne touche pas à la lecture',
      () async {
        // Le cas le plus fréquent : le fidèle éteint son écran. Il ne quitte
        // pas, il écoute. L'enregistreur ne connaît aucun lecteur et n'a donc
        // aucun moyen d'arrêter le son : c'est structurel, pas une promesse.
        final recorder = await openRecorder();
        await play(recorder, from: 0, to: 8);

        await recorder.onAppPaused();

        expect(reporter.sent.single.positionSeconds, 8);
        // La lecture continue : rien dans l'enregistreur n'a changé d'état.
        await play(recorder, from: 8, to: 12);
        final rows = await db.select(db.localPlaybackPositions).get();
        expect(rows.single.positionSeconds, 12);
      },
    );

    test(
      'trois déclencheurs enchaînés n\'envoient qu\'un rapport : le serveur '
      'sait déjà',
      () async {
        // On éteint l'écran, on met en pause, on quitte — en une fraction de
        // seconde. Trois requêtes identiques réveilleraient la radio pour trois
        // upserts que le serveur traiterait en no-op.
        final recorder = await openRecorder();
        await play(recorder, from: 0, to: 8);

        await recorder.onAppPaused();
        await recorder.onPaused();
        await recorder.onLeft();

        expect(reporter.sent, hasLength(1));
      },
    );

    test('l\'état terminal du lecteur marque terminé', () async {
      final recorder = await openRecorder();
      await play(recorder, from: 0, to: 8);
      reporter.sent.clear();

      await recorder.onTerminated();

      expect(recorder.isCompleted, isTrue);
      expect(reporter.last.completed, isTrue);
    });
  });

  group('Le seuil de « terminé »', () {
    test('à trente secondes de la fin, c\'est terminé', () async {
      final recorder = await openRecorder();

      await recorder.onPosition(
        const Duration(seconds: 570),
        duration: const Duration(seconds: 600),
        isPlaying: true,
      );

      expect(recorder.isCompleted, isTrue);
      expect(reporter.last.completed, isTrue);
    });

    test('une seconde plus tôt, ça ne l\'est pas', () async {
      final recorder = await openRecorder();

      await recorder.onPosition(
        const Duration(seconds: 569),
        duration: const Duration(seconds: 600),
        isPlaying: true,
      );

      expect(recorder.isCompleted, isFalse);
    });

    test(
      'une durée INCONNUE ne termine jamais rien, si loin qu\'on soit allé',
      () async {
        // Le cas courant, pas l'exception : en HLS sur iOS, `duration` est peu
        // fiable et souvent nulle. Marquer « terminé » sur une durée devinée
        // ferait disparaître de la liste « à reprendre » un prêche dont
        // quelqu'un n'a entendu que dix minutes.
        final recorder = await openRecorder();

        await recorder.onPosition(
          const Duration(hours: 3),
          isPlaying: true,
        );

        expect(recorder.isCompleted, isFalse);
        expect(reporter.last.completed, isFalse);
      },
    );

    test('une durée nulle ou négative est aberrante, et ne termine rien',
        () async {
      final recorder = await openRecorder();

      await recorder.onPosition(
        const Duration(seconds: 120),
        duration: Duration.zero,
        isPlaying: true,
      );

      expect(recorder.isCompleted, isFalse);
    });

    test(
      'un contenu plus court que le seuil ne serait pas terminé dès la '
      'première image',
      () async {
        // La soustraction passerait sous zéro : un extrait de vingt secondes
        // serait « écouté » avant d'avoir commencé.
        final recorder = await openRecorder();

        await recorder.onPosition(
          const Duration(seconds: 1),
          duration: const Duration(seconds: 20),
          isPlaying: true,
        );

        expect(recorder.isCompleted, isFalse);
      },
    );

    test('mais l\'état terminal, lui, termine même sans durée', () async {
      final recorder = await openRecorder();
      await recorder.onPosition(const Duration(seconds: 19), isPlaying: true);

      await recorder.onTerminated();

      expect(recorder.isCompleted, isTrue);
    });

    test('une fois terminé, la position ne se rapporte plus', () async {
      final recorder = await openRecorder();
      await recorder.onPosition(
        const Duration(seconds: 570),
        duration: const Duration(seconds: 600),
        isPlaying: true,
      );
      reporter.sent.clear();

      await play(recorder, from: 570, to: 700);
      await recorder.onPaused();
      await recorder.onLeft();

      expect(reporter.sent, isEmpty);
      // La position **locale**, elle, continue d'être tenue : quelqu'un qui
      // réécoute doit retrouver sa place.
      final rows = await db.select(db.localPlaybackPositions).get();
      expect(rows.single.positionSeconds, 700);
      expect(rows.single.completed, isTrue);
    });

    test('le seuil est écrit à un seul endroit', () {
      // Une constante nommée, et pas un `30` semé dans trois fichiers : la
      // valeur est **à confirmer** (question ouverte de l'issue #43), et il faut
      // qu'un seul geste suffise à la changer.
      expect(kPlaybackCompletionSlack, const Duration(seconds: 30));
      expect(
        readsAsCompleted(
          position: const Duration(seconds: 570),
          duration: const Duration(seconds: 600),
        ),
        isTrue,
      );
      expect(
        readsAsCompleted(position: const Duration(seconds: 570)),
        isFalse,
      );
    });
  });

  group('Le rapport est muet, et ne bloque jamais l\'écoute', () {
    test('un rapport perdu n\'interrompt rien, et se retente', () async {
      final recorder = await openRecorder();
      reporter.offline = true;

      await play(recorder, from: 0, to: 30);
      expect(reporter.sent, isEmpty);

      // La position locale a été tenue pendant tout ce temps : rien n'est perdu
      // pour le fidèle, seulement pour le serveur.
      var rows = await db.select(db.localPlaybackPositions).get();
      expect(rows.single.positionSeconds, 30);

      // Le réseau revient : le déclencheur suivant repart tout de suite, sans
      // attendre trente secondes de plus.
      reporter.offline = false;
      await recorder.onPaused();

      expect(reporter.sent.single.positionSeconds, 30);
    });

    test(
        'un échec n\'est PAS retenté à chaque émission de position, mais '
        'trente secondes de lecture plus tard', () async {
      final recorder = await openRecorder();
      reporter.offline = true;

      // Quatre émissions par seconde, comme le lecteur réel, pendant une
      // minute. Avant la correction, chaque émission au-delà de trente
      // secondes retentait : plus d'une centaine d'essais ici, des milliers à
      // l'heure en production.
      for (var q = 1; q <= 240; q++) {
        await recorder.onPosition(
          Duration(milliseconds: q * 250),
          duration: null,
          isPlaying: true,
        );
      }

      expect(reporter.attempts, 2);
    });

    test('un rapporteur qui LÈVE ne fait pas tomber la lecture', () async {
      final throwing = _ThrowingReporter();
      final recorder = await openRecorder(withReporter: throwing);

      await expectLater(play(recorder, from: 0, to: 30), completes);
      await expectLater(recorder.onPaused(), completes);
      await expectLater(recorder.onTerminated(), completes);

      expect(throwing.calls, greaterThan(0));
      // Et la position locale a continué d'être écrite pendant tout ce temps.
      final rows = await db.select(db.localPlaybackPositions).get();
      expect(rows.single.positionSeconds, 30);
    });

    test('rien n\'est jamais écrit dans la collection répliquée', () async {
      final recorder = await openRecorder();
      await play(recorder, from: 0, to: 90);
      await recorder.onTerminated();

      // Le rapporteur a parlé au serveur ; c'est le flux delta qui ramènera la
      // ligne. Le réseau ne peint jamais.
      expect(await db.select(db.playbackProgress).get(), isEmpty);
      expect(reporter.sent, isNotEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // #228 — un fichier partiel n'est jamais « écouté »
  // ───────────────────────────────────────────────────────────────────────────

  group('Un fichier partiel (#228)', () {
    test('l\'état terminal n\'est que la fin des octets, pas celle du prêche',
        () async {
      // Un `.aac` partiel joué hors ligne (F11) s'arrête proprement à la limite
      // des octets reçus : AVPlayer et ExoPlayer rendent `completed`, **sans
      // erreur** — c'est mesuré (spike 1, mobile#215). Ce fait-là ne dit pas que
      // l'enseignement a été entendu jusqu'au bout.
      final recorder = await openRecorder(partialSource: true);
      await play(recorder, from: 2395, to: 2400);

      await recorder.onTerminated();

      expect(recorder.isCompleted, isFalse);
      // Mais les quarante minutes réellement écoutées sont gardées : le fidèle
      // reprendra là une fois le fichier complet.
      final row = await db.select(db.localPlaybackPositions).get();
      expect(row.single.positionSeconds, 2400);
      expect(row.single.completed, isFalse);
      expect(reporter.sent.every((r) => !r.completed), isTrue);
    });

    test('le seuil ne le termine pas non plus, même téléchargé à 99 %',
        () async {
      // L'autre entrée de la complétion, et la raison du garde dans la fonction
      // partagée : sur un partiel presque entier, la position atteint bien les
      // trente dernières secondes de la **vraie** durée (celle du contrat,
      // #222) — le seuil marquerait « écouté » un enseignement dont la fin
      // manque sur le disque.
      final recorder = await openRecorder(partialSource: true);

      await recorder.onPosition(
        const Duration(hours: 1, minutes: 59, seconds: 35),
        duration: const Duration(hours: 2),
        isPlaying: true,
      );

      expect(recorder.isCompleted, isFalse);
      final row = await db.select(db.localPlaybackPositions).get();
      expect(row.single.completed, isFalse);
      expect(reporter.sent.every((r) => !r.completed), isTrue);
    });

    test('un fichier entier, lui, termine toujours par l\'état terminal',
        () async {
      // Le cas normal : sans le drapeau, rien ne change. La base est neuve à
      // chaque test — aucune complétion d'un autre cas ne peut faire passer
      // celui-ci.
      final recorder = await openRecorder();

      await recorder.onTerminated();

      expect(recorder.isCompleted, isTrue);
      expect(reporter.last.completed, isTrue);
    });

    test('un fichier entier, lui, termine toujours par le seuil', () async {
      final recorder = await openRecorder();

      await recorder.onPosition(
        const Duration(hours: 1, minutes: 59, seconds: 35),
        duration: const Duration(hours: 2),
        isPlaying: true,
      );

      expect(recorder.isCompleted, isTrue);
      expect(reporter.last.completed, isTrue);
      expect(
        (await db.select(db.localPlaybackPositions).get()).single.completed,
        isTrue,
      );
    });
  });
}
