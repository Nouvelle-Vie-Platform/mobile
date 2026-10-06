/// **Archiver, épingler une discussion — pour moi seul** (#146, tranche M8) —
/// `PUT /groups/:id/arrangement`, par une outbox locale rejouable.
///
/// Le patron de la lecture (`GroupReadAdvancer`), à une différence près : le
/// geste porte un **état voulu**, jamais une bascule.
///
/// 1. **calculer l'état voulu** depuis l'état effectif (règles de WhatsApp :
///    archiver désépingle, épingler désarchive) et la borne des trois épingles ;
/// 2. **le poser localement** (`pending_group_arrangements`) — la liste le lit
///    aussitôt, la discussion change de place sans attendre le réseau ;
/// 3. **poster l'état complet** (`{archived, pinned}`) ;
/// 4. confirmé → **ranger la ligne rendue** dans `group_arrangements` (la même
///    fonction que le tirage et le canal), **puis** retirer l'état local ; refusé
///    (`409` : trois épingles déjà, sur un autre appareil ; `403`/`404` : plus
///    membre) → retirer l'état local, la discussion revient à sa place ;
///    injoignable → le garder, et le rejouer ([replay]) au prochain cycle.
///
/// La route est idempotente (piège 5 du plan) : rejouer le même état n'écrit
/// rien côté serveur.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/chat_organization.dart';
import '../local/chat_organization_dao.dart';

/// Ce qu'a donné un envoi de rangement.
sealed class ArrangeOutcome {
  const ArrangeOutcome();
}

/// `200` : la ligne `group_arrangements` (plus `changed`, ignorée).
final class ArrangeConfirmed extends ArrangeOutcome {
  const ArrangeConfirmed(this.row);
  final Map<String, Object?> row;
}

/// `409` : la borne des trois épingles, atteinte côté serveur.
final class ArrangePinLimit extends ArrangeOutcome {
  const ArrangePinLimit();
}

/// Autre `4xx` : rien à rejouer — plus membre, groupe disparu.
final class ArrangeRejected extends ArrangeOutcome {
  const ArrangeRejected();
}

/// Pas de réponse, ou `5xx` : à rejouer.
final class ArrangeUnreachable extends ArrangeOutcome {
  const ArrangeUnreachable();
}

/// Contrat d'envoi d'un rangement.
abstract interface class GroupArrangementSender {
  Future<ArrangeOutcome> send({
    required String groupId,
    required bool archived,
    required bool pinned,
  });
}

/// Implémentation HTTP de [GroupArrangementSender].
///
/// ```
/// PUT /groups/:id/arrangement   (garde api)   { "archived": bool, "pinned": bool }
/// → 200 { id, groupId, archivedAt, pinnedAt, arrangedAt, changed }
/// ```
class HttpGroupArrangementSender implements GroupArrangementSender {
  HttpGroupArrangementSender({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  @override
  Future<ArrangeOutcome> send({
    required String groupId,
    required bool archived,
    required bool pinned,
  }) async {
    try {
      final response = await _client.put<Object?>(
        '/groups/$groupId/arrangement',
        data: {'archived': archived, 'pinned': pinned},
      );
      final data = response.data;
      if (data is Map) {
        return ArrangeConfirmed({
          for (final e in data.entries) e.key.toString(): e.value,
        });
      }
      return const ArrangeRejected();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 409) return const ArrangePinLimit();
      if (status != null && status >= 400 && status < 500 && status != 429) {
        return const ArrangeRejected();
      }
      return const ArrangeUnreachable();
    }
  }
}

/// Double **inerte** : ne poste rien, ne confirme rien — l'état local reste
/// posé, ce qui est la seule chose honnête sans serveur.
class InertGroupArrangementSender implements GroupArrangementSender {
  const InertGroupArrangementSender();

  @override
  Future<ArrangeOutcome> send({
    required String groupId,
    required bool archived,
    required bool pinned,
  }) async =>
      const ArrangeUnreachable();
}

/// Ce que le geste a donné, **pour l'écran**.
enum ArrangeResult {
  /// Posé (confirmé ou en attente du réseau) — la liste a déjà bougé.
  done,

  /// Déjà dans l'état demandé : rien n'est parti.
  unchanged,

  /// Refusé : trois discussions sont déjà épinglées. L'écran le dit.
  pinLimit,

