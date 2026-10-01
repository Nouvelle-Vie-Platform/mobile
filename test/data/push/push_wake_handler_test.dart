import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/group_dao.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/push/push_wake_handler.dart';
import 'package:maison_du_miracle/data/push/wake_notifier.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../../data/local/local_database_fixtures.dart';
import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_fixtures.dart';

/// **Le réveil, de bout en bout** — et l'assertion sur laquelle toute la tranche se
/// juge : la notification locale est dressée depuis le **magasin**, jamais depuis la
/// charge utile du push (ADR-0006, PRD D6).
///
/// Ce que ce fichier monte est le **vrai chemin**, Firebase excepté : un magasin
/// Drift en mémoire, le vrai moteur de synchronisation restreint aux collections que
/// le réveil nomme, le double du serveur de synchronisation sur le transport de Dio,
/// et un notifieur qui note ce qu'on lui demande d'afficher. Seul le greffon de
/// notification est remplacé — c'est le seul morceau qui exige un appareil.
void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;
  late _RecordingNotifier notifier;
  late List<Set<String>> pulls;

  /// Les cinq collections d'« Échanges », pour servir un manifeste complet.
  const echanges = [
    SyncCollectionKey.profiles,
    SyncCollectionKey.groups,
    SyncCollectionKey.groupMembers,
    SyncCollectionKey.groupJoinRequests,
    SyncCollectionKey.groupMessages,
  ];

  String cursorOf(String key) => switch (key) {
        SyncCollectionKey.profiles => profilesCursor,
        SyncCollectionKey.groups => groupsCursor,
        SyncCollectionKey.groupMembers => groupMembersCursor,
        SyncCollectionKey.groupJoinRequests => groupJoinRequestsCursor,
        _ => groupMessagesCursor,
      };

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
    dao = db.syncDao;
    notifier = _RecordingNotifier();
    pulls = [];
  });

  tearDown(() => db.close());

  void serveEchanges() {
    server
      ..serveManifest({
        'scope_version': 7,
        'collections': [
          for (final key in echanges)
            manifestEntry(
              key,
              partition: kSyncCollections[key]!,
              currentCursor: cursorOf(key),
              hasChanges: true,
              fromZero: true,
            ),
        ],
      })
      ..serveCollection('profiles', profilesPage())
      ..serveCollection('groups', groupsPage())
      ..serveCollection('group_members', groupMembersPage())
      ..serveCollection('group_join_requests', groupJoinRequestsPage())
      ..serveCollection('group_messages', groupMessagesPage());
  }

  /// **Le câblage du réveil d'une application fermée**, à l'identique de
  /// `push_background.dart` : un moteur **restreint** aux collections nommées, qui
  /// ne persiste **pas** la version de périmètre.
  PushWakeHandler handler({bool syncFails = false}) => PushWakeHandler(
        synchronize: (collections) async {
          pulls.add(collections);
          if (syncFails) throw const SocketLikeFailure();
          final restricted = syncedCollections()
              .where((c) => collections.contains(c.key))
              .toList(growable: false);
          if (restricted.isEmpty) return;
          await SyncEngine(
            api: SyncApi(dio: dio),
            dao: dao,
            collections: restricted,
            persistsScopeVersion: false,
          ).synchronize();
        },
        announcement: db.groupDao.announcementFor,
        notifier: notifier,
      );

  group('Un réveil de groupe', () {
    test('tire les collections du réveil, et elles seules', () async {
      serveEchanges();

      await handler().handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-00000000msg1',
      });

      expect(pulls, hasLength(1));
      expect(pulls.single, {
        SyncCollectionKey.profiles,
        SyncCollectionKey.groups,
        SyncCollectionKey.groupMembers,
        SyncCollectionKey.groupMessages,
      });
      // Et c'est **ciblé** : la cinquième collection d'Échanges n'est pas demandée
      // au serveur, et aucune des dix-huit autres du registre non plus. Un réveil
      // n'a pas à payer un cycle complet sur une application fermée.
      expect(server.requestsFor('group_join_requests'), isEmpty);
      expect(server.requestsFor('teachings'), isEmpty);
      expect(server.requestsFor('announcements'), isEmpty);
      expect(server.requestsFor('group_messages'), isNotEmpty);
    });

    test('la notification est dressée depuis le magasin, JAMAIS depuis le push',
        () async {
      serveEchanges();

      // La charge utile porte ici un corps, un titre et un nom d'auteur — ce que le
      // serveur n'envoie jamais, mais qu'un intermédiaire pourrait. Rien de tout
      // cela ne doit paraître : le texte affiché est celui de `group_messages`, et
      // le nom celui de `profiles`.
      await handler().handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-00000000msg1',
        'body': 'TEXTE VENU DU PUSH',
        'title': 'TITRE VENU DU PUSH',
        'authorName': 'NOM VENU DU PUSH',
      });

      expect(notifier.shown, hasLength(1));
      final shown = notifier.shown.single;
      // Le nom du groupe, lu dans `groups`.
      expect(shown.title, 'Chorale Harmonie');
      // Le nom de l'auteur (`profiles`) et le corps du message (`group_messages`).
      expect(
          shown.body, 'Estelle Adjo : Répétition samedi à 16h, salle du fond.');
      expect(shown.groupId, kGroupId);

      // **L'assertion la plus importante de la tranche**, écrite en négatif : rien
      // de la charge utile n'atteint l'écran. Une notification peinte depuis le push
      // afficherait un message qui n'est pas en base, et le tap ouvrirait un fil qui
      // ne le contient pas.
      expect(shown.title, isNot(contains('PUSH')));
      expect(shown.body, isNot(contains('PUSH')));
    });

    test('un message système n\'est préfixé d\'aucun nom', () async {
      serveEchanges();

      await handler().handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-00000000msg3',
      });

      expect(notifier.shown.single.title, 'Chorale Harmonie');
      // Le serveur ne se présente pas, et surtout il ne porte aucun profil à
      // joindre : `(authorId, isSystem) = (null, true)`.
      expect(
        notifier.shown.single.body,
        'Un nouveau membre a rejoint le groupe.',
      );
    });

    test('un auteur retiré se rend par une absence, pas par un nom inventé',
        () async {
      serveEchanges();

      // `(null, false)` — ADR-0032. Le corps part seul : « Membre retiré » est un
      // **fait**, pas un nom, et l'écrire ici le rendrait indiscernable d'un profil
      // simplement pas encore arrivé.
      await handler().handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-00000000msg4',
      });

      expect(notifier.shown.single.body, 'Que Dieu vous bénisse tous.');
      expect(notifier.shown.single.body, isNot(contains('retiré')));
    });

    test('deux messages du même fil se remplacent, ils ne s\'empilent pas',
        () async {
      serveEchanges();

      await handler().handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-00000000msg1',
      });
      await handler().handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-00000000msg3',
      });

      expect(notifier.shown, hasLength(2));
      // Même identifiant système : la seconde notification **remplace** la
      // première. Dix notifications pour une conversation ne seraient pas un défaut
      // de groupage, ce serait un défaut tout court.
      expect(notifier.shown.first.id, notifier.shown.last.id);
    });
  });

  group('Pas de ligne en magasin, pas de notification', () {
    test('un identifiant que le magasin ne connaît pas ne s\'annonce pas',
        () async {
      serveEchanges();

      await handler().handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-0000000absent',
      });

      // La synchronisation a bien eu lieu — le réveil n'est pas inerte —, mais le
      // message n'est pas arrivé : modération entre l'envoi du push et le tirage, ou
      // serveur en retard. Annoncer « Nouveau message » serait affirmer sur la seule
      // foi du push l'existence de ce que la base ne porte pas.
      expect(pulls, hasLength(1));
      expect(notifier.shown, isEmpty);
    });

    test('une synchronisation échouée n\'invente rien, et ne lève pas',
        () async {
      serveEchanges();

      await expectLater(
        handler(syncFails: true).handle(const {
          'type': 'group_message',
          'groupId': kGroupId,
          'messageId': '019a3000-0000-7000-8000-00000000msg1',
        }),
        completes,
      );

      expect(notifier.shown, isEmpty);
    });

    test('un magasin déjà pourvu annonce même si le cycle échoue', () async {
      // Le pendant du test précédent, et il compte autant : on continue vers la
      // lecture après un cycle raté, parce que le message peut déjà être là — ramené
      // par un cycle antérieur.
      serveEchanges();
      await SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) => echanges.contains(c.key))
            .toList(growable: false),
      ).synchronize();

      await handler(syncFails: true).handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-00000000msg1',
      });

      expect(notifier.shown, hasLength(1));
      expect(
        notifier.shown.single.body,
        'Estelle Adjo : Répétition samedi à 16h, salle du fond.',
      );
    });
  });

  group('Un nudge de synchronisation', () {
    test('pousse le moteur et n\'affiche rien', () async {
      server
        ..serveManifest({
          'scope_version': 7,
          'collections': [
            manifestEntry(
              SyncCollectionKey.profiles,
              partition: 'private',
              currentCursor: profilesCursor,
              hasChanges: true,
              fromZero: true,
            ),
          ],
        })
        ..serveCollection('profiles', profilesPage());

      await handler().handle(const {
        'type': 'sync_nudge',
        'collection': 'profiles',
      });

      expect(pulls.single, {'profiles'});
      // L'UX de réveil des domaines autres que les messages est hors périmètre
      // (#97) : la synchronisation est l'effet entier d'un nudge.
      expect(notifier.shown, isEmpty);
    });

    test('une collection que ce client ne réplique pas ne tire rien', () async {
      await handler().handle(const {
        'type': 'sync_nudge',
        'collection': 'collection_dun_serveur_plus_recent',
      });

      // Le handler a bien été appelé avec la clé — c'est le câblage qui décide de
      // n'en rien faire —, et aucun manifeste n'est parti.
      expect(pulls.single, {'collection_dun_serveur_plus_recent'});
      expect(server.manifestRequests, isEmpty);
      expect(notifier.shown, isEmpty);
    });
  });

  group('Ce qui n\'est pas un réveil connu', () {
    test('ne synchronise rien et n\'affiche rien', () async {
      // Surtout pas « au mieux » : synchroniser tout le magasin sur un push qu'on ne
      // comprend pas réveillerait la radio d'un téléphone pour rien.
      await handler().handle(const {
        'type': 'announcement_published',
        'notificationId': 'n-1',
      });

      expect(pulls, isEmpty);
      expect(server.manifestRequests, isEmpty);
      expect(notifier.shown, isEmpty);
    });
  });

  group('Un moteur restreint ne persiste pas la version de périmètre', () {
    test('la `scope_version` reste celle d\'avant le réveil', () async {
      serveEchanges();

      await handler().handle(const {
        'type': 'group_message',
        'groupId': kGroupId,
        'messageId': '019a3000-0000-7000-8000-00000000msg1',
      });

      // ⚠️ Le corollaire de la règle 2 d'ADR-0027. La `scope_version` est
      // **globale** : la persister après un cycle qui n'a visité que trois
      // collections éteindrait le resync que les vingt autres n'ont pas encore fait,
      // et le manifeste ne le redemanderait **jamais** — il recevrait une version à
      // jour. Le magasin garderait pour toujours des lignes sorties du périmètre,
      // sans qu'aucune erreur ne le dise.
      expect(await dao.readScopeVersion(), isNull);
    });

    test('un cycle complet, lui, la persiste', () async {
      // Le contrepoint, sans lequel le test précédent passerait aussi sur un moteur
      // qui ne persiste jamais rien.
      serveEchanges();

      await SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) => echanges.contains(c.key))
            .toList(growable: false),
      ).synchronize();

      expect(await dao.readScopeVersion(), 7);
    });
  });

  group('La notification, dressée hors de tout canal', () {
    test('un tête-à-tête porte le nom de la personne', () {
      final notification = announcementNotification(
        const MessageAnnouncement(
          messageId: 'm',
          groupId: 'g',
          groupName: 'Kossi Amavi, Estelle Adjo',
          isDirect: true,
          body: 'Bonsoir, es-tu disponible demain ?',
          authorId: 'u',
          isSystem: false,
          authorName: 'Estelle Adjo',
        ),
      );

      // Le titre d'un DM est le nom de la personne, pas celui que le serveur a donné
      // au groupe — la règle de `GroupDao.conversationsOf`, tenue ici aussi.
      expect(notification!.title, 'Estelle Adjo');
      expect(notification.body, 'Bonsoir, es-tu disponible demain ?');
    });

    test('un tête-à-tête sans nom retombe sur le groupe', () {
      final notification = announcementNotification(
        const MessageAnnouncement(
          messageId: 'm',
          groupId: 'g',
          groupName: 'Conversation',
          isDirect: true,
          body: 'Paix sur toi.',
          authorId: 'u',
          isSystem: false,
          authorName: null,
        ),
      );

      expect(notification!.title, 'Conversation');
    });

    test('un groupe que le magasin ne nomme pas encore ne s\'annonce pas', () {
      // Mieux vaut se taire qu'annoncer « (sans titre) » : une notification vide
      // ressemble à une donnée perdue.
      expect(
        announcementNotification(
          const MessageAnnouncement(
            messageId: 'm',
            groupId: 'g',
            groupName: null,
            isDirect: false,
            body: 'Amen.',
            authorId: 'u',
            isSystem: false,
            authorName: 'Estelle Adjo',
          ),
        ),
        isNull,
      );
    });

    test('un corps vide ne s\'annonce pas', () {
      expect(
        announcementNotification(
          const MessageAnnouncement(
            messageId: 'm',
            groupId: 'g',
            groupName: 'Chorale',
            isDirect: false,
            body: '   ',
            authorId: 'u',
            isSystem: false,
            authorName: 'Estelle',
          ),
        ),
        isNull,
      );
    });

    test('l\'identifiant système est positif et stable par fil', () {
      MessageAnnouncement of(String groupId) => MessageAnnouncement(
            messageId: 'm',
            groupId: groupId,
            groupName: 'Chorale',
            isDirect: false,
            body: 'Amen.',
            authorId: 'u',
            isSystem: false,
            authorName: 'Estelle',
          );

      final first = announcementNotification(of('grp-1'))!;
      final again = announcementNotification(of('grp-1'))!;
      final other = announcementNotification(of('grp-2'))!;

      // Positif : Android accepte les négatifs, iOS non.
      expect(first.id, greaterThanOrEqualTo(0));
      expect(first.id, again.id);
      expect(first.id, isNot(other.id));
    });
  });

  group('Le notifieur inerte', () {
    test('n\'affiche rien et ne lève pas', () async {
      const inert = InertWakeNotifier();
      await expectLater(inert.prepare(), completes);
      await expectLater(
        inert.show(
          const WakeNotification(
            id: 1,
            title: 'Chorale',
            body: 'Amen.',
            groupId: 'g',
          ),
        ),
        completes,
      );
    });
  });
}

/// Un notifieur qui **note** au lieu d'afficher : aucun canal de greffon, et ce que
/// le test lit est exactement ce qui serait parti à l'écran.
class _RecordingNotifier implements WakeNotifier {
  final List<WakeNotification> shown = [];

  @override
  Future<void> prepare() async {}

  @override
  Future<void> show(WakeNotification notification) async =>
      shown.add(notification);
}

/// Une panne de cycle, nommée pour qu'un test se lise. Ce que le moteur remonte
/// vraiment est une `DioException` ; ce qui compte ici est que **toute** panne soit
/// avalée et ne produise aucune notification.
class SocketLikeFailure implements Exception {
  const SocketLikeFailure();
}
