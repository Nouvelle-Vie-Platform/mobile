import 'package:drift/drift.dart';

import '../../models/note_view.dart';
import '../notes_media/note_attachment_content.dart' show hasPendingAttachment;
import 'app_database.dart';
import 'tables/note_tables.dart';

part 'notes_dao.g.dart';

/// **Les notes, départagées entre le brouillon et la ligne synchronisée**
/// (#190) — le patron de `PlaybackDao` : deux tables, une résolution à la
/// lecture.
///
/// Une note affichée vient de `local_notes` **si une ligne y existe**, sinon de
/// `spiritual_notes`. Une ligne locale n'existe que tant que le serveur n'a pas
/// renvoyé la note avec un `updatedAt ≥ clientUpdatedAt` — c'est
/// [purgeReconciled] qui l'efface, après chaque cycle réussi. Entre un `2xx`
/// et le retour du delta, la ligne locale reste donc la vérité de l'écran :
/// sans cela, la carte reculerait d'une version le temps d'un cycle.
///
/// Ce DAO **écrit**, et seulement dans [LocalNotes] : [SpiritualNotes] et
/// [NoteCategories] appartiennent à la synchronisation (ADR-0026). Aucune
/// méthode ici ne les touche, et un garde-fou de source le vérifie.
@DriftAccessor(tables: [SpiritualNotes, NoteCategories, LocalNotes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  /// La liste : épinglées en tête, puis par date de modification décroissante.
  ///
  /// [categoryId] filtre sur une catégorie ; [query] cherche dans le titre et
  /// le corps, **insensible à la casse** (`LIKE` de SQLite sur de l'ASCII, et
  /// `lower()` des deux côtés pour le reste).
  Stream<List<NoteView>> watchNotes({String? categoryId, String query = ''}) {
    final needle = '%${query.trim().toLowerCase()}%';
    final filter = categoryId == null ? '' : 'AND category_id = ? ';
    return customSelect(
      'SELECT * FROM ($_mergedNotes) '
      'WHERE (lower(coalesce(title, \'\')) LIKE ? OR lower(body) LIKE ?) '
      '$filter'
      'ORDER BY pinned DESC, updated_at DESC, id DESC',
      variables: [
        Variable.withString(needle),
        Variable.withString(needle),
        if (categoryId != null) Variable.withString(categoryId),
      ],
      readsFrom: {spiritualNotes, localNotes},
    ).watch().map((rows) => rows.map(_viewOf).toList());
  }

  /// Une note, par son identifiant — ou `null` si personne n'en sait rien.
  Stream<NoteView?> watchNote(String id) {
    return customSelect(
      'SELECT * FROM ($_mergedNotes) WHERE id = ?',
      variables: [Variable.withString(id)],
      readsFrom: {spiritualNotes, localNotes},
    ).watchSingleOrNull().map((row) => row == null ? null : _viewOf(row));
  }

  /// La note liée à un enseignement, s'il en existe une (la plus récente).
  Future<String?> noteIdForTeaching(String teachingId) async {
    final row = await customSelect(
      'SELECT id FROM ($_mergedNotes) WHERE teaching_id = ? '
      'ORDER BY updated_at DESC LIMIT 1',
      variables: [Variable.withString(teachingId)],
      readsFrom: {spiritualNotes, localNotes},
    ).getSingleOrNull();
    return row?.read<String>('id');
  }

  /// Les catégories, par nom.
  Stream<List<NoteCategoryView>> watchCategories() {
    final query = select(noteCategories)
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch().map(
          (rows) => [
            for (final row in rows)
              NoteCategoryView(
                id: row.id,
                name: row.name,
                color: NoteColor.parse(row.color),
              ),
          ],
        );
  }

  /// **Le brouillon**, écrit à chaque frappe : la ligne entière, remplacée en
  /// place, et marquée à envoyer.
  Future<void> saveDraft(LocalNotesCompanion draft) {
    return into(localNotes).insert(draft, mode: InsertMode.insertOrReplace);
  }

  Future<LocalNoteRow?> localNote(String id) =>
      (select(localNotes)..where((n) => n.id.equals(id))).getSingleOrNull();

  /// Les brouillons qui ont encore un envoi à faire, du plus ancien au plus
  /// récent — l'ordre dans lequel ils doivent repartir.
  Future<List<LocalNoteRow>> dirtyNotes() {
    return (select(localNotes)
          ..where((n) => n.dirty.equals(true))
          ..orderBy([(n) => OrderingTerm.asc(n.clientUpdatedAt)]))
        .get();
  }

  /// Le serveur a pris le brouillon tel qu'il était à [clientUpdatedAt] : plus
  /// rien à envoyer **pour cette version**. Une frappe arrivée entre-temps a
  /// avancé l'horloge, et la ligne reste à envoyer.
  Future<void> markSent(String id, DateTime clientUpdatedAt) {
    return (update(localNotes)
          ..where((n) =>
              n.id.equals(id) & n.clientUpdatedAt.equals(clientUpdatedAt)))
        .write(const LocalNotesCompanion(
      dirty: Value(false),
      lastError: Value(null),
    ));
  }

  Future<void> markFailed(String id, String error) {
    return (update(localNotes)..where((n) => n.id.equals(id)))
        .write(LocalNotesCompanion(lastError: Value(error)));
  }

  /// Efface le brouillon — note vide abandonnée, ou note supprimée (la
  /// tombstone revient par le delta).
  Future<void> deleteLocal(String id) =>
      (delete(localNotes)..where((n) => n.id.equals(id))).go();

  /// **La réconciliation** : chaque ligne locale dont la ligne synchronisée est
  /// revenue au moins aussi récente quitte le magasin. Rend le nombre de lignes
  /// purgées.
  ///
  /// **Sauf un brouillon qui porte encore une pièce jointe en montée** (#192) :
  /// le serveur a reçu la note **sans** cet embed (`serverNoteContent`), et sa
  /// version effacerait la pièce jointe de l'écran. Le tri se fait en Dart, par
  /// [hasPendingAttachment] — le même critère que celui qui retire l'embed à
  /// l'envoi —, plutôt qu'en SQL : un `LIKE '%"localId"%'` attraperait ce mot
  /// tapé dans le texte, et `json_each` lèverait sur un contenu illisible.
  /// La lecture et l'effacement partagent une transaction.
  Future<int> purgeReconciled() => transaction(() async {
        final rows = await customSelect(
          'SELECT l.id, l.content FROM local_notes l '
          'JOIN spiritual_notes s ON s.id = l.id '
          'WHERE s.updated_at IS NOT NULL '
          'AND s.updated_at >= l.client_updated_at',
          readsFrom: {localNotes, spiritualNotes},
        ).get();
        final ids = [
          for (final row in rows)
            if (!hasPendingAttachment(row.readNullable<String>('content')))
              row.read<String>('id'),
        ];
        if (ids.isEmpty) return 0;
        return (delete(localNotes)..where((n) => n.id.isIn(ids))).go();
      });

  /// La fusion des deux tables, en SQL : la ligne locale quand elle existe,
  /// la ligne synchronisée sinon. Les colonnes portent le même nom des deux
  /// côtés ; `updated_at` est l'horloge de l'appareil pour un brouillon.
  static const String _mergedNotes = 'SELECT id, teaching_id, title, content, '
      'body, category_id, pinned, client_updated_at AS updated_at, 1 AS local '
      'FROM local_notes '
      'UNION ALL '
      'SELECT s.id, s.teaching_id, s.title, s.content, s.body, s.category_id, '
      's.pinned, s.updated_at, 0 AS local FROM spiritual_notes s '
      'WHERE NOT EXISTS (SELECT 1 FROM local_notes l WHERE l.id = s.id)';

  NoteView _viewOf(QueryRow row) {
    final updatedAt = row.readNullable<int>('updated_at');
    return NoteView(
      id: row.read<String>('id'),
      title: row.readNullable<String>('title'),
      body: row.read<String>('body'),
      content: row.readNullable<String>('content'),
      categoryId: row.readNullable<String>('category_id'),
      pinned: row.read<int>('pinned') == 1,
      teachingId: row.readNullable<String>('teaching_id'),
      updatedAt: updatedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000, isUtc: true),
      isLocal: row.read<int>('local') == 1,
    );
  }
}
