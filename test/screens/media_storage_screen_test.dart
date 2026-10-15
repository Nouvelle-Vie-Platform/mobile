/// **L'écran « Stockage »** (T4, #226) : ce que chaque conversation occupe, et
/// de quoi vider.
///
/// Le peseur est **remplacé** ici, et c'est délibéré : il part dans un isolat et
/// touche de vrais fichiers, et la zone d'`async` d'un `testWidgets` ne fait
/// aboutir ni l'un ni l'autre. Ce que ce fichier vérifie est donc tout l'écran
/// — l'ordre, les chiffres, les noms, la confirmation, et la relecture après la
/// purge. Ce que le peseur rend, c'est
/// `test/data/messaging/media/message_media_usage_test.dart` qui le mesure, sur
/// du vrai disque.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/messaging/media/message_media_usage.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/message_media.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/media_storage_screen.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/message_media_storage_providers.dart';

import '../helpers/pump_screen.dart';
import '../helpers/signed_in_auth.dart';

final _fr = AppLocalizationsFr();

/// Un peseur qui ne pèse rien : il rend ce qu'on lui a dit, et **note** ce qu'on
/// lui demande de vider.
class _FakeStorage extends MessageMediaStorage {
  _FakeStorage(super.dao, this.usage);

  MessageMediaUsage usage;
  final List<String> purged = [];

  @override
  Future<MessageMediaUsage> weigh() async => usage;

  @override
  Future<void> purgeConversation(String groupId) async {
    purged.add('conversation:$groupId');
    usage = MessageMediaUsage(
      conversations: usage.conversations
          .where((c) => c.groupId != groupId)
          .toList(growable: false),
      byKind: usage.byKind,
    );
  }

  @override
  Future<void> purgeKind(MessageMediaKind kind) async {
    purged.add('kind:${kind.name}');
  }
}

ConversationMediaUsage _conversation(
  String groupId,
  int bytes, {
  String groupName = '',
  int files = 1,
}) =>
    ConversationMediaUsage(
      groupId: groupId,
      groupName: groupName,
      bytes: bytes,
      fileCount: files,
    );

ConversationView _view(String groupId, String title) => ConversationView(
      groupId: groupId,
      title: title,
      isDirect: true,
      memberCount: 2,
      canWrite: true,
    );