  /// Refusé par le serveur pour une autre raison (plus membre) : la discussion
  /// revient à sa place.
  rejected,
}

/// L'outbox du rangement.
class GroupArranger {
  GroupArranger({
    required ChatOrganizationDao dao,
    required GroupArrangementSender sender,
    required String userId,
    required Future<void> Function(Map<String, Object?> row) storeArrangement,
    DateTime Function()? clock,
  })  : _dao = dao,
        _sender = sender,
        _userId = userId,
        _store = storeArrangement,
        _clock = clock ?? DateTime.now;

  final ChatOrganizationDao _dao;
  final GroupArrangementSender _sender;
  final String _userId;
  final Future<void> Function(Map<String, Object?> row) _store;
  final DateTime Function() _clock;

  /// Les envois en cours, par discussion : un second geste pendant un
  /// aller-retour ne double pas la requête — l'état plus récent, posé
  /// localement, part juste après.
  final Set<String> _inFlight = {};

  /// Archive ([value] vrai) ou désarchive.
  Future<ArrangeResult> archive(String groupId, {required bool value}) =>
      _arrange(groupId, archived: value);

  /// Épingle ([value] vrai) ou désépingle.
  Future<ArrangeResult> pin(String groupId, {required bool value}) =>
      _arrange(groupId, pinned: value);

  Future<ArrangeResult> _arrange(
    String groupId, {
    bool? archived,
    bool? pinned,
  }) async {
    final current = await _dao.effectiveArrangementOf(groupId);
    var nextArchived = current.archived;
    var nextPinned = current.pinned;
    if (archived != null) {
      nextArchived = archived;
      // Archiver désépingle : une archive ne tient pas la tête de la liste.
      if (archived) nextPinned = false;
    }
    if (pinned != null) {
      nextPinned = pinned;
      // Épingler désarchive : l'épingle ramène dans la liste principale.
      if (pinned) nextArchived = false;
    }
    if (nextArchived == current.archived && nextPinned == current.pinned) {
      return ArrangeResult.unchanged;
    }

    // La borne, d'abord ici : refuser sans écrire, plutôt que d'épingler puis
    // de déplacer la discussion une seconde fois à la réponse du serveur.
    if (nextPinned && !current.pinned) {
      final others = await _dao.pinnedCount(_userId, except: groupId);
      if (others >= kMaxPinnedChats) return ArrangeResult.pinLimit;
    }

    await _dao.rememberArrangement(
      groupId: groupId,
      archived: nextArchived,
      pinned: nextPinned,
      requestedAt: _clock(),
    );
    return _send(groupId, nextArchived, nextPinned);
  }

  /// **Rejoue** les rangements locaux encore à confirmer. Appelé après chaque
  /// cycle de synchronisation réussi (`messagingOutboxProvider`).
  Future<void> replay() async {
    for (final pending in await _dao.pendingArrangements()) {
      await _send(pending.groupId, pending.archived, pending.pinned);
    }
  }

  Future<ArrangeResult> _send(
    String groupId,
    bool archived,
    bool pinned,
  ) async {
    if (!_inFlight.add(groupId)) return ArrangeResult.done;
    ArrangeOutcome outcome = const ArrangeUnreachable();
    try {
      outcome = await _sender.send(
        groupId: groupId,
        archived: archived,
        pinned: pinned,
      );
      switch (outcome) {
        case ArrangeConfirmed(:final row):
          // Ranger **avant** d'oublier : sinon la discussion reviendrait à son
          // ancienne place le temps d'un battement.
          await _store(row);
          await _dao.forgetArrangement(
            groupId: groupId,
            archived: archived,
            pinned: pinned,
          );
        case ArrangePinLimit():
        case ArrangeRejected():
          await _dao.forgetArrangement(
            groupId: groupId,
            archived: archived,
            pinned: pinned,
          );
        case ArrangeUnreachable():
          break;
      }
    } finally {
      _inFlight.remove(groupId);
    }

    // Un geste différent a pu être posé pendant l'aller-retour : il part tout
    // de suite. La récursion est bornée — chaque tour exige un état différent.
    if (outcome is! ArrangeUnreachable) {
      final pending = await _dao.pendingArrangementOf(groupId);
      if (pending != null &&
          (pending.archived != archived || pending.pinned != pinned)) {
        await _send(groupId, pending.archived, pending.pinned);
      }
    }

    return switch (outcome) {
      ArrangePinLimit() => ArrangeResult.pinLimit,
      ArrangeRejected() => ArrangeResult.rejected,
      _ => ArrangeResult.done,
    };
  }
}
