import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/push/conversation_notification.dart';
import 'package:maison_du_miracle/data/push/push_wake_handler.dart';
import 'package:maison_du_miracle/data/push/wake_notifier.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../../data/local/local_database_fixtures.dart';
import '../../helpers/fake_sync_server.dart';
import '../../helpers/sync_fixtures.dart';
import 'notification_doubles.dart';

/// **Le réveil, de bout en bout** — et l'assertion sur laquelle toute la tranche se
/// juge : la notification locale est dressée depuis le **magasin**, jamais depuis la
/// charge utile du push (ADR-0006, PRD D6).
///
/// Ce que ce fichier monte est le **vrai chemin**, Firebase excepté : un magasin
/// Drift en mémoire, le vrai moteur de synchronisation restreint aux collections que
/// le réveil nomme, le double du serveur de synchronisation sur le transport de Dio,
/// et un notifieur qui note ce qu'on lui demande d'afficher. Seul le greffon de
/// notification est remplacé — c'est le seul morceau qui exige un appareil.
///
/// Depuis M5, la notification est celle d'une **conversation** : ses derniers
/// non-lus, la sourdine, l'aperçu masquable, l'effacement d'une conversation lue
/// ailleurs, le résumé.
void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;
  late RecordingNotifier notifier;
  late List<Set<String>> pulls;
  late bool preview;

  /// L'horloge des tests : après tous les messages des fixtures.
  final now = DateTime.utc(2026, 9, 10, 12);

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
    notifier = RecordingNotifier();
    pulls = [];
    preview = true;
  });

  tearDown(() => db.close());

  /// Le manifeste d'Échanges, et — au besoin — une page de lecture servie
  /// (`group_reads`) et une page de messages choisie.
  void serveEchanges({
    Map<String, Object?>? messages,
    Map<String, Object?>? read,
  }) {
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
          if (read != null)
            manifestEntry(
              SyncCollectionKey.groupReads,
              partition: 'private',
              currentCursor: _readCursor,
              hasChanges: true,
              fromZero: true,
            ),
        ],
      })
      ..serveCollection('profiles', profilesPage())
      ..serveCollection('groups', groupsPage())
      ..serveCollection('group_members', groupMembersPage())
      ..serveCollection('group_join_requests', groupJoinRequestsPage())
      ..serveCollection('group_messages', messages ?? groupMessagesPage());
    if (read != null) {
      server.serveCollection(
        'group_reads',
        deltaPage(items: [read], nextCursor: _readCursor),
      );
    }
  }

  /// **Le câblage du réveil d'une application fermée**, à l'identique de
  /// `push_background.dart` : un moteur **restreint** aux collections nommées, qui
  /// ne persiste **pas** la version de périmètre, et le magasin lu pour **moi**.
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
        store: StoreWakeStore(
          groups: db.groupDao,
          showPreview: () async => preview,
          userId: () => kMeId,
        ),
        notifier: notifier,
        texts: kTestNotificationTexts,
        now: () => now,
      );

  const msg1 = '019a3000-0000-7000-8000-00000000msg1';
  const msg3 = '019a3000-0000-7000-8000-00000000msg3';
  const msg4 = '019a3000-0000-7000-8000-00000000msg4';

  Map<String, Object?> wake(String messageId, {bool muted = false}) => {
        'type': muted ? 'group_message_muted' : 'group_message',
        'groupId': kGroupId,
        'messageId': messageId,
      };

  group('Un réveil de groupe', () {
    test('tire les collections du réveil, et elles seules', () async {
      serveEchanges();

      await handler().handle(wake(msg1));

      expect(pulls, hasLength(1));
      expect(pulls.single, {
        SyncCollectionKey.profiles,
        SyncCollectionKey.groups,
        SyncCollectionKey.groupMembers,
        // M5 : ma lecture (une conversation lue ailleurs n'a plus rien à
        // montrer) et ma sourdine (posée ailleurs).
        SyncCollectionKey.groupReads,
        SyncCollectionKey.groupMutes,
        SyncCollectionKey.groupMessages,
      });
      // Et c'est **ciblé** : les demandes d'adhésion ne sont pas demandées au
      // serveur, et aucune des autres collections du registre non plus. Un réveil
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
      await handler().handle({
        ...wake(msg1),
        'body': 'TEXTE VENU DU PUSH',
        'title': 'TITRE VENU DU PUSH',
        'authorName': 'NOM VENU DU PUSH',
      });

      expect(notifier.shown, hasLength(1));
      final shown = notifier.shown.single;
      // Le nom du groupe, lu dans `groups`.
      expect(shown.title, 'Chorale Harmonie');
      expect(shown.isGroup, isTrue);
      expect(shown.groupId, kGroupId);
      // **Les non-lus de la conversation**, du plus ancien au plus récent : ni
      // mon message, ni celui du serveur. Le nom de l'auteur vient de
      // `profiles` ; l'auteur retiré n'en a pas (ADR-0032).
      expect(shown.lines.map((l) => l.text), [
        'Répétition samedi à 16h, salle du fond.',
        'Que Dieu vous bénisse tous.',
      ]);
      expect(shown.lines.first.authorName, 'Estelle Adjo');
      expect(shown.lines.last.authorName, isNull);
      expect(shown.unreadCount, 2);
      expect(shown.alert, isTrue);

      // **L'assertion la plus importante de la tranche**, écrite en négatif : rien
      // de la charge utile n'atteint l'écran.
      for (final line in shown.lines) {
        expect(line.text, isNot(contains('PUSH')));
        expect(line.authorName ?? '', isNot(contains('PUSH')));
      }
      expect(shown.title, isNot(contains('PUSH')));
    });

    test('un message du serveur ne réveille personne', () async {
      serveEchanges();

      // `(null, true)` : « Un nouveau membre a rejoint le groupe. » La formule des
      // non-lus écarte le serveur — WhatsApp ne sonne pas pour une adhésion.
      await handler().handle(wake(msg3));

      expect(notifier.shown, isEmpty);
    });

    test('un auteur retiré se rend par une absence, pas par un nom inventé',
        () async {
      serveEchanges();

      await handler().handle(wake(msg4));

      final shown = notifier.shown.single;
      // Le corps d'une ligne part seul : « Membre retiré » est un **fait**, pas un
      // nom, et le préfixer le rendrait indiscernable d'un profil simplement pas
      // encore arrivé. MessagingStyle, lui, le dit comme le fil (« removed »).
      expect(shown.body, 'Que Dieu vous bénisse tous.');
      expect(shown.lines.last.authorKey, 'removed');
    });

    test('deux messages du même fil se remplacent, ils ne s\'empilent pas',
        () async {
      serveEchanges();

      await handler().handle(wake(msg1));
      await handler().handle(wake(msg4));

      expect(notifier.shown, hasLength(2));
      // Même identifiant système : la seconde notification **remplace** la
      // première, en l'allongeant — c'est la conversation qu'on notifie.
      expect(notifier.shown.first.id, notifier.shown.last.id);
      expect(notifier.shown.first.id, conversationNotificationId(kGroupId));
    });

    test('le résumé suit : il compte les non-lus des conversations notifiées',
        () async {
      serveEchanges();

      await handler().handle(wake(msg1));

      expect(notifier.summaries, isNotEmpty);
      final summary = notifier.summaries.last;
      expect(summary.totalUnread, 2);
      expect(summary.conversations, 1);
      expect(summary.title, '2 nouveaux messages');
      expect(summary.lines, ['Chorale Harmonie']);
    });
  });

  group('La sourdine tait', () {
    test('un réveil muet du serveur synchronise et n\'affiche rien', () async {
      serveEchanges();

      await handler().handle(wake(msg1, muted: true));

      // Le magasin a bien été rempli — un réveil muet n'est pas un réveil perdu…
      expect(pulls, hasLength(1));
      expect(await db.groupDao.latestMessageOf(kGroupId), isNotNull);
      // … mais rien ne s'affiche — et pas de résumé posé seul, qui
      // annoncerait ce qu'aucune notification ne montre.
      expect(notifier.shown, isEmpty);
      expect(notifier.summaries, isEmpty);
    });

    test('une sourdine connue du magasin tait aussi un réveil sonore',
        () async {
      serveEchanges();
      // Posée depuis ce téléphone, et le serveur ne l'a pas encore appliquée à
      // ce réveil-ci.
      await db.into(db.groupMutes).insert(
            GroupMutesCompanion.insert(
              groupId: kGroupId,
              mutedForever: const Value(true),
              muteChangedAt: Value(now.subtract(const Duration(minutes: 1))),
            ),
          );

      await handler().handle(wake(msg1));

      expect(notifier.shown, isEmpty);
    });

    test('une sourdine échue ne tait plus rien', () async {
      serveEchanges();
      await db.into(db.groupMutes).insert(
            GroupMutesCompanion.insert(
              groupId: kGroupId,
              mutedUntil: Value(now.subtract(const Duration(minutes: 1))),
              muteChangedAt: Value(now.subtract(const Duration(hours: 8))),
            ),
          );

      await handler().handle(wake(msg1));

      expect(notifier.shown, hasLength(1));
    });
  });

  group('L\'aperçu masquable', () {
    test('masqué dans un groupe : « Nouveau message de … », rien du texte',
        () async {
      preview = false;
      serveEchanges(messages: groupMessagesPage(items: [memberMessagePayload]));

      await handler().handle(wake(msg1));

      final shown = notifier.shown.single;
      expect(shown.lines, hasLength(1));
      expect(shown.lines.single.text, 'Nouveau message de Estelle Adjo');
      expect(shown.body, isNot(contains('Répétition')));
      // Le titre reste : c'est le nom de la conversation, pas son contenu.
      expect(shown.title, 'Chorale Harmonie');
    });
  });

  group('Une conversation lue ailleurs', () {
    test('sa notification s\'efface, et le résumé avec', () async {
      // Ma lecture, avancée sur un autre appareil jusqu'au dernier message.
      serveEchanges(read: {
        'id': 1,
        'groupId': kGroupId,
        'lastReadMessageId': msg4,
        'lastReadAt': '2026-09-03T11:00:00.000Z',
      });

      await handler().handle(wake(msg1));

      expect(notifier.shown, isEmpty);
      expect(notifier.cancelled, contains(kGroupId));
      expect(notifier.summaryCancelled, isPositive);
    });
  });

  group('Pas de ligne en magasin, pas de notification', () {
    test('un identifiant que le magasin ne connaît pas ne s\'annonce pas',
        () async {
      serveEchanges();

      await handler().handle(wake('019a3000-0000-7000-8000-0000000absent'));

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
        handler(syncFails: true).handle(wake(msg1)),
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

      await handler(syncFails: true).handle(wake(msg1));

      expect(notifier.shown, hasLength(1));
      expect(
        notifier.shown.single.lines.first.text,
        'Répétition samedi à 16h, salle du fond.',
      );
    });

    test('sans compte sur ce téléphone, aucune conversation à notifier',
        () async {
      serveEchanges();
      final anonymous = PushWakeHandler(
        synchronize: (_) async {},
        store: StoreWakeStore(
          groups: db.groupDao,
          showPreview: () async => true,
          userId: () => null,
        ),
        notifier: notifier,
        texts: kTestNotificationTexts,
      );

      await anonymous.handle(wake(msg1));

      expect(notifier.shown, isEmpty);
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

      await handler().handle(wake(msg1));

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

  group('Le notifieur inerte', () {
    test('n\'affiche rien, n\'efface rien, et ne lève pas', () async {
      const inert = InertWakeNotifier();
      await expectLater(inert.prepare(), completes);
      await expectLater(inert.cancel('g'), completes);
      await expectLater(inert.cancelSummary(), completes);
    });
  });
}

/// L'état de lecture servi par `group_reads` dans ces tests.
final String _readCursor = serverCursor(
  updatedAtIso: '2026-09-03T11:00:00.000Z',
  id: 1,
);

/// Une panne de cycle, nommée pour qu'un test se lise. Ce que le moteur remonte
/// vraiment est une `DioException` ; ce qui compte ici est que **toute** panne soit
/// avalée et ne produise aucune notification.
class SocketLikeFailure implements Exception {
  const SocketLikeFailure();
}
