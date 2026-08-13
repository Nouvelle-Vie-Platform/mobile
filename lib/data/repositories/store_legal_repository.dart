import '../../models/legal_document_view.dart';
import '../local/legal_dao.dart';
import 'legal_repository.dart';

/// Les documents légaux **peints depuis le magasin local**, jamais depuis le
/// réseau.
///
/// Aucune requête ne part d'ici : la synchronisation écrit dans le magasin et
/// ne rend rien ; les écrans lisent le magasin et n'attendent rien du réseau
/// (ADR-0026). C'est ce qui fait qu'une CGU s'affiche hors ligne — et c'est
/// tout le motif d'en avoir fait une collection répliquée plutôt qu'un
/// `GET /legal/:kind` : la barrière de consentement (#56) doit pouvoir montrer
/// ce qu'elle demande d'accepter, y compris sans réseau.
///
/// Son seul travail est de traduire une ligne en modèle de lecture. La
/// **règle**, elle, vit dans [LegalDocumentView.resolve] — une fois, pour les
/// deux implémentations.
class StoreLegalRepository implements LegalRepository {
  const StoreLegalRepository(this._dao);

  final LegalDao _dao;

  @override
  Stream<LegalDocumentView?> documentOfKind(
    String kind, {
    required String locale,
  }) {
    return _dao.documentOfKind(kind).watchSingleOrNull().map(
          (row) => row == null
              ? null
              : LegalDocumentView.resolve(
                  kind: row.kind,
                  version: row.version,
                  // Les sections sortent **brutes** du magasin : c'est la
                  // fabrique qui décide de la langue, une fois, pour le
                  // document entier (ADR-0035).
                  sections: row.sections,
                  locale: locale,
                  lastMandatoryVersion: row.lastMandatoryVersion,
                  publishedAt: row.publishedAt,
                  updatedAt: row.updatedAt,
                ),
        );
  }
}
