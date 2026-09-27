/// **La préférence de branche, côté providers.**
///
/// Quatre entrées, et une seule parle au réseau (le miroir du compte).
///
/// La liste des branches se lit dans le **magasin** : `branches` est une
/// collection répliquée de partition `reference`, elle est donc déjà là, et le
/// sélecteur marche **hors ligne**. Surtout, il ne passe pas par
/// `BranchRepository` : celui-ci appelle `GET /sync/branches` à la main, hors du
/// protocole delta, et l'écran de profil est le seul à en avoir besoin parce
/// qu'il existait avant le magasin. Un réglage que doit pouvoir poser un invité
/// dans un taxi n'a pas le droit de dépendre du réseau.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/branch_scope/branch_scope.dart';
import '../data/branch_scope/branch_scope_mirror.dart';
import '../data/branch_scope/branch_scope_store.dart';
import '../data/local/app_database.dart';
import 'sync_providers.dart';

/// Pas de réessai automatique, pour la raison des autres lectures de magasin :
/// une lecture locale qui échoue ne réussira pas mieux à la seconde tentative.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// **Le magasin de la préférence** — le seul qui sache remettre les curseurs à
/// zéro, et le seul que lise le moteur de synchronisation.
final branchScopeStoreProvider = Provider<BranchScopeStore>(
  (ref) => BranchScopeStore(ref.watch(appDatabaseProvider)),
);

/// **Le miroir du compte** — le seul provider de ce fichier qui parle au réseau.
///
/// Inerte sans backend, et inerte pour un porteur d'appareil : un invité n'a pas
/// de compte où retrouver son réglage, et son réglage n'en a pas besoin.
final branchScopeMirrorProvider = Provider<BranchScopeMirror>(
  (ref) => AppEnv.useBackend
      ? HttpBranchScopeMirror()
      : const InertBranchScopeMirror(),
);

/// **La façade** : c'est elle, et elle seule, qu'un écran appelle pour poser une
/// préférence.
///
/// Elle reçoit `pullToRefreshProvider` comme resynchronisation, ce qui lui donne
/// gratuitement les deux bonnes propriétés : sans backend c'est un no-op, et un
/// cycle déjà en cours est **rejoint** au lieu d'en ouvrir un second sur les
/// mêmes curseurs.
final branchScopeProvider = Provider<BranchScope>((ref) {
  return BranchScope(
    store: ref.watch(branchScopeStoreProvider),
    mirror: ref.watch(branchScopeMirrorProvider),
    resynchronize: ref.watch(pullToRefreshProvider),
  );
});

/// La branche préférée, `null` = toutes.
///
/// **Un `FutureProvider`, et surtout pas un `StreamProvider` sur Drift.** Le
/// flux paraissait évident — c'est la forme de `mediaPreferencesProvider` juste
/// à côté — et il est un piège que ce dépôt a déjà payé deux fois. Un
/// `QueryStream` Drift, à son annulation, programme un `Timer` de nettoyage
/// (`StreamQueryStore.markAsClosed`) : sous l'horloge factice de `testWidgets`,
/// il reste **pendant** au démontage, et tout test qui monte l'écran meurt sur
/// « A Timer is still pending even after the widget tree was disposed » — quand
/// il ne se fige pas franchement, à 0 % de CPU, jusqu'à expiration.
/// L'en-tête de `test/screens/media_settings_screen_test.dart` raconte la
/// première fois.
///
/// Et le flux n'apportait rien : le seul consommateur de cette préférence est
/// `SyncEngine`, qui la lit **ponctuellement**, une fois par cycle. Contrairement
/// au plafond de débit — observé en direct par le lecteur pendant qu'un prêche
/// joue —, personne n'a besoin d'être réveillé quand elle change. C'est l'écran
/// qui la change, et c'est lui qui invalide (voir `MediaSettingsScreen`).
final preferredBranchProvider = FutureProvider<int?>(
  (ref) => ref.watch(branchScopeProvider).read(),
  retry: _noAutomaticRetry,
);

/// **Les branches où l'on peut se ranger**, lues du magasin, par ordre
/// alphabétique. Vide tant que la première synchronisation n'a pas eu lieu — et
/// c'est un état honnête : on ne peut pas choisir dans une liste qu'on n'a pas
/// reçue, et l'écran le dit.
///
/// Ponctuel aussi, et pour la même raison. Le coût est nul ici : le référentiel
/// ne bouge qu'à un cycle de synchronisation, et rouvrir le panneau suffit.
final branchScopeChoicesProvider = FutureProvider<List<BranchRow>>(
  (ref) => ref.watch(mediathequeDaoProvider).allBranches().get(),
  retry: _noAutomaticRetry,
);
