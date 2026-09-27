/// **Le miroir de la préférence dans le compte** — une commodité, jamais une
/// autorité.
///
/// Le serveur expose `preferredBranchId` sur `GET /auth/me` et l'accepte sur
/// `PUT /auth/profile`. La colonne ne filtre **rien** : le serveur filtre sur le
/// **paramètre de la requête**, jamais sur elle. Elle existe pour une seule
/// chose — retrouver son réglage sur un autre appareil, ou après une
/// réinstallation.
///
/// Ce qui en découle, et qui doit rester vrai :
///
/// - **la source de vérité est locale** (`BranchScopeStore`). Un invité n'a pas
///   de compte et dispose pourtant du réglage ; un membre hors ligne aussi ;
/// - **ce miroir ne doit jamais bloquer ni faire échouer un geste.** Poser sa
///   branche dans le panneau de réglages est une action locale qui réussit
///   toujours ; la recopier dans le compte est un supplément qui peut échouer en
///   silence. Le contrat est donc le même que celui de la télémétrie et de la
///   reprise de lecture : **muet**, et un booléen pour seule information ;
/// - **il n'écrit jamais dans le magasin.** C'est `BranchScopeStore` qui écrit,
///   parce que c'est lui qui sait remettre les curseurs à zéro. Un miroir qui
///   écrirait la préférence directement contournerait ce nettoyage, et ce serait
///   la façon la plus discrète de casser toute cette tranche.
library;

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';

/// Le nom du champ, côté serveur, **écrit une fois**.
///
/// En `camelCase` : c'est un corps d'API, où cette convention règne. Le
/// `snake_case` du `branch_id` de `/sync` est celui des **query strings** et du
/// protocole delta, et les confondre donnerait un champ que le validateur
/// VineJS refuserait — silencieusement, puisque l'appel est muet.
const String kPreferredBranchField = 'preferredBranchId';

/// **Ce qui recopie la préférence dans le compte**, et rien d'autre.
abstract interface class BranchScopeMirror {
  /// La préférence telle que le **compte** la porte.
  ///
  /// Rend `null` quand il n'y a rien à adopter : pas de branche au compte, pas
  /// de compte du tout (un invité), ou l'appel a échoué. Les trois cas se
  /// confondent délibérément — dans les trois, il n'y a rien à faire, et
  /// distinguer « échec » de « vide » inviterait à afficher quelque chose.
  ///
  /// Ne lève **jamais**.
  Future<int?> read();

  /// Recopie la préférence dans le compte. `null` = toutes les branches.
  ///
  /// Rend `true` si le serveur l'a prise. Ne lève **jamais**.
  Future<bool> write(int? branchId);
}

/// Implémentation HTTP.
///
/// ```
/// GET /auth/me        → { …, "preferredBranchId": 3 }
/// PUT /auth/profile   { "preferredBranchId": 3 }   // null pour « toutes »
/// ```
///
/// **Le jeton d'appareil ne passe pas par ici.** Les deux routes sont celles
/// d'un compte ; les appeler avec un porteur anonyme rendrait un 401 — et ce
/// 401-là, sous le mode invité, déclencherait un **renouvellement de jeton
/// d'appareil suivi d'un rejeu** (`UnauthorizedInterceptor`), donc deux
/// requêtes de plus pour un échec certain. On lit donc la nature du porteur
/// avant d'appeler, et un invité n'appelle pas. C'est aussi la réponse à « que
/// vaut le miroir pour un invité ? » : rien, et c'est normal — sa préférence
/// vit sur son appareil, il n'a pas de compte où la retrouver.
class HttpBranchScopeMirror implements BranchScopeMirror {
  HttpBranchScopeMirror({ApiClient? client})
      : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Le dernier échec avalé, pour le diagnostic et les tests. Aucun écran ne le
  /// lit — sans lui, un miroir qui ne miroiterait plus rien passerait pour un
  /// miroir discret.
  @visibleForTesting
  Object? lastFailure;

  @override
  Future<int?> read() async {
    if (!await _carriedByMember()) return null;
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/auth/me');
      lastFailure = null;
      final raw = res.data?[kPreferredBranchField];
      return (raw as num?)?.toInt();
    } catch (error) {
      lastFailure = error;
      return null;
    }
  }

  @override
  Future<bool> write(int? branchId) async {
    if (!await _carriedByMember()) return false;
    try {
      // **La clé part même à `null`**, et c'est le seul moyen de *retirer* la
      // branche du compte. L'omettre — comme le fait `updateProfile` pour
      // `branchId`, où l'omission signifie « je n'y touche pas » — rendrait
      // « toutes les branches » impossible à recopier : le compte garderait pour
      // toujours la dernière branche choisie.
      await _api.dio.put<void>(
        '/auth/profile',
        data: <String, Object?>{kPreferredBranchField: branchId},
      );
      lastFailure = null;
      return true;
    } catch (error) {
      lastFailure = error;
      return false;
    }
  }

  /// Le porteur courant est-il un **membre** ?
  ///
  /// `AuthTokenKind.parse` est prudent — tout ce qui n'est pas explicitement
  /// `device` vaut `member` —, et ce défaut va du bon côté ici aussi : au pire on
  /// tente un appel qui échoue en silence, jamais on ne prive un membre de son
  /// miroir.
  Future<bool> _carriedByMember() async {
    try {
      if (await _api.readToken() == null) return false;
      return await _api.readTokenKind() == AuthTokenKind.member;
    } catch (error) {
      lastFailure = error;
      return false;
    }
  }
}

/// Miroir **inerte** : il ne lit rien et n'écrit rien.
///
/// Le défaut du mode maquette (`AppEnv.useBackend == false`), et celui des
/// tests d'écran : sans lui, ouvrir le panneau de réglages dans un test
/// appellerait `/auth/me` sur une socket que `flutter test` refuse, et
/// laisserait derrière lui la minuterie de Dio.
class InertBranchScopeMirror implements BranchScopeMirror {
  const InertBranchScopeMirror();

  @override
  Future<int?> read() async => null;

  @override
  Future<bool> write(int? branchId) async => false;
}
