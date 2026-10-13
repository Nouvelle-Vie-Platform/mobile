/// **Les notes** (#190) : le DAO, l'écriture, et les lectures — toutes des
/// flux du magasin, que la synchronisation remplit.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/local/notes_dao.dart';
import '../data/repositories/note_draft_saver.dart';
import '../data/repositories/notes_repository.dart';
import '../models/note_view.dart';
import 'sync_providers.dart';

Duration? _noAutomaticRetry(int retryCount, Object error) => null;

final notesDaoProvider = Provider<NotesDao>(
  (ref) => ref.watch(appDatabaseProvider).notesDao,
);

/// **Le seul provider de ce domaine qui parle au réseau.** Inerte sans
/// backend ; les tests le surchargent par un double.
/// Le délai du brouillon d'une note avant son envoi (`NoteDraftSaver`).
/// Surchargé par les tests d'écran, pour que la charge de la machine ne
/// déclenche pas un envoi au milieu d'un parcours.
final noteDraftDebounceProvider =
    Provider<Duration>((_) => const Duration(seconds: 2));

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) =>
      AppEnv.useBackend ? HttpNotesRepository() : const InertNotesRepository(),
);

/// La clé d'une lecture de la liste : le filtre de catégorie et la recherche.
/// Un `record`, comparé par valeur : deux lectures identiques partagent un
/// seul flux.
typedef NotesQuery = ({String? categoryId, String query});

final notesListProvider = StreamProvider.family<List<NoteView>, NotesQuery>(
  (ref, q) => ref
      .watch(notesDaoProvider)
      .watchNotes(categoryId: q.categoryId, query: q.query),
  retry: _noAutomaticRetry,
);

final noteCategoriesProvider = StreamProvider<List<NoteCategoryView>>(
  (ref) => ref.watch(notesDaoProvider).watchCategories(),
  retry: _noAutomaticRetry,
);

final noteProvider = StreamProvider.family<NoteView?, String>(
  (ref, id) => ref.watch(notesDaoProvider).watchNote(id),
  retry: _noAutomaticRetry,
);

/// **Le renvoi de ce qui n'est pas parti** : `app.dart` l'appelle après chaque
/// cycle réussi, à côté de l'outbox de la messagerie. La purge des brouillons
/// revenus par le delta se fait au même moment.
final notesOutboxProvider = Provider<Future<void> Function()>((ref) {
  return () => NoteDraftSaver.resendDirty(
        ref.read(notesDaoProvider),
        ref.read(notesRepositoryProvider),
      );
});
