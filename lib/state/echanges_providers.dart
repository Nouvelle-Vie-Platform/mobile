/// **Les providers de la rubrique « Échanges »** (#96).
///
/// Même découpage que la médiathèque et les annonces : des `StreamProvider` de
/// **lecture** adossés au magasin, et **un seul** provider qui parle au réseau —
/// le composeur de messages.
///
/// ## ⚠️ L'acteur entre par un **paramètre de famille**, jamais par `ref.watch`
///
/// Toutes les lectures de cette rubrique ont besoin de savoir **qui je suis** :
/// mes conversations se lisent sur *mes* appartenances, « à rejoindre » veut dire
/// « dont je ne suis pas membre », et le `mine` d'une bulle est une comparaison à
/// mon identifiant.
///
/// La forme évidente — un `Provider` qui lit [echangesActorProvider], lui-même
/// lisant `authProvider` — **a été écrite, et elle casse l'application**. Elle
/// pose une chaîne de providers **synchrones** entre `authProvider` et les flux de
/// lecture, et le hub vit dans l'`IndexedStack` de la coquille, donc en permanence.
/// Le chemin qui tombe est exactement le plus courant : un invité touche l'onglet
/// Échanges, `requireSession()` **pousse** le parcours de connexion par-dessus la
/// coquille — ce qui met ses abonnements en pause (`TickerMode`) —, la connexion
/// aboutit, l'acteur change, la route se dépile, et Riverpod **vide la chaîne
/// pendant la construction** de l'overlay : « setState() or markNeedsBuild() called
/// during build ». L'application se peint en rouge au moment précis où quelqu'un
/// vient de se connecter.
///
/// Un paramètre de famille n'a pas ce défaut, et c'est structurel : un acteur
/// différent est une **autre clé**, donc un élément de provider **neuf** — rien
/// n'est invalidé, donc rien n'est à vider pendant un build. Le prix est une ligne
/// par écran (`ref.watch(echangesActorProvider)`), et un widget qui se reconstruit
/// sur un changement d'authentification est, lui, un chemin éprouvé : l'onglet
/// Profil le fait depuis toujours.
///
/// `test/screens/guest_tabs_test.dart` verrouille les deux gestes qui l'avaient
/// révélé.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/echanges_repository.dart';
import '../data/repositories/group_message_composer.dart';
import '../data/repositories/group_message_sender.dart';
import '../data/repositories/store_echanges_repository.dart';
import '../models/echanges_view.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';

/// Politique de réessai : **aucun réessai automatique**, comme la médiathèque et
/// l'agenda.
///
/// Riverpod 3 réessaie tout seul un provider en échec, jusqu'à dix fois avec une
/// attente qui double. Sur une lecture de **magasin local**, un échec n'est pas
/// une intermittence de réseau qu'attendre pourrait résoudre : c'est une base
/// illisible. Insister ne ferait que retarder l'aveu.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// **Moi**, ou `null` — lu par les **écrans**, qui le passent ensuite en clé de
/// famille. Voir l'en-tête du fichier : il ne doit jamais être lu par un autre
/// provider.
final echangesActorProvider = Provider<String?>(
  (ref) => ref.watch(authProvider).user?.id,
);

/// **La clé d'une lecture qui porte un identifiant** : l'acteur, et la chose
/// demandée.
///
/// Un `record` plutôt que deux familles imbriquées : les records sont comparés par
/// valeur en Dart, donc deux lectures du même fil par le même acteur partagent bien
/// un seul élément de provider.
typedef EchangesKey = ({String? actor, String id});

