// **Ce que le composeur lit du magasin**, sur une vraie base en mémoire.
//
// Deux lectures que la visionneuse n'avait pas besoin de faire : la liste des
// comptes que je peux signer avec les fonds que je peux choisir, et la ligne
// **brute** d'une annonce à modifier. Toutes deux passent par un flux — la
// synchronisation réécrit sous les pieds de l'écran —, et le premier combine
// deux requêtes en une seule émission, ce qui mérite d'être prouvé plutôt que
// supposé.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/store_announcement_repository.dart';
import 'package:maison_du_miracle/models/announcement_draft.dart';

import 'local/local_database_fixtures.dart';

void main() {
  late AppDatabase db;
  late StoreAnnouncementRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = StoreAnnouncementRepository(db.announcementDao);
  });

  tearDown(() => db.close());

  group('composerOptions — mes comptes et les fonds actifs', () {
    test('n\'émet qu\'une fois les deux lectures arrivées', () async {
      await db.batch((b) {
        b.insert(
          db.officialAccounts,
          officialAccountRow(
            3,
            name: 'Diaconat de la Maison du Miracle — Bè Kpota',
            shortName: 'Diaconat',
            backgroundId: 5,
          ),
        );
        b.insert(db.officialAccountMemberships, membershipRow(1, accountId: 3));
        b.insert(db.statusBackgrounds, statusBackgroundRow(5));
      });

      final options = await repository.composerOptions(locale: 'fr').first;

      // Le même repli que l'en-tête du mur : un membre doit reconnaître dans le
      // sélecteur la signature qu'il verra ensuite sur son statut.
      expect(options.accounts.single.name, 'Diaconat');
      expect(options.accounts.single.backgroundId, 5);
      expect(options.backgrounds.single.id, 5);
      // Les trois arrêts arrivent **dérivés par le serveur** : on les lit, on ne
      // les recalcule pas.
      expect(options.backgrounds.single.backdrop.topColor, 0xFF2E4CAE);
    });

    test('un fond dont les couleurs ne se lisent pas n\'est pas proposé',
        () async {
      // La pastille du sélecteur **est** le dégradé : sans arrêts, il n'y a rien
      // d'honnête à peindre à sa place — le repli du mur est dérivé de
      // l'identifiant de l'annonce, qui n'existe pas encore.
      await db.into(db.statusBackgrounds).insert(
            statusBackgroundRow(9, topColor: 'pas-une-couleur'),
          );

      final options = await repository.composerOptions(locale: 'fr').first;

      expect(options.backgrounds, isEmpty);
    });

    test('le flux ré-émet quand la synchronisation ajoute un fond', () async {
      final emissions = <int>[];
      final subscription = repository
          .composerOptions(locale: 'fr')
          .listen((options) => emissions.add(options.backgrounds.length));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.into(db.statusBackgrounds).insert(statusBackgroundRow(1));
      await pumpEventQueue();

      // C'est ce qui fait qu'un fond ajouté au portail apparaît au cycle
      // suivant, sans que le membre rouvre l'écran.
      expect(emissions, [0, 1]);
    });
  });

  group('draftOf — l\'annonce telle qu\'on la modifie', () {
    test('rend les identifiants bruts, jamais des valeurs résolues', () async {
      await db.into(db.announcements).insert(
            announcementRow(
              'a-1',
              accountId: 3,
              backgroundId: 5,
              title: 'Convention',
              expiresAt: DateTime.utc(2026, 6, 1),
            ),
          );

      final draft = await repository.draftOf('a-1').first;

      expect(draft, isNotNull);
      expect(draft!.accountId, 3);
      expect(draft.backgroundId, 5);
      expect(draft.title, 'Convention');
      // Drift rend ses instants en heure **locale** ; on compare donc des
      // instants, pas des représentations. Le fil, lui, ne voit que de l'UTC —
      // `announcementPayload` normalise à l'envoi.
      expect(draft.expiresAt!.toUtc(), DateTime.utc(2026, 6, 1));
      // Jamais `now` : réenvoyer « maintenant » ferait remonter en tête du mur
      // une annonce qu'on rouvrait pour corriger une faute de frappe.
      expect(draft.timing, PublicationTiming.scheduled);
      expect(draft.publishedAt!.toUtc(), DateTime.utc(2026, 5, 1, 8));
    });

    test(
      'une affiche déjà déposée est comptée comme du contenu',
      () async {
        // On n'a que son URL, pas ses octets. Sans ce rattrapage, rouvrir une
        // affiche pour changer sa date de fin la ferait refuser comme « rien à
        // publier ».
        await db.into(db.announcements).insert(
              announcementRow(
                'a-1',
                backgroundImageUrl: '/uploads/announcements/affiche.jpg',
              ),
            );

        final draft = await repository.draftOf('a-1').first;

        expect(draft!.hasBackgroundImage, isTrue);
        expect(draft.issuesAt(DateTime.utc(2026, 5, 2)), isEmpty);
      },
    );

    test(
      'un audio ou une vidéo déjà déposés sont comptés comme du contenu',
      () async {
        // Un statut qui n'est qu'un média : le rouvrir pour changer sa date de
        // fin ne doit pas le faire refuser comme « rien à publier ».
        await db.into(db.announcements).insert(
              announcementRow('a-1').copyWith(
                mediaKind: const Value('video'),
                mediaUrl: const Value('https://media.example.test/v.m3u8'),
              ),
            );

        final draft = await repository.draftOf('a-1').first;

        expect(draft!.hasMedia, isTrue);
        expect(draft.issuesAt(DateTime.utc(2026, 5, 2)), isEmpty);
      },
    );

    test('un genre de média inconnu ne compte pas comme du contenu', () async {
      await db.into(db.announcements).insert(
            announcementRow('a-1').copyWith(
              mediaKind: const Value('hologramme'),
              mediaUrl: const Value('https://media.example.test/v.m3u8'),
            ),
          );

      final draft = await repository.draftOf('a-1').first;

      expect(draft!.hasMedia, isFalse);
    });

    test('rend null quand l\'annonce a été rétractée', () async {
      expect(await repository.draftOf('absente').first, isNull);
    });
  });
}
