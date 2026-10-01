/// **L'écho optimiste, et la clé d'idempotence qui va avec** (#96, décision 2 du
/// cadrage).
///
/// Ce que ce fichier défend tient en une phrase : un membre qui tape « amen » doit
/// le voir **avant** que le réseau togolais ait fini d'y penser, et le double appui
/// que cet écho évite à l'écran ne doit pas se produire **au réseau** à la place.
///
/// C'est une **rupture assumée** avec le composeur d'annonces, qui attend la réponse
/// du serveur avant de montrer quoi que ce soit. Elle est défendable pour une
/// publication, fausse pour une conversation.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/group_message_composer.dart';
import 'package:maison_du_miracle/data/repositories/group_message_sender.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';

import 'local/local_database_fixtures.dart';

/// Un envoyeur **scripté** : il note ce qu'on lui a demandé de poster, et il dit
/// ce qu'on lui a dit de dire.
class _ScriptedSender implements GroupMessageSender {
  /// Mutable, et c'est ce qui compte : le test de « réessayer » fait **échouer**
  /// le premier envoi puis réussir le second, sous la même clé.
  bool succeeds = true;
  final List<Map<String, Object?>> posted = [];

  @override
  Future<bool> send({
    required String groupId,
    required String body,
    required String clientMessageId,
    required DateTime clientCreatedAt,
  }) async {
    posted.add({
      'groupId': groupId,
      'body': body,
      'clientMessageId': clientMessageId,
      'clientCreatedAt': clientCreatedAt,
    });
    return succeeds;
  }
}

