import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables/legal_tables.dart';

part 'legal_dao.g.dart';

/// **Les lectures du magasin, côté documents légaux.**
///
/// Un DAO de plus, jamais des méthodes sur un DAO voisin : d'autres
/// collections, un autre modèle, d'autres écrans — la même raison qui a séparé
/// les rassemblements, les annonces et la reprise de lecture.
///
/// Rien ici ne choisit une langue. Les sections sortent **brutes**, cartes de
/// traduction entières comprises : la langue d'un document légal se décide sur
/// le document entier, à la lecture, dans `resolveLegalLocale` (ADR-0035). Un
/// DAO qui replierait par champ rendrait la règle inapplicable.
@DriftAccessor(tables: [LegalDocuments])
class LegalDao extends DatabaseAccessor<AppDatabase> with _$LegalDaoMixin {
  LegalDao(super.db);

  /// Le document courant d'un genre (`cgu`, `privacy`, `about`), ou `null` si
  /// le magasin ne l'a pas encore reçu.
  ///
  /// `null` n'est **pas** une erreur : c'est `ContentAbsence.notSynced`, une
  /// attente. Le serveur ne tient qu'une ligne courante par genre — le tri par
  /// version décroissante ne fait que rendre la lecture déterministe si deux
  /// éditions se croisaient dans un même cycle.
  Selectable<LegalDocumentRow> documentOfKind(String kind) {
    return select(legalDocuments)
      ..where((t) => t.kind.equals(kind))
      ..orderBy([
        (t) => OrderingTerm.desc(t.version),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(1);
  }
}
