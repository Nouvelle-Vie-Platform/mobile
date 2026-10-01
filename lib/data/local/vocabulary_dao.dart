import 'package:drift/drift.dart';

import '../../models/vocabulary.dart';
import 'app_database.dart';
import 'tables/vocabulary_tables.dart';

part 'vocabulary_dao.g.dart';

/// **Les lectures du magasin, côté vocabulaire** (#81).
///
/// Une seule question : **qu'est-ce que le portail a surchargé ?** La réponse
/// est une poignée de lignes, lue d'un coup et rangée en deux cartes — c'est
/// ce que la résolution (`l10n/vocabulary.dart`) attend, et elle ne sait rien
/// du magasin.
///
/// La table a quelques dizaines de lignes au plus (le catalogue serveur est
/// **curé**), et seules celles qu'un administrateur a explicitement réglées
/// existent. Il n'y a donc rien à paginer, rien à indexer, et aucune raison de
/// lire mot par mot : un `where id = …` par libellé affiché ouvrirait une
/// requête par texte à l'écran.
@DriftAccessor(tables: [PresentationVocabulary])
class VocabularyDao extends DatabaseAccessor<AppDatabase>
    with _$VocabularyDaoMixin {
  VocabularyDao(super.db);

  /// Le vocabulaire réglé, **observé** : la synchronisation réécrit sous les
  /// pieds des écrans, et un mot changé au portail doit apparaître au cycle
  /// suivant sans qu'on rouvre l'écran.
  ///
  /// Un `Stream` et non un `Future`, pour la raison qui vaut partout dans ce
  /// dépôt — une photographie prise au montage figerait le vocabulaire jusqu'à
  /// la prochaine navigation.
  Stream<VocabularyOverrides> watchOverrides() =>
      select(presentationVocabulary).watch().map(_rangeOf);

  /// Le même, **une fois**. Sert au démarrage et aux tests ; l'application, elle,
  /// observe.
  Future<VocabularyOverrides> readOverrides() async =>
      _rangeOf(await select(presentationVocabulary).get());

  /// Range les lignes en deux cartes, **d'après `kind` et rien d'autre**.
  ///
  /// Une ligne dont la nature est inconnue est **ignorée** plutôt que devinée :
  /// le serveur pourrait en introduire une troisième, et un client qui tenterait
  /// de la ranger quelque part la rangerait au mauvais endroit. Ignorer laisse
  /// le `.arb`, ce qui est toujours un affichage juste.
  ///
  /// Une ligne de terme dont les **deux** formes sont nulles, et une surcharge
  /// dont la carte est nulle, n'entrent pas : ce sont des « non-décisions » que
  /// le portail a écrites pour faire voyager un retour en arrière, et les garder
  /// obligerait la résolution à les distinguer d'une vraie surcharge.
  VocabularyOverrides _rangeOf(List<VocabularyRow> rows) {
    final labels = <String, Map<String, String>>{};
    final terms = <String, VocabularyTerm>{};

    for (final row in rows) {
      switch (row.kind) {
        case 'label':
          final label = row.label;
          if (label != null) labels[row.id] = label;
        case 'term':
          if (row.singular == null && row.plural == null) continue;
          terms[row.id] = VocabularyTerm(
            singular: row.singular,
            plural: row.plural,
          );
      }
    }

    return VocabularyOverrides(
      labels: Map.unmodifiable(labels),
      terms: Map.unmodifiable(terms),
    );
  }
}
