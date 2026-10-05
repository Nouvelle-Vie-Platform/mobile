/// **Mes requêtes** (#148) : la lecture, et l'écriture qui va avec.
///
/// Même découpage que les annonces : une **lecture** adossée au magasin (la
/// collection privée `my_interactions`, que la synchronisation remplit), et une
/// **écriture** séparée qui parle au réseau (`POST /interactions`) sans jamais
/// écrire dans le magasin — c'est le cycle suivant qui ramène la ligne
/// (ADR-0026 : le réseau ne peint jamais).
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/my_request_view.dart';
import '../local/interaction_dao.dart';

/// La lecture de **mes** requêtes, pour un acteur donné.
abstract interface class MyRequestsRepository {
  /// Mes requêtes, les plus récentes d'abord. Un `Stream` : un changement de
  /// statut reçu pendant que l'onglet est ouvert doit s'y voir.
  Stream<List<MyRequestView>> mine();
}

/// Le magasin local — avec backend et une session.
class StoreMyRequestsRepository implements MyRequestsRepository {
  StoreMyRequestsRepository(this._dao, {required String userId})
      : _userId = userId;

  final InteractionDao _dao;
  final String _userId;

  @override
  Stream<List<MyRequestView>> mine() => _dao.watchMine(_userId);
}

/// Le double en mémoire — sans backend, ou sans session. **Vide par défaut**,
/// et c'est la vérité : sans serveur, personne n'a rien envoyé.
class InMemoryMyRequestsRepository implements MyRequestsRepository {
  InMemoryMyRequestsRepository([this._requests = const []]);

  final List<MyRequestView> _requests;

  @override
  Stream<List<MyRequestView>> mine() => Stream.value(_requests);
}

// ─────────────────────────────────────────────────────────────────────────────
// Écriture
// ─────────────────────────────────────────────────────────────────────────────

/// Une requête à envoyer, telle que le formulaire la décrit.
@immutable
class RequestDraft {
  const RequestDraft({
    required this.kind,
    required this.title,
    required this.content,
    required this.isAnonymous,
    this.shareWithCommunity = false,
  });

  final RequestKind kind;
  final String title;
  final String content;

  /// Anonymat souple (ADR-0007) : masqué aux responsables, jamais à moi.
  final bool isAnonymous;

  /// **Prière seulement** : la poser sur le mur de prière (`community`) ou la
  /// réserver à l'équipe pastorale (`private`). Ignoré pour une suggestion ou
  /// une réclamation, que le serveur force en `private` (ADR-0014).
  final bool shareWithCommunity;

  /// Le corps de `POST /interactions`, en **`camelCase`** comme tous les corps
  /// de cette API. `id` est pré-généré ici (UUIDv7, ADR-0001) : un rejeu après
  /// une coupure est un no-op côté serveur, jamais un doublon.
  Map<String, Object?> toJson({required String id, required DateTime now}) => {
        'id': id,
        'type': kind.wire,
        'title': title,
        'content': content,
        'isAnonymous': isAnonymous,
        if (kind == RequestKind.prayer)
          'visibility': shareWithCommunity ? 'community' : 'private',
        'clientCreatedAt': now.toUtc().toIso8601String(),
      };
}

/// Pourquoi un envoi a échoué — de quoi choisir la phrase, pas plus.
enum RequestSubmitErrorCode {
  /// Le serveur n'a pas été joint.
  network,

  /// Session expirée : l'intercepteur d'`ApiClient` s'occupe de l'éjection.
  unauthorized,

  /// Refus de validation (`422`) : titre trop court, message vide…
  invalid,

  /// Toute autre réponse.
  server,
}

class RequestSubmitException implements Exception {
  const RequestSubmitException(this.code, [this.message]);

  final RequestSubmitErrorCode code;

  /// Le message du serveur, quand il en donne un (déjà traduit, `Accept-Language`).
  final String? message;

  @override
  String toString() => 'RequestSubmitException(${code.name}'
      '${message == null ? '' : ': $message'})';
}

/// L'envoi d'une requête.
abstract interface class RequestSubmitter {
  Future<void> submit(RequestDraft draft);
}

/// Sans backend : rien ne part, et on le dit plutôt que de faire semblant.
class UnavailableRequestSubmitter implements RequestSubmitter {
  const UnavailableRequestSubmitter();

  @override
  Future<void> submit(RequestDraft draft) => Future.error(
        const RequestSubmitException(RequestSubmitErrorCode.network),
      );
}

/// L'identifiant d'une requête neuve. Exposé pour que l'implémentation HTTP et
/// ses tests le partagent.
String mintRequestId() => const Uuid().v7();
