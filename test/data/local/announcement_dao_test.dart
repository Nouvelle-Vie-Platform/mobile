// Lectures du magasin, côté **annonces**.
//
// Ce que ces tests protègent tient en une phrase : **une annonce s'affiche même
// quand ce qu'elle désigne manque**. Les quatre collections se synchronisent
// séparément, et une jointure stricte ferait disparaître le statut au lieu d'une
// ligne d'en-tête ou d'un dégradé.

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';

import 'local_database_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  group('AnnouncementDao.allAnnouncements', () {
    test('joint le compte officiel et le fond servi', () async {
      await db.batch((b) {
        b.insert(db.statusBackgrounds, statusBackgroundRow(5, ink: 'dark'));
        b.insert(
          db.officialAccounts,
          officialAccountRow(3, name: 'Diaconat de la Maison du Miracle'),
        );
        b.insert(
          db.announcements,
          announcementRow('a-1', accountId: 3, backgroundId: 5),
        );
      });

      final rows = await db.announcementDao.allAnnouncements().get();

      expect(rows, hasLength(1));
      expect(rows.single.account?.name, 'Diaconat de la Maison du Miracle');
      expect(rows.single.background?.ink, 'dark');
    });

    test(
      'préfère le nom court au nom complet dans l\'en-tête',
      () async {
        // « Diaconat » plutôt que « Diaconat de la Maison du Miracle — Bè
        // Kpota », sur une ligne où l'ellipse guette.
        await db.batch((b) {
          b.insert(
            db.officialAccounts,
            officialAccountRow(
              3,
              name: 'Diaconat de la Maison du Miracle — Bè Kpota',
              shortName: 'Diaconat',
            ),
          );
          b.insert(db.announcements, announcementRow('a-1', accountId: 3));
        });

        final rows = await db.announcementDao.allAnnouncements().get();

        expect(rows.single.accountName, 'Diaconat');
      },
    );

    test(
      'une annonce dont le compte n\'est pas encore arrivé s\'affiche quand même',
      () async {
        // La fenêtre existe : les collections se tirent séparément. Perdre le
        // statut coûterait bien plus cher que perdre sa ligne d'en-tête, qui
        // paraîtra au cycle suivant.
        await db.into(db.announcements).insert(
              announcementRow('a-1', accountId: 404, backgroundId: 404),
            );

        final rows = await db.announcementDao.allAnnouncements().get();

        expect(rows, hasLength(1));
        expect(rows.single.account, isNull);
        expect(rows.single.accountName, isNull);
        expect(rows.single.background, isNull);
      },
    );

    test('rend les annonces expirées : c\'est la lecture qui les retire',
        () async {
      // Le serveur ne retire jamais une annonce expirée du flux delta, et le
      // magasin ne la filtre pas davantage : une requête SQL est évaluée quand
      // la table change, pas quand l'heure passe. Un statut « valable jusqu'à ce
      // soir » doit disparaître **à la seconde**, ce que seul le provider peut
      // tenir.
      await db.into(db.announcements).insert(
            announcementRow(
              'expiree',
              expiresAt: DateTime.utc(2020, 1, 1),
            ),
          );

      final rows = await db.announcementDao.allAnnouncements().get();

      expect(rows, hasLength(1));
    });

    test('un flux ré-émet quand la synchronisation écrit', () async {
      final stream = db.announcementDao.allAnnouncements().watch();
      final emissions = <int>[];
      final subscription = stream.listen((rows) => emissions.add(rows.length));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.into(db.announcements).insert(announcementRow('a-1'));
      await pumpEventQueue();

      // C'est tout l'intérêt du `Stream` : une rétractation reçue pendant qu'un
      // fidèle regarde le mur retire le statut de l'écran ouvert.
      await (db.delete(db.announcements)..where((t) => t.id.equals('a-1')))
          .go();
      await pumpEventQueue();

      expect(emissions, [0, 1, 0]);
    });
  });

  group('AnnouncementDao.hasMembership', () {
    test('faux tant qu\'aucune appartenance n\'est arrivée', () async {
      expect(await db.announcementDao.hasMembership().getSingle(), isFalse);
    });

    test('vrai dès la première ligne — la collection est scoppée sur moi',
        () async {
      // Le serveur n'y sert jamais l'appartenance de quelqu'un d'autre : une
      // ligne suffit, il n'y a personne à écarter.
      await db.into(db.officialAccountMemberships).insert(membershipRow(1));

      expect(await db.announcementDao.hasMembership().getSingle(), isTrue);
    });
  });

  group('AnnouncementDao.myAccounts — ce que le composeur peut signer', () {
    test('joint mes appartenances aux comptes officiels', () async {
      await db.batch((b) {
        b.insert(db.officialAccounts, officialAccountRow(3, name: 'Diaconat'));
        b.insert(db.officialAccounts, officialAccountRow(4, name: 'Jeunesse'));
        b.insert(db.officialAccountMemberships, membershipRow(1, accountId: 3));
      });

      final rows = await db.announcementDao.myAccounts().get();

      // Le compte 4 existe, mais je n'en suis pas membre.
      expect(rows.map((row) => row.id), [3]);
    });

    test(
      'une appartenance dont le compte n\'est pas arrivé ne se propose pas',
      () async {
        // À rebours du reste du DAO, la jointure est **interne** : ailleurs on
        // tolère l'absence parce qu'il vaut mieux un statut sans en-tête qu'un
        // statut disparu. Ici l'absence est bloquante — on ne peut pas offrir
        // de signer au nom d'un compte qu'on ne sait pas nommer.
        await db
            .into(db.officialAccountMemberships)
            .insert(membershipRow(1, accountId: 404));

        expect(await db.announcementDao.myAccounts().get(), isEmpty);
      },
    );

    test('un compte désactivé n\'est plus proposé', () async {
      // Un compte se désactive au portail, jamais ne se supprime : ses annonces
      // continuent de s'afficher, mais on n'en publie plus de nouvelles.
      await db.batch((b) {
        b.insert(db.officialAccounts, officialAccountRow(3, isActive: false));
        b.insert(db.officialAccountMemberships, membershipRow(1, accountId: 3));
      });

      expect(await db.announcementDao.myAccounts().get(), isEmpty);
    });
  });

  group('AnnouncementDao.composableBackgrounds', () {
    test('ne propose que les fonds actifs, triés par position', () async {
      await db.batch((b) {
        b.insert(db.statusBackgrounds, statusBackgroundRow(1, position: 2));
        b.insert(db.statusBackgrounds, statusBackgroundRow(2, position: 1));
        b.insert(
          db.statusBackgrounds,
          statusBackgroundRow(3, position: 0, isActive: false),
        );
      });

      final rows = await db.announcementDao.composableBackgrounds().get();

      expect(rows.map((row) => row.id), [2, 1]);
    });

    test(
      'un fond désactivé reste peint sur les annonces qui le portent',
      () async {
        // `isActive` est une **donnée**, pas un filtre de stockage : le retirer
        // du magasin ferait perdre son dégradé à un statut parfaitement valide.
        await db.batch((b) {
          b.insert(
            db.statusBackgrounds,
            statusBackgroundRow(7, isActive: false),
          );
          b.insert(db.announcements, announcementRow('a-1', backgroundId: 7));
        });

        expect(await db.announcementDao.composableBackgrounds().get(), isEmpty);
        final rows = await db.announcementDao.allAnnouncements().get();
        expect(rows.single.background?.id, 7);
      },
    );
  });

  group('AnnouncementDao.announcementById — les valeurs brutes', () {
    test('rend la ligne telle que le serveur l\'a servie', () async {
      // Le composeur repart des **identifiants**, pas du modèle de lecture :
      // celui-ci a remplacé `accountId` et `backgroundId` par un nom de compte
      // et trois arrêts de dégradé, et retrouver un identifiant depuis un
      // libellé n'a pas de solution quand deux comptes ont le même nom court.
      await db.into(db.announcements).insert(
            announcementRow('a-1', accountId: 3, backgroundId: 5, title: 'Vig'),
          );

      final row =
          await db.announcementDao.announcementById('a-1').getSingleOrNull();

      expect(row?.accountId, 3);
      expect(row?.backgroundId, 5);
      expect(row?.title, 'Vig');
    });

    test('rend null pour une annonce retirée du magasin', () async {
      expect(
        await db.announcementDao.announcementById('absente').getSingleOrNull(),
        isNull,
      );
    });
  });
}
