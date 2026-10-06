/// **Mes requêtes** (#148) — le modèle de lecture de l'onglet « Requêtes ».
library;

import 'package:flutter/foundation.dart';

/// Le genre d'une requête, tel que le serveur le connaît (`interactions.type`).
///
/// [unknown] n'est pas un cas d'école : un serveur plus récent peut servir un
/// genre que cette version ignore. La ligne s'affiche alors sans étiquette de
/// genre plutôt que de faire tomber la liste.
enum RequestKind {
  prayer('prayer_request'),
  suggestion('suggestion'),
  complaint('complaint'),
  unknown('');

  const RequestKind(this.wire);

  /// La valeur stockée et servie par le serveur.
  final String wire;

  static RequestKind fromWire(String value) => RequestKind.values.firstWhere(
        (kind) => kind != RequestKind.unknown && kind.wire == value,
        orElse: () => RequestKind.unknown,
      );
}

/// L'état de traitement d'une requête (`interactions.status`) : le cycle
/// `new → in_progress → resolved` (+ `archived`), mené par les responsables.
enum RequestStatus {
  received('new'),
  inProgress('in_progress'),
  resolved('resolved'),
  archived('archived'),
  unknown('');

  const RequestStatus(this.wire);

  final String wire;

  static RequestStatus fromWire(String value) =>
      RequestStatus.values.firstWhere(
        (status) => status != RequestStatus.unknown && status.wire == value,
        orElse: () => RequestStatus.unknown,
      );
}

/// Une requête que **j'ai** envoyée, prête à afficher.
@immutable
class MyRequestView {
  const MyRequestView({
    required this.id,
    required this.kind,
    required this.status,
    required this.title,
    required this.content,
    required this.isAnonymous,
    required this.sentAt,
  });

  final String id;
  final RequestKind kind;
  final RequestStatus status;
  final String title;
  final String content;

  /// Envoyée anonymement : masquée aux responsables, jamais à moi (ADR-0007).
  final bool isAnonymous;

  /// L'instant d'envoi (UTC) — l'horodatage du téléphone quand il existe,
  /// celui du serveur sinon. `null` seulement pour une ligne mal formée.
  final DateTime? sentAt;

  @override
  bool operator ==(Object other) =>
      other is MyRequestView &&
      other.id == id &&
      other.kind == kind &&
      other.status == status &&
      other.title == title &&
      other.content == content &&
      other.isAnonymous == isAnonymous &&
      other.sentAt == sentAt;

  @override
  int get hashCode =>
      Object.hash(id, kind, status, title, content, isAnonymous, sentAt);
}