void main() {
  late _FakeStorage storage;

  Future<void> pump(
    WidgetTester tester, {
    required MessageMediaUsage usage,
    List<ConversationView> conversations = const [],
  }) async {
    // Un téléphone ordinaire, très haut : les deux sections doivent être
    // construites sans défiler.
    tester.view.physicalSize = const Size(1170, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    storage = _FakeStorage(db.groupDao, usage);

    await pumpScreen(
      tester,
      const MediaStorageScreen(),
      database: db,
      auth: SignedInAuthRepository(),
      echanges: InMemoryEchangesRepository(conversations: conversations),
      overrides: [
        messageMediaStorageProvider.overrideWithValue(storage),
      ],
    );
    await tester.pumpAndSettle();
  }

  Finder row(String groupId) =>
      find.byKey(MediaStorageScreen.conversationKey(groupId));

  group('L\'écran Stockage', () {
    testWidgets(
        'le total, les conversations du plus lourd au plus léger, '
        'et les poids par type', (tester) async {
      await pump(
        tester,
        usage: MessageMediaUsage(
          conversations: [
            _conversation('g-lourd', 8400000, groupName: 'Chorale', files: 9),
            _conversation('g-leger', 840000, groupName: 'Intercession'),
          ],
          byKind: const {
            MessageMediaKind.video: 7000000,
            MessageMediaKind.image: 2240000,
          },
        ),
      );

      expect(
        find.text(_fr.mediaStorageTotal('9,2 Mo')),
        findsOneWidget,
        reason: 'le total est celui que le peseur rend, formaté une seule fois',
      );
      // Le bandeau dit la décision : rien ne s'efface seul, et une purge se
      // rattrape par un téléchargement.
      expect(find.text(_fr.mediaStorageNotice), findsOneWidget);

      expect(find.text('Chorale'), findsOneWidget);
      expect(find.text(_fr.mediaStorageFiles(9)), findsOneWidget);
      expect(find.text('8,4 Mo'), findsOneWidget);
      expect(find.text('840 ko'), findsOneWidget);
      expect(find.text('7,0 Mo'), findsOneWidget);
      expect(find.text('2,2 Mo'), findsOneWidget);

      // L'ordre, lu dans l'arbre et non supposé.
      final lourd = tester.getTopLeft(row('g-lourd')).dy;
      final leger = tester.getTopLeft(row('g-leger')).dy;
      expect(lourd, lessThan(leger));

      // Les types, eux aussi du plus lourd au plus léger, avec les libellés
      // déjà traduits de l'aperçu des conversations.
      expect(find.text(_fr.m4PreviewVideo), findsOneWidget);
      expect(find.text(_fr.m4PreviewImage), findsOneWidget);
      final video = tester
          .getTopLeft(find.byKey(
            MediaStorageScreen.kindKey(MessageMediaKind.video),
          ))
          .dy;
      final image = tester
          .getTopLeft(find.byKey(
            MediaStorageScreen.kindKey(MessageMediaKind.image),
          ))
          .dy;
      expect(video, lessThan(image));
    });

    testWidgets(
        'le titre d\'un tête-à-tête vient de la liste des conversations',
        (tester) async {
      await pump(
        tester,
        usage: MessageMediaUsage(
          conversations: [
            // Le nom servi par le serveur pour un DM n'a pas été écrit pour
            // être lu : il ne doit jamais apparaître.
            _conversation('g-dm', 5000, groupName: 'direct:019a-019a'),
            // Un groupe quitté : il n'est plus dans la liste, ses fichiers
            // occupent pourtant la place et doivent rester purgeables.
            _conversation('g-parti', 4000),
          ],
          byKind: const {MessageMediaKind.image: 9000},
        ),
        conversations: [_view('g-dm', 'Pasteur Amavi')],
      );

      expect(find.text('Pasteur Amavi'), findsOneWidget);
      expect(find.text('direct:019a-019a'), findsNothing);
      expect(find.text(_fr.mediaStorageUnknownConversation), findsOneWidget);
      expect(row('g-parti'), findsOneWidget);
    });

    testWidgets('vider une conversation se confirme, puis se relit',
        (tester) async {
      await pump(
        tester,
        usage: MessageMediaUsage(
          conversations: [
            _conversation('g-1', 3000000, groupName: 'Chorale'),
            _conversation('g-2', 1000000, groupName: 'Intercession'),
          ],
          byKind: const {MessageMediaKind.image: 4000000},
        ),
      );

      await tester.tap(
        find.byKey(MediaStorageScreen.purgeConversationKey('g-1')),
      );
      await tester.pumpAndSettle();

      // On jette un fichier prêt : la confirmation est due, et elle promet le
      // retour du média.
      expect(find.text(_fr.mediaStoragePurgeTitle), findsOneWidget);
      expect(
        find.text(_fr.mediaStoragePurgeMessage('Chorale')),
        findsOneWidget,
      );

      // Annuler ne vide rien.
      await tester.tap(find.text(_fr.actionCancel));
      await tester.pumpAndSettle();
      expect(storage.purged, isEmpty);
      expect(row('g-1'), findsOneWidget);

      await tester.tap(
        find.byKey(MediaStorageScreen.purgeConversationKey('g-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_fr.mediaStoragePurgeAction));
      await tester.pumpAndSettle();

      expect(storage.purged, ['conversation:g-1']);
      // La pesée est relue : la ligne part de l'écran, et le total la suit.
      expect(row('g-1'), findsNothing);
      expect(row('g-2'), findsOneWidget);
      expect(find.text(_fr.mediaStorageTotal('1,0 Mo')), findsOneWidget);
    });

    testWidgets('vider un type demande bien ce type', (tester) async {
      await pump(
        tester,
        usage: MessageMediaUsage(
          conversations: [_conversation('g-1', 7000, groupName: 'Chorale')],
          byKind: const {MessageMediaKind.video: 7000},
        ),
      );

      await tester.tap(
          find.byKey(MediaStorageScreen.purgeKindKey(MessageMediaKind.video)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_fr.mediaStoragePurgeAction));
      await tester.pumpAndSettle();

      expect(storage.purged, ['kind:video']);
    });

    testWidgets('rien sur l\'appareil : le vide, pas une panne',
        (tester) async {
      await pump(tester, usage: MessageMediaUsage.empty);

      expect(find.text(_fr.mediaStorageEmpty), findsOneWidget);
      expect(find.text(_fr.mediaStorageTotal('0 o')), findsOneWidget);
      // Pas de section vide à purger.
      expect(find.text(_fr.mediaStorageByConversation.toUpperCase()),
          findsNothing);
    });
  });

  group('L\'entrée du Profil', () {
    testWidgets('« Stockage des médias » mène à l\'écran', (tester) async {
      final router = GoRouter(
        initialLocation: '/hote',
        routes: [
          GoRoute(
            path: '/hote',
            builder: (_, __) => Consumer(
              builder: (context, ref, __) {
                ref.watch(authProvider);
                return const Scaffold(body: ProfileScreen());
              },
            ),
          ),
          GoRoute(
            name: AppRoute.mediaStorage,
            path: '/settings/media/storage',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('PAGE_STOCKAGE'))),
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpRouter(tester, router, auth: SignedInAuthRepository());
      await tester.pumpAndSettle();

      expect(find.byKey(ProfileScreen.mediaStorageKey), findsOneWidget);
      await tester.tap(find.byKey(ProfileScreen.mediaStorageKey));
      await tester.pumpAndSettle();

      expect(find.text('PAGE_STOCKAGE'), findsOneWidget);
    });
  });
}
