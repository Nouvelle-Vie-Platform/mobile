/// **La préférence de branche**, et le nettoyage que le serveur ne fait pas.
///
/// ## Ce que le serveur tient, et ce qu'il ne tient pas
///
/// Le serveur accepte un `branch_id` sur `GET /sync` et `GET /sync/{collection}`.
/// C'est un **filtre d'affichage, jamais une autorisation** : une branche
/// inconnue rend **422**, jamais 403, et sans paramètre **toutes** les branches
/// arrivent. Il filtre sur le **paramètre de la requête**, jamais sur la colonne
/// du compte — la colonne est un miroir, pour retrouver le réglage sur un autre
/// appareil.
///
/// Ce qu'il ne tient pas, et c'est tout l'objet de ce fichier : **il ne détecte
/// pas une préférence changée.** Il n'a aucune trace de ce que ce client
/// demandait au cycle précédent, il ne posera donc jamais
/// `full_resync_required`. Or un curseur est un keyset : il ne repasse **jamais**
/// derrière sa borne. Deux dégâts symétriques en découlent, et aucun ne
/// s'annonce :
///
/// - **on rétrécit** (toutes → Kpalimé) : les enseignements des huit autres
///   assemblées restent dans le magasin et continuent de s'afficher ;
/// - **on élargit** (Kpalimé → toutes) : les enseignements des autres
///   assemblées **antérieurs au curseur** n'arriveront jamais.
///
/// Les deux sont inoffensifs pour la sécurité — c'est justement ce qui autorise
/// à confier ce nettoyage au client, il ne peut que se priver de données. Mais
/// l'état reste incohérent, et **rien côté serveur ne le rattrapera**.
///
/// ## Le nettoyage : un remplacement, pas une purge
///
/// [choose] pose la préférence **et** marque les quatre collections concernées
/// « à remplacer » (`SyncDao.markForReplacement`). Le cycle suivant les re-tire
/// depuis zéro et balaie, dans sa transaction finale, tout ce qu'il n'a pas revu.
///
/// Deux propriétés méritent d'être dites, parce que chacune est le résultat d'un
/// choix et non un effet de bord :
///
/// 1. **Ce n'est pas un mécanisme neuf.** Le jeton posé est celui du resync, que
///    le moteur lit déjà. Un chemin parallèle « oublier les curseurs » aurait été
///    faux : effacer un curseur fait re-tirer, donc **ré-écrire**, mais n'efface
///    **rien** — les lignes sorties du périmètre resteraient. Seul
///    `finishResync` supprime, et seulement ce que le cycle n'a pas revu ;
/// 2. **L'ordre des deux écritures compte**, et elles sont dans une transaction
///    pour que la question ne se pose pas. Elle se pose quand même, parce qu'une
///    transaction peut être contournée un jour : le marquage va **avant**
///    l'écriture de la préférence. Une panne entre les deux laisse alors « les
///    collections se remplacent avec l'ancien filtre » — idempotent, invisible,
///    corrigé au geste suivant. L'ordre inverse laisse « le filtre a changé,
///    les curseurs n'ont pas bougé », qui est exactement l'état que rien ne
///    rattrape.
library;

import 'package:flutter/foundation.dart';

import '../local/app_database.dart';
import '../sync/branch_filter.dart';

/// **Le magasin de la préférence de branche.**
///
/// Elle est rangée **localement** — donc un invité en dispose, ce qui est le
/// point : le porteur d'appareil anonyme lit le catalogue, il a le droit de le
/// restreindre à son assemblée. Le miroir dans le compte est une commodité
/// séparée (`branch_scope_mirror.dart`), et ce magasin-ci ne le connaît pas.
class BranchScopeStore {
  BranchScopeStore(this._db);

  final AppDatabase _db;

  /// La branche préférée, `null` = toutes.
  ///
  /// **Il n'y a volontairement aucune lecture en flux ici.** C'était la forme
  /// évidente — celle des réglages média juste à côté — et elle est un piège :
  /// un `QueryStream` Drift programme un `Timer` de nettoyage à son annulation,
  /// qui reste pendant sous l'horloge factice de `testWidgets` et fait mourir
  /// tout test montant l'écran de réglages. Le flux n'apportait rien non plus :
  /// le seul consommateur est le moteur de synchronisation, qui lit une fois par
  /// cycle.
  Future<int?> read() => _db.settingsDao.readPreferredBranch();

  /// La préférence a-t-elle déjà été choisie sur cet appareil ?
  Future<bool> hasChoice() => _db.settingsDao.hasPreferredBranchChoice();

  /// **Pose la préférence et remet à zéro ce qu'il faut.**
  ///
  /// Rend `true` si quelque chose a changé — donc s'il y a lieu de
  /// resynchroniser. Rend `false` sur un choix identique au précédent, et ce
  /// n'est pas un détail d'optimisation : sans cette garde, ouvrir le panneau de
  /// réglages et re-cocher la même ligne relancerait un remplacement complet de
  /// quatre collections. L'étourderie coûterait tout le catalogue en 3G.
  Future<bool> choose(int? branchId) async {
    if (branchId == await read() && await hasChoice()) return false;

    await _db.transaction(() async {
      // **Le marquage d'abord.** Voir l'en-tête : c'est l'ordre qui rend la
      // panne inoffensive si la transaction venait un jour à disparaître.
      await _db.syncDao.markForReplacement(kBranchScopedCollections);
      await _db.settingsDao.setPreferredBranch(branchId);
    });
    return true;
  }

  /// **Oublie la préférence** : retour à toutes les branches, avec le même
  /// nettoyage.
  ///
  /// Appelé quand le serveur répond **422** — la branche préférée n'existe plus
  /// (une assemblée fermée, un identifiant recopié d'un autre environnement).
  /// Retomber sur « toutes » est le seul repli qui laisse l'application
  /// utilisable ; s'obstiner ferait échouer **tous** les cycles, et toutes les
  /// collections rangées après la fautive avec eux.
  Future<void> forget() async {
    try {
      await choose(null);
    } catch (error) {
      // Le repli ne doit pas pouvoir échouer bruyamment : il est appelé depuis
      // le chemin d'erreur du moteur.
      debugPrint('[branche] préférence non oubliée : $error');
    }
  }
}