void main() {
  late AppDatabase db;
  late _ScriptedSender sender;
  late int cycles;
  late GroupMessageComposer composer;

  const String me = 'u-me';
  const String groupId = 'g-1';
  const String mintedKey = '019a4000-0000-7000-8000-00000000key1';

  setUp(() {
    db = openTestDatabase();
    sender = _ScriptedSender();
    cycles = 0;
    composer = GroupMessageComposer(
      dao: db.groupDao,
      sender: sender,
      resynchronize: () async => cycles++,
      // L'horloge et la frappe de clé sont **injectables**, et il le faut : un
      // test doit pouvoir nommer la clé qu'il va retrouver dans
      // `pending_group_messages` **et** dans le corps posté. Sans elles, l'ordre
      // de l'écho et l'idempotence seraient intestables.
      now: () => DateTime.utc(2026, 9, 10, 10),
      mintId: () => mintedKey,
    );
  });

  tearDown(() => db.close());

  StoreEchangesRepository repository() =>
      StoreEchangesRepository(db.groupDao, userId: me);

  group('L\'écho paraît avant le réseau', () {
    test(
        'le message est au fil, en « cours d\'envoi », et la clé part avec lui',
        () async {
      await composer.send(groupId: groupId, body: '  Amen  ');

      final thread = await repository().thread(groupId).first;
      expect(thread, hasLength(1));
      final echo = thread.single;

      // L'écho est **mien** et **en cours** : c'est tout ce que l'écran a besoin
      // de savoir pour le dessiner.
      expect(echo.body, 'Amen', reason: 'le corps est élagué avant tout');
      expect(echo.delivery, MessageDelivery.sending);
      expect(echo.origin, MessageOrigin.member);
      // Son identifiant est la **clé d'idempotence** : il n'a pas encore
      // d'identité serveur, et c'est par elle que la réconciliation se fera.
      expect(echo.id, mintedKey);

      // ⚠️ **La clé est partie au serveur**, et c'est l'obligation qui découle de
      // l'écho : sans elle, le double appui que l'écho évite à l'écran se produit
      // quand même au réseau. Le serveur l'attend déjà — unicité
      // `(group_id, author_id, client_message_id)`.
      expect(sender.posted.single['clientMessageId'], mintedKey);
      expect(sender.posted.single['body'], 'Amen');
      expect(sender.posted.single['clientCreatedAt'], isA<DateTime>());
    });

    test('un envoi réussi déclenche un cycle, et n\'écrit pas la ligne finale',
        () async {
      await composer.send(groupId: groupId, body: 'Amen');

      // « Le réseau ne peint jamais » : le serveur assigne l'`id` (un UUIDv7 qui
      // est aussi le curseur), et c'est le flux delta qui ramène la ligne.
      expect(cycles, 1);
      expect(await db.select(db.groupMessages).get(), isEmpty);
      expect(await db.select(db.pendingGroupMessages).get(), hasLength(1));
    });

    test('un texte vide ne pose rien du tout', () async {
      // Le bouton d'envoi d'un champ vide ne doit pas laisser de trace — c'est
      // exactement ce que faisait la barre de saisie avant le branchement : elle
      // lisait une chaîne toujours vide et repartait.
      expect(await composer.send(groupId: groupId, body: '   '), isNull);

      expect(await db.select(db.pendingGroupMessages).get(), isEmpty);
      expect(sender.posted, isEmpty);
    });

    test('un double appui ne pose qu\'un écho, sous la même clé', () async {
      await composer.send(groupId: groupId, body: 'Amen');
      await composer.send(groupId: groupId, body: 'Amen');

      // `insertOrReplace` sur la clé : le second appui réécrit le premier écho
      // plutôt que d'en poser un second. Et c'est **la même clé** qui empêche le
      // doublon au réseau, où le serveur renverra l'existant.
      expect(await db.select(db.pendingGroupMessages).get(), hasLength(1));
      expect(
        sender.posted.map((p) => p['clientMessageId']).toSet(),
        {mintedKey},
      );
    });
  });

  group('Un envoi qui n\'est pas parti le dit', () {
    test('l\'écho passe en échec, et le message reste à l\'écran', () async {
      sender.succeeds = false;

      await composer.send(groupId: groupId, body: 'Amen');

      final echo = (await repository().thread(groupId).first).single;
      // Sans cet état, un message perdu resterait « en cours d'envoi » pour
      // toujours : le pire des deux mondes, puisque la personne croirait avoir
      // parlé.
      expect(echo.delivery, MessageDelivery.failed);
      expect(echo.body, 'Amen');
      // Et aucun cycle n'a été déclenché : il n'y a rien à aller chercher.
      expect(cycles, 0);
    });

    test('« réessayer » repart sous la MÊME clé', () async {
      sender.succeeds = false;
      final key = await composer.send(groupId: groupId, body: 'Amen');
      expect(key, mintedKey);

      sender.succeeds = true;
      expect(await composer.retry(key!), isTrue);

      // ⚠️ **La même clé, et c'est tout l'intérêt** : si le premier envoi avait en
      // réalité abouti — réponse perdue, coupure après le `POST` —, le serveur
      // reconnaît la clé et renvoie le message existant au lieu d'en créer un
      // second. Frapper une clé neuve ferait du « réessayer » le doublon que la
      // clé existe pour éviter.
      expect(sender.posted, hasLength(2));
      expect(
        sender.posted.map((p) => p['clientMessageId']).toSet(),
        {mintedKey},
      );
      expect(cycles, 1);
    });

    test('« abandonner » retire l\'écho du fil', () async {
      sender.succeeds = false;
      final key = await composer.send(groupId: groupId, body: 'Amen');

      await composer.discard(key!);

      expect(await repository().thread(groupId).first, isEmpty);
      expect(await db.select(db.pendingGroupMessages).get(), isEmpty);
    });
  });

  group('La réconciliation se fait sur la clé', () {
    /// La ligne **autoritaire** que le flux delta ramènerait, portant la même clé
    /// d'idempotence que l'écho.
    Future<void> deliverServerRow() => db.into(db.groupMessages).insert(
          GroupMessagesCompanion.insert(
            id: '019a3000-0000-7000-8000-000000000001',
            groupId: groupId,
            authorId: const Value(me),
            body: 'Amen',
            clientMessageId: const Value(mintedKey),
            createdAt: Value(DateTime.utc(2026, 9, 10, 10, 0, 2)),
          ),
        );

    test('l\'écho disparaît dès que la ligne serveur arrive, sans doublon',
        () async {
      await composer.send(groupId: groupId, body: 'Amen');
      expect(await repository().thread(groupId).first, hasLength(1));

      await deliverServerRow();

      final thread = await repository().thread(groupId).first;
      // **Un seul message**, et c'est celui du serveur : l'écho est filtré à la
      // lecture tant que sa clé est présente dans `group_messages`.
      expect(thread, hasLength(1));
      expect(thread.single.id, '019a3000-0000-7000-8000-000000000001');
      expect(thread.single.delivery, MessageDelivery.sent);
    });

    test('le filtre est à la lecture, pas une suppression différée', () async {
      // ⚠️ La ligne en attente est **encore là** : supprimer l'écho au retour du
      // `POST` aurait fait disparaître le message de l'écran pendant le temps —
      // court mais réel — qui sépare la réponse du cycle qui ramène la ligne. Un
      // message qui clignote est pire qu'un message marqué « en cours d'envoi ».
      await composer.send(groupId: groupId, body: 'Amen');
      await deliverServerRow();

      expect(await db.select(db.pendingGroupMessages).get(), hasLength(1));
      expect(await repository().thread(groupId).first, hasLength(1));

      // Le ramassage, lui, vient après — et aucun écran n'en dépend.
      expect(await db.groupDao.purgeReconciled(), 1);
      expect(await db.select(db.pendingGroupMessages).get(), isEmpty);
      expect(await repository().thread(groupId).first, hasLength(1));
    });

    test('un écho d\'un autre groupe n\'est pas ramassé par erreur', () async {
      // Le ramassage se fait sur la clé, qui est unique par construction ; ce test
      // existe pour qu'un `DELETE` écrit un jour « par groupe » ne passe pas.
      await composer.send(groupId: groupId, body: 'Amen');
      await db.groupDao.rememberPending(
        clientMessageId: 'autre-cle',
        groupId: 'g-2',
        body: 'Alléluia',
        createdAt: DateTime.utc(2026, 9, 10, 11),
      );
      await deliverServerRow();

      expect(await db.groupDao.purgeReconciled(), 1);
      final left = await db.select(db.pendingGroupMessages).get();
      expect(left.map((p) => p.clientMessageId), ['autre-cle']);
    });
  });
}