/// Fournit l'implémentation d'[EchangesRepository] **pour un acteur donné**.
///
/// Avec backend **et** une session : le **magasin local**, que la synchronisation
/// alimente. Le réseau ne peint jamais (ADR-0026) — c'est ce qui rend une
/// conversation relisible hors ligne dès la première image.
///
/// Sans l'un ou l'autre : le double **vide**.
///
/// ⚠️ **Vide, et non plus `SampleData`.** `InMemoryChurchRepository` était le seul
/// double câblé en production sans condition, et il servait quatre groupes, sept
/// conversations et le même fil de cinq messages pour toutes les discussions. Une
/// application sans backend montre désormais une rubrique vide, ce qui est la
/// vérité. Et sans session il n'y a rien non plus : le serveur ne sert aucune de
/// ces collections à un porteur sans compte — les trois privées sont refusées, les
/// deux `branch` sont servies **vides**.
final echangesRepositoryProvider =
    Provider.family<EchangesRepository, String?>((ref, actor) {
  if (!AppEnv.useBackend || actor == null) {
    return InMemoryEchangesRepository();
  }
  return StoreEchangesRepository(ref.watch(groupDaoProvider), userId: actor);
});

/// **Mes conversations**, groupes et tête-à-tête mêlés, triées par récence.
final conversationsProvider =
    StreamProvider.family<List<ConversationView>, String?>(
  (ref, actor) => ref.watch(echangesRepositoryProvider(actor)).conversations(),
  retry: _noAutomaticRetry,
);

/// **Les groupes à rejoindre** de la rangée de découverte.
final discoverGroupsProvider =
    StreamProvider.family<List<DiscoverGroupView>, String?>(
  (ref, actor) => ref.watch(echangesRepositoryProvider(actor)).discoverGroups(),
  retry: _noAutomaticRetry,
);

/// **Le fil d'un groupe**, écho optimiste compris.
///
/// Un `StreamProvider` et non un `FutureProvider`, et ici cette règle porte un
/// nom : le **détachement d'auteur** (ADR-0032) arrive sur une ligne déjà
/// stockée. Une bulle affichée doit perdre son auteur sous les yeux du lecteur.
final groupThreadProvider =
    StreamProvider.family<List<GroupMessageView>, EchangesKey>(
  (ref, key) => ref.watch(echangesRepositoryProvider(key.actor)).thread(key.id),
  retry: _noAutomaticRetry,
);

/// **La fiche d'un groupe**, roster compris. `null` = le magasin ne connaît pas
/// cet identifiant, et c'est une **absence**, pas une erreur.
final groupDetailProvider =
    StreamProvider.family<GroupDetailView?, EchangesKey>(
  (ref, key) => ref.watch(echangesRepositoryProvider(key.actor)).group(key.id),
  retry: _noAutomaticRetry,
);

/// **La fiche d'une personne.** `null` tant que `profiles` ne l'a pas livrée.
final memberProfileProvider =
    StreamProvider.family<MemberProfileView?, EchangesKey>(
  (ref, key) => ref.watch(echangesRepositoryProvider(key.actor)).member(key.id),
  retry: _noAutomaticRetry,
);

/// **Le seul provider de cette rubrique qui parle au réseau.**
///
/// Il pose l'écho local, poste, déclenche un cycle de synchronisation et laisse le
/// flux delta ramener la ligne autoritaire. Sans backend, l'envoyeur est **inerte**
/// — il dit « parti » sans rien poster : l'écho reste alors au fil, ce qui est la
/// seule chose honnête quand aucun serveur ne viendra le confirmer.
///
/// Il ne dépend **pas** de l'acteur : le serveur lit l'auteur sur le porteur de la
/// requête, et la table locale de l'écho ne range pas par personne — elle est
/// vidée avec la base à la suppression de compte, comme tout le reste.
final groupMessageComposerProvider = Provider<GroupMessageComposer>(
  (ref) => GroupMessageComposer(
    dao: ref.watch(groupDaoProvider),
    sender: AppEnv.useBackend
        ? HttpGroupMessageSender()
        : const InertGroupMessageSender(),
    // Le même rappel que le tirer-pour-rafraîchir : un envoi réussi rejoint le
    // cycle en cours plutôt que d'en lancer un second, qui se disputerait les
    // mêmes curseurs.
    resynchronize: ref.watch(pullToRefreshProvider),
  ),
);
