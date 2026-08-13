import '../../models/legal_document_view.dart';
import '../sample_data.dart';

/// Documents légaux — **repository dédié, et le seul chemin des écrans vers une
/// CGU, une politique de confidentialité ou une présentation**.
///
/// Hors de `ChurchRepository` comme les autres domaines servis par le back
/// (CLAUDE.md, « Brancher un vrai backend ») : ce contrat-là est synchrone et
/// ne couvre plus que des domaines fictifs.
///
/// **Un `Stream`, jamais un `Future`.** La source est un magasin local que la
/// synchronisation réécrit sous les pieds des écrans : la publication d'une
/// révision arrive par le flux delta pendant qu'un fidèle lit, et l'écran
/// ouvert doit la refléter. Un `Future` livrerait une photographie prise au
/// moment du clic — et sur l'écran qu'on demandera bientôt d'accepter (#56),
/// cette photographie serait la preuve horodatée d'un accord donné sur un texte
/// périmé.
///
/// Ce qui en sort est **déjà replié dans une seule langue** ([LegalDocumentView])
/// : un widget qui le reçoit n'a plus aucune règle à appliquer, donc plus aucune
/// occasion d'en appliquer une variante. D'où le [locale] exigé à chaque appel —
/// la langue courante est une décision de l'application, pas du magasin, et elle
/// change sans que le magasin bouge.
abstract interface class LegalRepository {
  /// Le document courant d'un genre (`cgu`, `privacy`, `about`), `null` si le
  /// magasin ne l'a pas encore reçu.
  ///
  /// `null` n'est **pas une erreur** : c'est `ContentAbsence.notSynced`, une
  /// attente. Le document existe probablement côté serveur ; il n'est pas
  /// encore arrivé sur cet appareil.
  Stream<LegalDocumentView?> documentOfKind(
    String kind, {
    required String locale,
  });
}

/// Implémentation **en mémoire**, servie quand `AppEnv.useBackend` est faux
/// (mode maquette) et dans les tests d'écran.
///
/// Elle applique **exactement** les mêmes règles de lecture que
/// [StoreLegalRepository] — repli en bloc compris. Ce n'est pas un scrupule de
/// symétrie : sans cela, la dérogation d'ADR-0035 ne serait exercée nulle part
/// pendant tout le développement en mode maquette, et un document mélangé s'y
/// afficherait parfaitement. `test/data/legal_repository_test.dart` vérifie la
/// parité, comme son jumeau de la médiathèque.
class InMemoryLegalRepository implements LegalRepository {
  InMemoryLegalRepository({List<LegalDocument>? documents})
      : _documents = documents ?? SampleData.legalDocuments;

  final List<LegalDocument> _documents;

  @override
  Stream<LegalDocumentView?> documentOfKind(
    String kind, {
    required String locale,
  }) {
    for (final document in _documents) {
      if (document.kind != kind) continue;
      return Stream.value(_view(document, locale));
    }
    return Stream.value(null);
  }

  /// Le **seul** endroit où ce double construit un document — comme le magasin,
  /// par la fabrique qui applique le repli en bloc.
  LegalDocumentView _view(LegalDocument document, String locale) =>
      LegalDocumentView.resolve(
        kind: document.kind,
        version: document.version,
        sections: document.sections,
        locale: locale,
        lastMandatoryVersion: document.lastMandatoryVersion,
        publishedAt: document.publishedAt,
        updatedAt: document.updatedAt,
      );
}
