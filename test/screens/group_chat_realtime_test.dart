/// **Le temps réel vu depuis la conversation ouverte** (#101).
///
/// `test/data/open_thread_channel_test.dart` prouve qu'un signal déclenche un
/// cycle et rien d'autre. Ça ne dit rien de ce qui compte ici : que *l'écran*
/// ouvre le canal, que le magasin reste intact quand un signal arrive, et que
/// quitter l'écran rende la socket. Un canal non branché ne casse aucun test de
/// socle — il laisse simplement la conversation muette, ce qui est exactement
/// l'état d'avant la tranche.
///
/// Les quatre assertions de l'issue, dans l'ordre d'importance :
///
/// 1. un signal reçu déclenche **un cycle** et **n'écrit rien** dans Drift ;
/// 2. quitter l'écran **ferme** la connexion ;
/// 3. l'application est **exactement la même** sans SSE — serveur injoignable ou
///    canal refusé, aucune erreur ne paraît ;
/// 4. une reconnexion déclenche un cycle (vérifiée dans le fichier d'à côté, où
///    l'on peut piloter le temps).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/realtime/group_channel.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/screens/group_chat_screen.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/widgets/chat/chat_bubble.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/pump_screen.dart';

const String _groupId = 'g-1';

final _fr = AppLocalizationsFr();

const GroupDetailView _group = GroupDetailView(
  groupId: _groupId,
  title: 'Chorale Harmonie',
  isDirect: false,
  memberCount: 3,
  canWrite: true,
);

/// Un fil déjà peint par le magasin : c'est lui qui doit rester à l'écran quoi
/// qu'il arrive au canal.
final List<GroupMessageView> _thread = [
  GroupMessageView(
    id: 'm-1',
    groupId: _groupId,
    body: 'Répétition samedi à 16h.',
    origin: messageOriginOf(authorId: 'u-peer', isSystem: false),
    mine: false,
    delivery: MessageDelivery.sent,
    authorId: 'u-peer',
    authorName: 'Estelle Adjo',
    createdAt: DateTime.utc(2026, 9, 3, 10, 30),
  ),
];

/// Un canal piloté par le test, qui compte ses ouvertures et ses fermetures.
class _ScriptedChannel implements GroupChannel {
  final List<String> opened = [];
  int cancelled = 0;
  StreamController<GroupChannelSignal>? _current;

  @override
  Stream<GroupChannelSignal> watch(String groupId) {
    opened.add(groupId);
    final controller = StreamController<GroupChannelSignal>();
    controller.onCancel = () => cancelled++;
    _current = controller;
    return controller.stream;
  }

  void signal() => _current!.add(const GroupChannelSignal());

  /// Le serveur est injoignable.
  void breakDown() => _current!.addError(const SocketException('réseau coupé'));

  /// Le serveur refuse l'abonnement : je ne suis pas membre.
  void refuse() =>
      _current!.addError(const GroupChannelRefused('groups/$_groupId', 400));
}

