import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/playback_dao.dart';

import 'local_database_fixtures.dart';

/// **Les deux tables de la reprise, et la résolution entre elles.**
///
/// L'invariant que ce fichier garde tient en une phrase : *la synchronisation
/// remplit la collection répliquée, le lecteur remplit la table locale, et
/// personne ne se mélange*. Une écriture applicative dans `playback_progress`
/// ne casserait aucun test de comportement — elle serait simplement écrasée au
/// cycle suivant, et le bug qui en résulterait serait irreproductible.
void main() {
  late AppDatabase db;
  late PlaybackDao dao;

  const contentId = '019f2c40-0000-7000-8000-000000000001';
  const syncedProgressId = '019f6b00-0000-7000-8000-000000000001';
  const mintedProgressId = '019f6b00-0000-7000-8000-0000000000ff';

  setUp(() {
    db = openTestDatabase();
    dao = db.playbackDao;
  });

  tearDown(() => db.close());

  /// Pose une ligne **répliquée** comme la synchronisation le ferait — par
  /// `SyncDao`, jamais par le DAO de lecture.
  Future<void> givenSyncedProgress({
    String id = syncedProgressId,
    String teachingId = contentId,
    required int positionSeconds,
    bool completed = false,
    required DateTime updatedAt,
  }) {
    return db.syncDao.applyPage(
      db.syncDao.playbackProgressCollection,
      upserts: [
        PlaybackProgressCompanion.insert(
          id: id,
          teachingId: teachingId,
          positionSeconds: positionSeconds,
          completed: Value(completed),
          updatedAt: Value(updatedAt),
        ),
      ],
      cursor: 'c-progress',
    );
  }

  group('Rien à reprendre', () {
    test('un contenu jamais écouté ne rend aucune reprise', () async {
      expect(await dao.resumeFor(contentId), isNull);
    });
  });

  group('Une seule des deux sources', () {
    test(
      'la ligne répliquée suffit : c\'est elle qui donne la reprise sur un '
      'second appareil, et après réinstallation',
      () async {
        await givenSyncedProgress(
          positionSeconds: 942,
          updatedAt: DateTime.utc(2026, 5, 24, 14, 31),
        );

        final resume = await dao.resumeFor(contentId);

        expect(resume, isNotNull);
        expect(resume!.source, PlaybackResumeSource.synced);
        expect(resume.position, const Duration(seconds: 942));
        expect(resume.progressId, syncedProgressId);
      },
    );

    test(
      'la position à chaud suffit : elle est la seule qui marche en avion',
      () async {
        await dao.saveLocalPosition(
          contentId: contentId,
          progressId: mintedProgressId,
          positionSeconds: 120,
          at: DateTime.utc(2026, 5, 24, 14),
        );

        final resume = await dao.resumeFor(contentId);

        expect(resume!.source, PlaybackResumeSource.local);
        expect(resume.position, const Duration(seconds: 120));
        // Aucune ligne répliquée n'existe encore : c'est l'identifiant frappé
        // par ce client qui fait foi, et c'est lui qui partira au serveur.
        expect(resume.progressId, mintedProgressId);
      },
    );
  });

  group('Les deux sources : la plus récente gagne', () {
    test('la position à chaud est en général en avance, et l\'emporte',
        () async {
      await givenSyncedProgress(
        positionSeconds: 600,
        updatedAt: DateTime.utc(2026, 5, 24, 14, 20),
      );
      await dao.saveLocalPosition(
        contentId: contentId,
        progressId: mintedProgressId,
        positionSeconds: 942,
        at: DateTime.utc(2026, 5, 24, 14, 31),
      );

      final resume = await dao.resumeFor(contentId);

      expect(resume!.source, PlaybackResumeSource.local);
      expect(resume.positionSeconds, 942);
    });

    test(
      'mais pas toujours : ce qu\'un autre appareil a écouté depuis l\'emporte '
      'sur la position locale devenue vieille',
      () async {
        // Le fidèle a écouté dix minutes dans le taxi sur ce téléphone-ci, puis
        // trente minutes chez lui sur l'autre. Rouvrir celui du taxi doit
        // reprendre à trente minutes.
        await dao.saveLocalPosition(
          contentId: contentId,
          progressId: mintedProgressId,
          positionSeconds: 600,
          at: DateTime.utc(2026, 5, 24, 14),
        );
        await givenSyncedProgress(
          positionSeconds: 1800,
          updatedAt: DateTime.utc(2026, 5, 24, 20),
        );

        final resume = await dao.resumeFor(contentId);

        expect(resume!.source, PlaybackResumeSource.synced);
        expect(resume.positionSeconds, 1800);
      },
    );

    test(
      'réécouter depuis le début ne renvoie pas à la fin : c\'est la plus '
      'récente qui gagne, pas la plus grande',
      () async {
        // Prendre systématiquement la plus grande **position** aurait l'air de
        // marcher sur les deux tests précédents, et enverrait quelqu'un qui
        // recommence un prêche droit à la fin.
        await givenSyncedProgress(
          positionSeconds: 3500,
          updatedAt: DateTime.utc(2026, 5, 24, 14),
        );
        await dao.saveLocalPosition(
          contentId: contentId,
          progressId: mintedProgressId,
          positionSeconds: 12,
          at: DateTime.utc(2026, 5, 25, 9),
        );

        final resume = await dao.resumeFor(contentId);

        expect(resume!.source, PlaybackResumeSource.local);
        expect(resume.positionSeconds, 12);
      },
    );

    test(
      'l\'identité, elle, ne se départage pas à l\'horloge : le serveur '
      'connaît la ligne, c\'est son id qui repart',
      () async {
        // Frapper un second UUID pour un contenu que le serveur connaît déjà
        // créerait une seconde ligne — ou un 409 le jour où le rapprochement
        // serveur par `(userId, teachingId)` disparaîtrait.
        await givenSyncedProgress(
          positionSeconds: 600,
          updatedAt: DateTime.utc(2026, 5, 24, 14),
        );
        await dao.saveLocalPosition(
          contentId: contentId,
          progressId: mintedProgressId,
          positionSeconds: 942,
          at: DateTime.utc(2026, 5, 25, 9),
        );

        final resume = await dao.resumeFor(contentId);

        expect(resume!.source, PlaybackResumeSource.local);
        expect(resume.progressId, syncedProgressId);
      },
    );

    test(
      'une ligne répliquée sans updatedAt ne prétend pas être la plus fraîche',
      () async {
        await db.syncDao.applyPage(
          db.syncDao.playbackProgressCollection,
          upserts: [
            PlaybackProgressCompanion.insert(
              id: syncedProgressId,
              teachingId: contentId,
              positionSeconds: 3000,
            ),
          ],
          cursor: 'c-progress',
        );
        await dao.saveLocalPosition(
          contentId: contentId,
          progressId: mintedProgressId,
          positionSeconds: 42,
          at: DateTime.utc(2026, 5, 25, 9),
        );

        final resume = await dao.resumeFor(contentId);

        expect(resume!.source, PlaybackResumeSource.local);
        expect(resume.positionSeconds, 42);
      },
    );
  });

  group('« Terminé » voyage avec la position', () {
    test('la source retenue donne aussi le drapeau de complétion', () async {
      await givenSyncedProgress(
        positionSeconds: 3600,
        completed: true,
        updatedAt: DateTime.utc(2026, 5, 24, 14),
      );

      final resume = await dao.resumeFor(contentId);

      expect(resume!.completed, isTrue);
    });
  });

  group('Deux tables, et personne ne se mélange', () {
    test(
      'écrire la position à chaud ne touche pas à la collection répliquée',
      () async {
        await givenSyncedProgress(
          positionSeconds: 600,
          updatedAt: DateTime.utc(2026, 5, 24, 14),
        );

        await dao.saveLocalPosition(
          contentId: contentId,
          progressId: mintedProgressId,
          positionSeconds: 942,
          completed: true,
        );

        // La ligne répliquée est **intacte** : seule la synchronisation
        // l'écrit, et le serveur ne saura la position à 942 que par
        // `POST /teachings/:teachingId/progress`.
        final synced = await dao.syncedProgressFor(contentId);
        expect(synced!.positionSeconds, 600);
        expect(synced.completed, isFalse);
      },
    );

    test('la position à chaud se remplace en place, sans historique', () async {
      for (final seconds in [10, 20, 30]) {
        await dao.saveLocalPosition(
          contentId: contentId,
          progressId: mintedProgressId,
          positionSeconds: seconds,
        );
      }

      final rows = await db.select(db.localPlaybackPositions).get();
      expect(rows, hasLength(1));
      expect(rows.single.positionSeconds, 30);
    });

    test(
      'la table locale seule n\'a pas de jeton d\'écriture, donc ne peut pas '
      'entrer au registre des collections',
      () {
        // Structurel plutôt que documentaire : sans `sync_stamp`, le balayage
        // de fin de resync et le tampon d'écriture échoueraient à la première
        // ligne. Il n'existe donc pas de chemin par lequel cette table entre
        // dans `syncedCollections()` par distraction.
        expect(
          db.localPlaybackPositions.columnsByName.keys,
          isNot(contains('sync_stamp')),
        );
        expect(
          db.playbackProgress.columnsByName.keys,
          contains('sync_stamp'),
        );
      },
    );
  });

  group('Deux contenus ne se confondent pas', () {
    test('chaque contenu a sa propre reprise', () async {
      const otherContentId = '019f2c40-0000-7000-8000-000000000002';

      await givenSyncedProgress(
        positionSeconds: 100,
        updatedAt: DateTime.utc(2026, 5, 24, 14),
      );
      await givenSyncedProgress(
        id: '019f6b00-0000-7000-8000-000000000002',
        teachingId: otherContentId,
        positionSeconds: 200,
        updatedAt: DateTime.utc(2026, 5, 24, 15),
      );

      expect((await dao.resumeFor(contentId))!.positionSeconds, 100);
      expect((await dao.resumeFor(otherContentId))!.positionSeconds, 200);
    });
  });
}
