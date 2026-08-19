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
/// chose dans tous les cas.
enum SyncTrigger {
  /// **Ouverture de l'application.**
  appStart,

  /// **Retour au premier plan.**
  foreground,

  /// **Tirer-pour-rafraîchir.**
  pullToRefresh,

  /// **Un événement temps-réel (SSE Transmit) est arrivé** sur un canal
  /// `groups/{id}` auquel on est abonné — décision D1 de
  /// `docs/temps-reel-sse.md`.
  ///
  /// Le SSE **déclenche une sync**, il ne peint jamais le message (ADR-0026) :
  /// le message arrive ensuite par le flux delta comme d'habitude. C'est le
  /// `RealtimeService` (hors de ce moteur) qui possède le client Transmit,
  /// coalesce les événements rapprochés et appelle [SyncScheduler.trigger] avec
  /// cette raison.
  ///
  /// **C'est un cycle de plus, jamais un polling.** Le garde-fou « aucun
  /// `Timer` dans `lib/data/sync/` » reste vrai : la minuterie de coalescing vit
  /// dans le service, pas ici. Le corps de [SyncScheduler.trigger] et du moteur
  /// ne change pas — un événement rejoint le cycle en vol s'il y en a un, comme
  /// les trois autres.
  realtime,

  /// **Un réveil push est arrivé, app fermée ou en fond** — décision D6 de
  /// `docs/prd/notifications-push.md`. Le SSE couvre l'app ouverte, le push
  /// couvre l'app fermée : les deux **déclenchent une sync**, aucun ne peint le
  /// message (le réveil est content-free, `{ type, groupId, messageId }`).
  ///
  /// C'est `PushWakeHandler` (hors de ce moteur, `lib/data/push/`) qui reçoit le
  /// réveil, appelle [SyncScheduler.trigger] avec cette raison via un callback
  /// — comme le `RealtimeService` —, puis lit le message dans le magasin pour en
  /// dresser une notification locale. **Un cycle de plus, jamais un polling** :
  /// le garde-fou « aucun `Timer` dans `lib/data/sync/` » reste vrai, et le corps
  /// de [trigger] et du moteur ne change pas.
  push,
}

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

  /// **Appelé après chaque cycle réussi**, avant que le rapport ne revienne à
  /// l'appelant. `null` par défaut — le socle de synchronisation n'en dépend
  /// pas.
  ///
  /// C'est le point d'accroche du **cycle de vie des téléchargements** (#194) :
  /// `app.dart` y branche la réconciliation (révision → `outdated`, retrait →
  /// purge + notification) et la reprise des téléchargements inachevés, pour
  /// qu'elles suivent les trois déclencheurs — ouverture, retour au premier
  /// plan, tirer-pour-rafraîchir — sans les recâbler chacun. Un échec de ce
  /// travail n'échoue **pas** le cycle : il est avalé comme le reste (le magasin
  /// garde ce qu'il avait), retenu par [lastFailure] seulement si la sync
  /// elle-même a échoué.
  Future<void> Function(SyncReport report)? onCycleSucceeded;

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
      // Le travail post-sync (cycle de vie des téléchargements, #194) tourne
      // **après** un cycle réussi. Il ne fait pas échouer le cycle : une purge
      // ou un badge raté laisse le magasin en l'état, comme une sync ratée.
      final after = onCycleSucceeded;
      if (after != null) {
        try {
          await after(report);
        } catch (_) {
          // Avalé : ce n'est pas une panne de synchronisation.
        }
      }
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
