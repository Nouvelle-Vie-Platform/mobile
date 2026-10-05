import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/sync_scheduler.dart';

/// **Quand on synchronise — et surtout quand on ne synchronise pas.**
///
/// Trois déclencheurs (ADR-0017) : ouverture, retour au premier plan,
/// tirer-pour-rafraîchir. **Jamais de polling** : le dernier test de ce fichier
/// est un garde-fou de source, parce qu'un intervalle ajouté « juste pour être
/// sûr » ne se voit dans aucun test de comportement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const report = SyncReport(
    pulled: [],
    resynced: [],
    skipped: [],
    untouched: [],
    pages: 0,
    scopeVersion: null,
  );

  late int cycles;
  late List<Completer<SyncReport>> pending;

  setUp(() {
    cycles = 0;
    pending = [];
  });

  /// Un moteur factice qui rend la main tout de suite.
  Future<SyncReport> immediate() async {
    cycles++;
    return report;
  }

  /// Un moteur factice dont on décide de la fin, pour observer la fenêtre
  /// pendant laquelle un cycle tourne.
  Future<SyncReport> deferred() {
    cycles++;
    final completer = Completer<SyncReport>();
    pending.add(completer);
    return completer.future;
  }

  test('l\'ouverture déclenche un cycle et s\'abonne au cycle de vie',
      () async {
    final scheduler = SyncScheduler(immediate);
    addTearDown(scheduler.dispose);

    await scheduler.start();

    expect(cycles, 1);
    expect(scheduler.lastTrigger, SyncTrigger.appStart);
  });

  test(
      'le retour au premier plan déclenche un cycle, la mise en arrière-plan '
      'non', () async {
    final scheduler = SyncScheduler(immediate);
    addTearDown(scheduler.dispose);
    await scheduler.start();

    scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
    scheduler.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(cycles, 1);

    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(cycles, 2);
    expect(scheduler.lastTrigger, SyncTrigger.foreground);
  });

  test(
      'le retour au premier plan relit les flux tout de suite, puis à la fin '
      'du cycle (#138)', () async {
    final scheduler = SyncScheduler(deferred);
    addTearDown(scheduler.dispose);
    var rereads = 0;
    scheduler.onForeground = () => rereads++;

    scheduler.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(rereads, 0, reason: 'seul le retour relit');

    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    // Immédiatement : ce qu'un réveil de fond a déjà écrit par une autre
    // connexion se voit sans attendre le réseau.
    expect(rereads, 1);
    expect(cycles, 1);

    // Puis à la fin du cycle : un réveil de fond encore en cours au retour a
    // pu finir d'écrire entre-temps.
    pending.single.complete(report);
    await pumpEventQueue();
    expect(rereads, 2);
  });

  test('la seconde relecture suit aussi un cycle échoué (#138)', () async {
    final scheduler = SyncScheduler(() => Future<SyncReport>.error(
          const SocketException('hors ligne'),
        ));
    addTearDown(scheduler.dispose);
    var rereads = 0;
    scheduler.onForeground = () => rereads++;

    scheduler.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(rereads, 2);
    expect(scheduler.lastFailure, isA<SocketException>());
  });

  test('tirer-pour-rafraîchir déclenche un cycle', () async {
    final scheduler = SyncScheduler(immediate);
    addTearDown(scheduler.dispose);

    await scheduler.refresh();

    expect(cycles, 1);
    expect(scheduler.lastTrigger, SyncTrigger.pullToRefresh);
  });

  test('deux déclencheurs concurrents ne lancent qu\'un seul cycle', () async {
    final scheduler = SyncScheduler(deferred);
    addTearDown(scheduler.dispose);

    final first = scheduler.trigger(SyncTrigger.appStart);
    final second = scheduler.refresh();

    // Deux cycles concurrents se disputeraient les mêmes curseurs et les mêmes
    // jetons de resync : le second rejoint le premier.
    expect(cycles, 1);
    expect(scheduler.isRunning, isTrue);

    pending.single.complete(report);
    expect(await first, same(await second));
    expect(scheduler.isRunning, isFalse);
  });

  test('un cycle échoué est retenu, jamais propagé', () async {
    final scheduler = SyncScheduler(() => Future<SyncReport>.error(
          const SocketException('hors ligne'),
        ));
    addTearDown(scheduler.dispose);

    // Une synchronisation qui échoue n'est pas une erreur d'application : le
    // magasin garde ce qu'il avait et le cycle se rejoue au prochain
    // déclencheur.
    expect(await scheduler.start(), isNull);
    expect(scheduler.lastFailure, isA<SocketException>());

    // … et l'échec n'enferme pas le planificateur : le cycle suivant part.
    expect(scheduler.isRunning, isFalse);
  });

  test('jamais de polling : aucune horloge dans le socle de synchronisation',
      () {
    // Un `Timer.periodic` ajouté « pour être sûr » ne casse aucun test de
    // comportement — il réveille seulement la radio d'un téléphone sur une
    // connexion facturée pour apprendre qu'il n'y a rien de neuf. D'où ce
    // garde-fou de source.
    final sources = Directory('lib/data/sync')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    expect(sources, isNotEmpty);
    for (final source in sources) {
      // Les commentaires sont retirés : ils **parlent** de l'interdiction, ils
      // ne l'enfreignent pas.
      final code = source
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      expect(
        code,
        isNot(contains('Timer')),
        reason: '${source.path} introduit une horloge : le déclenchement est '
            'ouverture / premier plan / tirer-pour-rafraîchir, et le nudge FCM '
            'plus tard — jamais un intervalle',
      );
    }
  });
}
