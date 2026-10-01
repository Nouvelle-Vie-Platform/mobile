/// **Un signal, un cycle — et rien d'autre** (#101).
///
/// Ce fichier tient l'invariant de la tranche : l'événement SSE est un **signal,
/// jamais une source de vérité** (ADR-0006). Il déclenche un cycle de
/// synchronisation, et c'est le moteur qui écrit.
///
/// Trois façons complémentaires de le prouver, et aucune ne suffit seule :
///
/// - **ici**, que le seul effet d'un signal est un appel au rappel de
///   synchronisation — un double qui ne sait rien faire d'autre que compter ;
/// - **par la source** (dernier test), qu'aucun fichier de `lib/data/realtime/`
///   ne connaît Drift ni un DAO : un `insertOnConflictUpdate` glissé là ne
///   casserait aucun test de comportement ;
/// - **à l'écran** (`test/screens/group_chat_realtime_test.dart`), que le magasin
///   reste vide après un signal reçu dans une conversation ouverte.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/realtime/group_channel.dart';
import 'package:maison_du_miracle/data/realtime/open_thread_channel.dart';

const String _groupId = 'g-1';

/// Le délai de réouverture, raccourci : la tranche ne porte pas sur la valeur de
/// `kGroupChannelRetryDelay`, et attendre dix secondes par test serait du temps
/// pris à la suite entière.
const Duration _retry = Duration(milliseconds: 10);

/// Un canal piloté à la main : c'est le test qui décide quand le canal s'ouvre,
/// diffuse, tombe ou refuse.
class _ScriptedChannel implements GroupChannel {
  _ScriptedChannel(this.log);

  /// Le journal **partagé** avec le rappel de synchronisation : c'est lui qui
  /// permet de vérifier un **ordre**, et non seulement des compteurs.
  final List<String> log;

  /// Les groupes pour lesquels on a demandé un canal, dans l'ordre.
  final List<String> opened = [];

  /// Le nombre d'abonnements **annulés** — c'est-à-dire de connexions fermées.
  int cancelled = 0;

  StreamController<GroupChannelSignal>? _current;

  @override
  Stream<GroupChannelSignal> watch(String groupId) {
    opened.add(groupId);
    log.add('watch');
    final controller = StreamController<GroupChannelSignal>();
    controller.onCancel = () {
      cancelled++;
      if (_current == controller) _current = null;
    };
    _current = controller;
    return controller.stream;
  }

  /// Le canal s'est ouvert, ou un message a été diffusé — c'est **le même
  /// signal**, et c'est voulu (voir [GroupChannelSignal]).
  void signal() => _current!.add(const GroupChannelSignal());

  /// Le serveur a rendu la main (redéploiement, coupure).
  void drop() => _current!.close();

  /// Le transport a cassé.
  void breakDown() => _current!.addError(const SocketException('réseau coupé'));

  /// Le serveur refuse l'abonnement : je ne suis pas membre de ce groupe.
  void refuse() =>
      _current!.addError(const GroupChannelRefused('groups/$_groupId', 400));
}

