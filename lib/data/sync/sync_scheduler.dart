/// **Quand on synchronise — et quand on ne synchronise pas.**
///
/// Trois déclencheurs, posés par ADR-0017 : **ouverture** de l'application,
/// **retour au premier plan**, **tirer-pour-rafraîchir**. Le nudge FCM viendra
/// plus tard et se branchera ici, comme un quatrième appel à [trigger].
///
/// **Jamais de polling.** Il n'y a aucun `Timer` dans ce fichier, et il ne doit
/// pas en apparaître (`test/sync/sync_scheduler_test.dart` le vérifie). Un
/// intervalle réveille la radio d'un téléphone sur une connexion facturée pour
/// apprendre, la plupart du temps, qu'il n'y a rien de neuf — alors que le
/// serveur sait pousser quand il y a quelque chose.
library;

import 'package:flutter/widgets.dart';

import 'sync_engine.dart';

/// Ce qui a déclenché un cycle. Diagnostic seulement — le moteur fait la même
/// chose dans les trois cas.
enum SyncTrigger { appStart, foreground, pullToRefresh }

/// Sérialise les déclenchements et écoute le cycle de vie de l'application.
///
/// **Un seul cycle à la fois** : un retour au premier plan pendant qu'un
/// tirer-pour-rafraîchir est en cours ne lance pas un second cycle, il rejoint
/// celui qui tourne. Deux cycles concurrents se disputeraient les mêmes
/// curseurs et les mêmes jetons de resync.
class SyncScheduler with WidgetsBindingObserver {
  SyncScheduler(this._synchronize, {WidgetsBinding? binding})
      : _binding = binding;

  final Future<SyncReport> Function() _synchronize;
  final WidgetsBinding? _binding;

  Future<SyncReport?>? _inFlight;
  bool _observing = false;

  /// Le déclencheur du cycle en cours ou du dernier terminé.
  SyncTrigger? lastTrigger;

  /// L'erreur du dernier cycle échoué, `null` si le dernier a réussi.
  ///
  /// Une synchronisation qui échoue n'est **pas** une erreur d'application :
  /// le magasin garde ce qu'il avait, les écrans continuent de peindre, et le
  /// cycle se rejoue au prochain déclencheur. C'est l'écran qui décidera un
  /// jour d'en dire quelque chose (étape 2) ; ici on la retient, on ne la
  /// propage pas.
  Object? lastFailure;

  /// Un cycle est en cours.
  bool get isRunning => _inFlight != null;

  /// **Ouverture de l'application** : s'abonne au cycle de vie et lance un
  /// premier cycle.
  Future<SyncReport?> start() {
    if (!_observing) {
      (_binding ?? WidgetsBinding.instance).addObserver(this);
      _observing = true;
    }
    return trigger(SyncTrigger.appStart);
  }

  /// **Tirer-pour-rafraîchir.** Rend le cycle en cours s'il y en a un.
  Future<SyncReport?> refresh() => trigger(SyncTrigger.pullToRefresh);

  /// **Retour au premier plan.**
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Le résultat n'intéresse personne ici : le magasin peint les écrans, et
      // ils se rafraîchiront d'eux-mêmes quand il changera. L'échec éventuel
      // est retenu par [lastFailure], jamais propagé.
      trigger(SyncTrigger.foreground);
    }
  }

  /// Lance un cycle, ou rejoint celui qui tourne déjà.
  ///
  /// Rend le rapport, ou `null` si le cycle a échoué — voir [lastFailure].
  Future<SyncReport?> trigger(SyncTrigger reason) {
    final running = _inFlight;
    if (running != null) return running;

    lastTrigger = reason;
    final cycle = _run();
    _inFlight = cycle;
    return cycle;
  }

  Future<SyncReport?> _run() async {
    try {
      final report = await _synchronize();
      lastFailure = null;
      return report;
    } catch (error) {
      lastFailure = error;
      return null;
    } finally {
      _inFlight = null;
    }
  }

  /// Se désabonne du cycle de vie. Un cycle en vol se termine seul — il n'a
  /// rien à annuler : ses transactions sont atomiques page par page.
  void dispose() {
    if (!_observing) return;
    (_binding ?? WidgetsBinding.instance).removeObserver(this);
    _observing = false;
  }
}
