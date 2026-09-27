/// **La préférence de branche vue de l'extérieur** : un seul objet à appeler,
/// trois choses à l'intérieur.
///
/// - le **magasin local** (`BranchScopeStore`) — la source de vérité, et le seul
///   qui sache remettre les curseurs à zéro ;
/// - le **miroir du compte** (`BranchScopeMirror`) — une commodité muette ;
/// - la **resynchronisation** — injectée, parce que ce dossier n'a pas à
///   connaître `SyncScheduler` : la couche basse déclare ce dont elle a besoin,
///   elle n'importe pas la couche haute (même raison que
///   `ApiClient.onUnauthorized`).
///
/// C'est ici, et nulle part ailleurs, qu'un écran pose une préférence. Passer
/// par le magasin directement sauterait le miroir ; passer par le DAO de
/// réglages sauterait **la remise à zéro des curseurs**, et personne ne s'en
/// apercevrait avant qu'un fidèle ne signale voir les annonces d'une autre
/// assemblée.
library;

import 'package:flutter/foundation.dart';

import 'branch_scope_mirror.dart';
import 'branch_scope_store.dart';

/// La façade de la préférence de branche.
class BranchScope {
  BranchScope({
    required BranchScopeStore store,
    required BranchScopeMirror mirror,
    Future<void> Function()? resynchronize,
  })  : _store = store,
        _mirror = mirror,
        _resynchronize = resynchronize;

  final BranchScopeStore _store;
  final BranchScopeMirror _mirror;
  final Future<void> Function()? _resynchronize;

  /// La branche préférée, `null` = toutes. **Une lecture ponctuelle, jamais un
  /// flux** : voir `BranchScopeStore.read`.
  Future<int?> read() => _store.read();

  /// **Le geste du fidèle** : « je veux voir cette branche », ou « toutes ».
  ///
  /// Trois temps, et cet ordre-là :
  ///
  /// 1. le magasin pose la préférence **et** marque les quatre collections à
  ///    remplacer, en une transaction ;
  /// 2. la synchronisation est relancée — sans elle, l'affichage ne changerait
  ///    qu'au prochain retour au premier plan, et le fidèle conclurait que le
  ///    réglage ne marche pas ;
  /// 3. le compte est mis au miroir, en dernier et sans que rien n'en dépende.
  ///
  /// Le réglage est **acquis dès le premier temps**, qui est local et ne peut pas
  /// échouer pour cause de réseau. Les deux suivants sont des suppléments.
  Future<void> choose(int? branchId) async {
    if (!await _store.choose(branchId)) return;

    // Le cycle est attendu — c'est ce qui permet à l'appelant de savoir quand
    // l'écran est à jour —, mais son échec ne remonte pas : une préférence posée
    // hors ligne est posée, et le remplacement se fera au premier cycle qui
    // aboutira (le jeton de resync survit, c'est tout son intérêt).
    try {
      await _resynchronize?.call();
    } catch (error) {
      debugPrint('[branche] resynchronisation différée : $error');
    }

    await _mirror.write(branchId);
  }

  /// **Retrouver son réglage depuis son compte.**
  ///
  /// À appeler à la connexion, au démarrage d'une session de membre, et à
  /// l'ouverture du panneau de réglages. Deux règles, et elles sont
  /// asymétriques exprès :
  ///
  /// - **cet appareil n'a jamais choisi** → on adopte ce que le compte porte,
  ///   avec tout le nettoyage de [choose]. C'est le cas « nouvel appareil » et le
  ///   cas « réinstallation », et c'est à ça que sert le miroir ;
  /// - **cet appareil a déjà choisi** → on ne touche **à rien** localement. On
  ///   remonte seulement au compte, s'il ne sait encore rien, ce qui est le cas
  ///   « je l'ai réglé en invité, puis je me suis connecté ».
  ///
  /// **La décision locale gagne toujours**, et c'est le point à ne pas
  /// renverser. Un miroir qui aurait autorité écraserait un réglage qu'on vient
  /// de poser dès que sa recopie a échoué — hors ligne, par exemple : le compte
  /// porterait encore l'ancienne branche, et le panneau réouvert défèrerait le
  /// geste du fidèle. Ce qu'on perd en échange : changer sa branche sur un
  /// téléphone ne la change pas sur un second téléphone déjà réglé. C'est un
  /// filtre d'affichage par appareil ; c'est acceptable, et ça se révise si le
  /// produit préfère l'inverse.
  ///
  /// Ne lève **jamais** : appelée sur un chemin de démarrage, elle n'a pas le
  /// droit d'empêcher l'application de s'ouvrir.
  Future<void> hydrateFromAccount() async {
    try {
      final chosenHere = await _store.hasChoice();
      final remote = await _mirror.read();

      if (!chosenHere) {
        if (remote != null) await choose(remote);
        return;
      }
      if (remote != null) return;

      final local = await _store.read();
      if (local != null) await _mirror.write(local);
    } catch (error) {
      debugPrint('[branche] miroir de compte ignoré : $error');
    }
  }

  /// **Le repli du 422** : la branche préférée n'existe pas (ou plus) côté
  /// serveur.
  ///
  /// On retombe sur « toutes », avec le nettoyage complet, et on recopie
  /// l'oubli dans le compte — sinon le prochain démarrage irait rechercher la
  /// même branche morte et rejouerait le même 422.
  ///
  /// **Elle ne resynchronise pas**, à la différence de [choose] : c'est le
  /// moteur qui l'appelle, au milieu d'un cycle, et qui rejoue ce cycle sans
  /// filtre juste après. Relancer un cycle depuis ici en ouvrirait un second sur
  /// les mêmes curseurs.
  ///
  /// Ne lève **jamais** : appelée depuis le chemin d'erreur du moteur.
  Future<void> forget() async {
    await _store.forget();
    await _mirror.write(null);
  }
}