void main() {
  late _ScriptedChannel channel;
  late int cycles;
  late AppDatabase db;

  setUp(() {
    channel = _ScriptedChannel();
    cycles = 0;
    db = openTestDatabase();
    addTearDown(db.close);
  });

  /// Monte la conversation avec un canal piloté, un magasin **réel** en mémoire et
  /// un déclencheur de cycle qui ne fait que compter.
  ///
  /// Le magasin réel n'est pas un détail : c'est lui qui rend l'assertion
  /// « l'événement n'écrit rien » vérifiable. Un double en mémoire ne pourrait
  /// jamais prouver qu'une table est restée vide.
  Future<void> pumpConversation(WidgetTester tester) => pumpScreen(
        tester,
        const GroupChatScreen(groupId: _groupId),
        database: db,
        channel: channel,
        echanges: InMemoryEchangesRepository(
          groups: {_groupId: _group},
          threads: {_groupId: _thread},
        ),
        overrides: [
          // Le vrai `openThreadSyncProvider` ouvrirait le planificateur, donc
          // `ApiClient` et une socket. Ici on ne veut qu'une chose : savoir
          // **combien** de cycles un signal demande.
          openThreadSyncProvider.overrideWithValue(() async {
            cycles++;
          }),
        ],
      );

  /// Démonte l'arbre, donc le `ProviderScope` : c'est le geste qui ferme la
  /// connexion, et il doit être explicite dans les tests où une minuterie de
  /// réouverture reste armée — sinon le harnais attend ce que plus rien ne possède.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('ouvrir la conversation ouvre le canal de CE groupe',
      (tester) async {
    await pumpConversation(tester);

    expect(channel.opened, [_groupId]);
    expect(
      cycles,
      0,
      reason: 'demander un canal ne synchronise pas ; c\'est l\'abonnement '
          'réussi qui porte le signal, et le double ne l\'émet pas tout seul',
    );

    await leave(tester);
  });

  testWidgets('UN SIGNAL DÉCLENCHE UN CYCLE, ET N\'ÉCRIT RIEN DANS LE MAGASIN',
      (tester) async {
    // ⚠️ **L'assertion la plus importante de la tranche.** Un événement SSE est un
    // signal, jamais une source de vérité (ADR-0006) : il pousse le moteur, et
    // c'est le moteur qui écrit. Écrire ici donnerait deux écritures concurrentes
    // dans la même table, deux curseurs qui se croisent, et un message qui arrive
    // par les deux chemins — le chemin mixte que la décision 1 du cadrage
    // d'Échanges a refusé.
    //
    // Le garde-fou de source de `open_thread_channel_test.dart` dit la même chose
    // sous une forme qu'on ne peut pas contourner ; celui-ci dit qu'à l'exécution,
    // dans l'écran réel, rien n'est passé par la porte.
    await pumpConversation(tester);

    channel.signal();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(cycles, 1);
    expect(
      await db.select(db.groupMessages).get(),
      isEmpty,
      reason:
          'le corps diffusé par le serveur n\'a pas été désérialisé : c\'est '
          'au cycle de synchronisation d\'aller chercher la ligne',
    );
    expect(await db.select(db.pendingGroupMessages).get(), isEmpty);
    expect(await db.select(db.profiles).get(), isEmpty);
    expect(await db.select(db.groups).get(), isEmpty);
    expect(await db.select(db.groupMembers).get(), isEmpty);

    // Et le fil n'a pas bougé pour autant : ce qui le peint est le magasin, pas le
    // réseau. Un signal accélère le prochain cycle, il ne dessine rien.
    expect(find.text('Répétition samedi à 16h.'), findsOneWidget);

    await leave(tester);
  });

  testWidgets('trois messages en rafale ne posent toujours rien dans Drift',
      (tester) async {
    await pumpConversation(tester);

    channel
      ..signal()
      ..signal()
      ..signal();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(cycles, 3);
    expect(await db.select(db.groupMessages).get(), isEmpty);

    await leave(tester);
  });

  testWidgets('quitter l\'écran ferme la connexion', (tester) async {
    // Le piège 2 de l'issue : le flux ne se ferme pas tout seul au démontage. Si
    // personne n'annule, la connexion survit à l'écran — et un test qui échoue
    // laisse le harnais attendre.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.push('/group-chat/$_groupId'),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/group-chat/:id',
          builder: (context, state) =>
              GroupChatScreen(groupId: state.pathParameters['id']!),
        ),
      ],
    );

    await pumpRouter(
      tester,
      router,
      database: db,
      channel: channel,
      echanges: InMemoryEchangesRepository(
        groups: {_groupId: _group},
        threads: {_groupId: _thread},
      ),
      overrides: [
        openThreadSyncProvider.overrideWithValue(() async {
          cycles++;
        }),
      ],
    );

    expect(channel.opened, isEmpty, reason: 'pas de fil ouvert, pas de canal');

    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(channel.opened, [_groupId]);
    expect(channel.cancelled, 0);
    expect(find.byType(ChatBubble), findsOneWidget);

    // Le geste réel : la flèche de retour. C'est `autoDispose` qui ferme — plus
    // personne n'observe le canal du fil.
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(channel.cancelled, 1, reason: 'la socket est rendue au retour');
  });

  group('Sans SSE, l\'application est exactement la même', () {
    testWidgets('serveur injoignable : le fil reste, aucune erreur ne paraît',
        (tester) async {
      await pumpConversation(tester);

      channel.breakDown();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Le fil se remplit au cycle suivant, et la panne ne se voit nulle part :
      // elle n'est actionnable par personne, et une conversation n'est pas
      // l'endroit où apprendre l'état d'une socket.
      expect(find.text('Répétition samedi à 16h.'), findsOneWidget);
      expect(find.text(_fr.echangesLoadError), findsNothing);
      expect(tester.takeException(), isNull);

      // La minuterie de réouverture est armée : la quitter la désarme, et c'est
      // précisément ce qu'on veut vérifier — sinon le harnais attendrait.
      await leave(tester);
    });

    testWidgets('canal refusé : rien à l\'écran, et aucune insistance',
        (tester) async {
      // Un non-membre est refusé par `CheckGroupMembership`. C'est un état normal
      // (magasin en avance sur mon retrait du groupe), pas une panne.
      await pumpConversation(tester);

      channel.refuse();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Répétition samedi à 16h.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(cycles, 0);
      expect(channel.opened, [_groupId], reason: 'on ne réessaie pas un refus');

      await leave(tester);
    });

    testWidgets('sans canal du tout, l\'écran est identique', (tester) async {
      // Le défaut de `pumpScreen` : `SilentGroupChannel`. C'est le régime d'une
      // application sans backend, et celui de tous les autres tests d'écran.
      await pumpScreen(
        tester,
        const GroupChatScreen(groupId: _groupId),
        database: db,
        echanges: InMemoryEchangesRepository(
          groups: {_groupId: _group},
          threads: {_groupId: _thread},
        ),
      );

      expect(find.byType(ChatBubble), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