void main() {
  // Le planificateur de signaux s'abonne au cycle de vie : il faut une liaison.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> log;
  late _ScriptedChannel channel;
  late int cycles;
  late OpenThreadChannel open;

  /// Le rappel de synchronisation, et **tout ce que cet objet sait faire**. Il ne
  /// touche aucune base : s'il en touchait une, le test ne prouverait plus rien.
  Future<void> cycle() async {
    cycles++;
    log.add('cycle');
  }

  setUp(() {
    log = [];
    channel = _ScriptedChannel(log);
    cycles = 0;
    open = OpenThreadChannel(
      groupId: _groupId,
      channel: channel,
      resynchronize: cycle,
      retryDelay: _retry,
    );
  });

  tearDown(() => open.close());

  group('Un signal déclenche un cycle, et rien d\'autre', () {
    test('un signal reçu = un cycle', () async {
      open.open();
      expect(channel.opened, [_groupId]);
      expect(cycles, 0, reason: 'demander un canal ne synchronise pas');

      channel.signal();
      await pumpEventQueue();

      expect(cycles, 1);
    });

    test('trois signaux = trois appels, aucun rangé ni perdu', () async {
      open.open();
      channel
        ..signal()
        ..signal()
        ..signal();
      await pumpEventQueue();

      // Le dédoublonnage n'est pas ici : c'est `SyncScheduler.trigger` qui rend
      // le cycle en vol plutôt que d'en lancer un second (voir
      // `openThreadSyncProvider`). Cet objet ne décide pas à sa place — s'il
      // filtrait, il faudrait deviner ici quel signal compte.
      expect(cycles, 3);
    });

    test('le signal ne porte rien : il n\'y a rien à désérialiser', () {
      // Le type est **vide**, et c'est la contrainte de la tranche rendue
      // structurelle : pas de corps, pas d'identifiant, donc aucune donnée du
      // réseau ne peut atteindre le magasin par ce chemin. Deux instances sont
      // d'ailleurs identiques — il n'y a rien pour les distinguer.
      expect(const GroupChannelSignal(), const GroupChannelSignal());
      expect(
        const GroupChannelSignal().toString(),
        'GroupChannelSignal()',
        reason: 'un signal nu ; s\'il portait un champ, il dirait lequel',
      );
    });
  });

  group('La reconnexion', () {
    test('un canal tombé est rouvert, et sa réouverture déclenche un cycle',
        () async {
      open.open();
      channel.signal();
      await pumpEventQueue();
      expect(cycles, 1);

      channel.drop();
      await Future<void>.delayed(_retry * 3);

      expect(channel.opened, [_groupId, _groupId], reason: 'on a rouvert');
      expect(
        cycles,
        1,
        reason:
            'rouvrir n\'est pas synchroniser : une tentative qui échouerait '
            'ne doit rien demander au moteur, sinon la réouverture devient un '
            'sondage du moteur (ADR-0017)',
      );

      // C'est le canal **rétabli** qui redemande un cycle — il n'a aucune mémoire
      // de ce qui s'est diffusé pendant la coupure, donc il a le même trou à
      // faire combler qu'un message reçu.
      channel.signal();
      await pumpEventQueue();

      expect(cycles, 2);
    });

    test('une panne de transport se rattrape de la même façon', () async {
      open.open();
      channel.breakDown();
      await Future<void>.delayed(_retry * 3);

      expect(channel.opened.length, 2);
      expect(open.lastFailure, isA<SocketException>());
    });

    test('un refus ne se réessaie JAMAIS', () async {
      // Le canal est réservé aux membres (`CheckGroupMembership`). Insister ne
      // changerait pas la réponse, et une boucle d'abonnements refusés coûterait
      // du forfait pour rien — au Togo, il compte autant que la batterie.
      open.open();
      channel.refuse();
      await Future<void>.delayed(_retry * 5);

      expect(channel.opened, [_groupId]);
      expect(cycles, 0);
      expect(open.lastFailure, isA<GroupChannelRefused>());
      expect(open.isConnected, isFalse);
    });

    test('une synchronisation qui échoue ne remonte pas', () async {
      // « L'application fonctionne exactement pareil sans SSE » : une panne de
      // cycle laisse le magasin en l'état et ne paraît pas à l'écran.
      final failing = OpenThreadChannel(
        groupId: _groupId,
        channel: channel,
        resynchronize: () async => throw const SocketException('hors ligne'),
        retryDelay: _retry,
      );
      addTearDown(failing.close);

      failing.open();
      channel.signal();
      await pumpEventQueue();

      expect(failing.lastFailure, isA<SocketException>());
    });
  });

  group('Le cycle de vie', () {
    test('quitter l\'écran ferme la connexion', () async {
      open.open();
      expect(open.isConnected, isTrue);

      await open.close();

      expect(channel.cancelled, 1, reason: 'la socket est rendue');
      expect(open.isConnected, isFalse);

      // Et plus rien ne la rouvre : un canal fermé reste fermé, sinon la
      // connexion survivrait à l'écran (le piège 2 de l'issue).
      await Future<void>.delayed(_retry * 3);
      expect(channel.opened.length, 1);
    });

    test('fermer deux fois ne lève pas', () async {
      open.open();
      await open.close();
      await expectLater(open.close(), completes);
    });

    test('l\'arrière-plan ferme, et le retour synchronise AVANT de rouvrir',
        () async {
      open.open();
      expect(log, ['watch']);

      open.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(open.isConnected, isFalse, reason: 'on ferme proprement');
      expect(channel.cancelled, 1);

      open.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      // **L'ordre est l'assertion.** Le rattrapage ne doit pas dépendre de la
      // réussite d'une réouverture : on revient souvent d'arrière-plan là où il
      // n'y a pas de réseau.
      expect(log, ['watch', 'cycle', 'watch']);
      expect(open.isConnected, isTrue);
    });

    test('`inactive` ne ferme rien : ce n\'est pas un départ', () async {
      // Une alerte système, le sélecteur d'applications effleuré. Fermer dessus
      // couperait le canal plusieurs fois par conversation.
      open.open();
      open.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await pumpEventQueue();

      expect(channel.cancelled, 0);
      expect(open.isConnected, isTrue);
      expect(cycles, 0);
    });

    test('un `resumed` sur une connexion saine ne coûte rien', () async {
      open.open();
      open.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(channel.opened.length, 1);
      expect(cycles, 0,
          reason: 'rien n\'avait été fermé, il n\'y a pas de trou');
    });

    test('l\'arrière-plan d\'un écran déjà quitté ne rouvre rien', () async {
      open.open();
      await open.close();

      open.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(channel.opened.length, 1);
      expect(cycles, 0);
    });

    test('ouvrir deux fois n\'ouvre qu\'une connexion', () async {
      open.open();
      open.open();
      expect(channel.opened, [_groupId]);
    });
  });

  test(
      'garde-fou de source : rien de `lib/data/realtime/` ne connaît le magasin',
      () {
    // **L'assertion la plus importante de la tranche, dans sa forme la moins
    // contournable.** Un test de comportement ne peut pas prouver qu'on n'écrit
    // *jamais* dans Drift depuis un événement ; une écriture ajoutée demain à côté
    // du cycle passerait tous les tests ci-dessus. Celui-ci rend le chemin mixte
    // impossible à écrire : la couche temps réel n'a aucun moyen d'atteindre une
    // table.
    //
    // Écrire depuis l'événement donnerait deux écritures concurrentes dans la même
    // table, deux curseurs qui se croisent, et un message qui arrive par les deux
    // chemins — ce que la décision 1 du cadrage d'Échanges a refusé.
    final sources = Directory('lib/data/realtime')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    expect(sources, isNotEmpty);
    for (final source in sources) {
      // Les commentaires **parlent** de Drift et du magasin — c'est tout l'objet
      // de leur documentation —, ils ne les importent pas.
      final code = source
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      for (final interdit in [
        'package:drift/',
        'local/app_database',
        '_dao.dart',
        'jsonDecode',
        'jsonEncode',
      ]) {
        expect(
          code,
          isNot(contains(interdit)),
          reason:
              '${source.path} touche « $interdit » : un événement SSE est un '
              'signal, et c\'est le moteur de synchronisation qui écrit '
              '(ADR-0006). Désérialiser le corps d\'un message ici, ou atteindre '
              'une table, c\'est le chemin mixte que le cadrage a refusé.',
        );
      }
    }
  });
}
