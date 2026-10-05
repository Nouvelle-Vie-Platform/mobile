import 'package:drift/drift.dart';

import '../../models/my_request_view.dart';
import 'app_database.dart';
import 'tables/interaction_tables.dart';

part 'interaction_dao.g.dart';

/// **Lecture de mes requêtes** (#148) — la collection `my_interactions`.
///
/// Lecture seule : la table se remplit par le flux delta, jamais par
/// l'application. Un envoi passe par `POST /interactions`, puis par un cycle de
/// synchronisation qui ramène la ligne.
@DriftAccessor(tables: [MyInteractions])
class InteractionDao extends DatabaseAccessor<AppDatabase>
    with _$InteractionDaoMixin {
  InteractionDao(super.db);

  /// Mes requêtes, **les plus récentes d'abord**.
  ///
  /// ⚠️ **Le filtre sur l'auteur n'est pas décoratif.** Le serveur ne sert que
  /// les miennes, mais le magasin **survit à la déconnexion** : sans ce filtre,
  /// la personne qui se connecte ensuite sur le même téléphone lirait les
  /// requêtes de la précédente — prières privées comprises. Sans acteur, rien
  /// ne se lit.
  Stream<List<MyRequestView>> watchMine(String? actor) {
    if (actor == null) return Stream.value(const <MyRequestView>[]);
    final query = select(myInteractions)
      ..where((row) => row.authorId.equals(actor))
      ..orderBy([
        (row) => OrderingTerm.desc(
              coalesce([row.clientCreatedAt, row.createdAt]),
            ),
        (row) => OrderingTerm.desc(row.id),
      ]);
    return query.watch().map((rows) => rows.map(_viewOf).toList());
  }

  MyRequestView _viewOf(MyInteractionRow row) => MyRequestView(
        id: row.id,
        kind: RequestKind.fromWire(row.type),
        status: RequestStatus.fromWire(row.status),
        title: row.title,
        content: row.content,
        isAnonymous: row.isAnonymous,
        sentAt: row.clientCreatedAt ?? row.createdAt,
      );
}
