import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/note_draft_saver.dart';
import 'package:maison_du_miracle/data/repositories/notes_repository.dart';
import 'package:maison_du_miracle/models/note_view.dart';

import 'local/local_database_fixtures.dart';

/// **L'auto-sauvegarde** (#190) : la ligne locale à chaque frappe, l'envoi
/// 2 s après la dernière et à la sortie, jamais pour un brouillon vide, et le
/// renvoi de ce qui est resté `dirty`.
void main() {
  late AppDatabase db;
  late _RecordingNotesRepository repo;
  late NoteDraftSaver saver;

  const id = '019f8000-0000-7000-8000-000000000001';
  const debounce = Duration(milliseconds: 40);

  NoteDraft draft({String? title, String body = ''}) => NoteDraft(
        id: id,
        title: title,
        body: body,
        clientCreatedAt: DateTime.utc(2026, 10, 11, 8),
      );

  setUp(() {
    db = openTestDatabase();
    repo = _RecordingNotesRepository();
    saver = NoteDraftSaver(
      dao: db.notesDao,
      repository: repo,
      debounce: debounce,
    );
  });

  // La minuterie d'un test peut encore courir : on ferme l'enregistreur avant
  // la base, sans quoi elle écrirait dans une base fermée après le test.
  tearDown(() async {
    await saver.close();
    await db.close();
  });

  Future<void> wait(Duration d) => Future<void>.delayed(d);

  group('Chaque frappe', () {
    test('écrit la ligne locale tout de suite, et n\'envoie pas encore',
        () async {
      await saver.update(draft(body: 'Dieu'));

      final row = (await db.notesDao.localNote(id))!;
      expect(row.body, 'Dieu');
      expect(row.dirty, isTrue);
      expect(repo.upserts, isEmpty);
    });

    test('l\'envoi part après la dernière frappe, une seule fois', () async {
      await saver.update(draft(body: 'D'));
      await wait(debounce ~/ 2);
      await saver.update(draft(body: 'Di'));
      await wait(debounce ~/ 2);
      await saver.update(draft(body: 'Dieu'));
      expect(repo.upserts, isEmpty,
          reason: 'la minuterie repart à chaque frappe');

      await wait(debounce * 2);

      expect(repo.upserts, hasLength(1));
      expect(repo.upserts.single.body, 'Dieu');
      expect((await db.notesDao.localNote(id))!.dirty, isFalse);
    });

    test('un échec laisse le brouillon à envoyer', () async {
      repo.accept = false;
      await saver.update(draft(body: 'Dieu'));
      await wait(debounce * 2);

      expect(repo.upserts, hasLength(1));
      final row = (await db.notesDao.localNote(id))!;
      expect(row.dirty, isTrue);
      expect(row.lastError, isNotNull);
    });
  });

  group('La sortie de l\'écran', () {
    test('envoie ce qui attend encore, sans attendre la minuterie', () async {
      await saver.update(draft(title: 'Titre'));
      await saver.close();

      expect(repo.upserts, hasLength(1));
      expect(repo.upserts.single.title, 'Titre');
    });

    test('un brouillon vide s\'efface, et ne part jamais', () async {
      await saver.update(draft(title: '  ', body: '\n'));
      await wait(debounce * 2);
      expect(repo.upserts, isEmpty, reason: 'pas de minuterie pour du vide');

      await saver.close();

      expect(repo.upserts, isEmpty);
      expect(await db.notesDao.localNote(id), isNull);
    });

    test('rien n\'a été touché : rien ne part, rien ne s\'écrit', () async {
      await saver.close();
      expect(repo.upserts, isEmpty);
      expect(await db.select(db.localNotes).get(), isEmpty);
    });
  });

  group('Le renvoi après un cycle réussi', () {
    test('renvoie ce qui est resté `dirty`, dans l\'ordre des frappes',
        () async {
      const other = '019f8000-0000-7000-8000-000000000002';
      repo.accept = false;
      await saver.update(draft(body: 'premier'));
      await NoteDraftSaver(
              dao: db.notesDao, repository: repo, debounce: debounce)
          .update(NoteDraft(
        id: other,
        body: 'second',
        clientCreatedAt: DateTime.utc(2026, 10, 11, 9),
      ));
      await wait(debounce * 2);
      expect(repo.upserts, hasLength(2), reason: 'deux échecs');

      repo.accept = true;
      repo.upserts.clear();
      await NoteDraftSaver.resendDirty(db.notesDao, repo);

      expect(repo.upserts.map((u) => u.id), [id, other]);
      expect(await db.notesDao.dirtyNotes(), isEmpty);
    });

    test('ne renvoie pas ce qui est parti, et purge ce que le delta a ramené',
        () async {
      await saver.update(draft(body: 'parti'));
      await saver.flush();
      expect(repo.upserts, hasLength(1));
      repo.upserts.clear();

      // Le delta ramène la ligne, aussi récente que la frappe.
      final row = (await db.notesDao.localNote(id))!;
      await db.syncDao.applyPage(
        db.syncDao.spiritualNotesCollection,
        upserts: [
          SpiritualNotesCompanion.insert(
            id: id,
            updatedAt: Value(row.clientUpdatedAt),
          ),
        ],
        cursor: 'c',
      );

      await NoteDraftSaver.resendDirty(db.notesDao, repo);

      expect(repo.upserts, isEmpty);
      expect(await db.notesDao.localNote(id), isNull);
    });

    test('un brouillon vide resté en base ne part pas non plus', () async {
      await saver.update(draft());
      await NoteDraftSaver.resendDirty(db.notesDao, repo);
      expect(repo.upserts, isEmpty);
    });
  });
}

class _RecordingNotesRepository implements NotesRepository {
  final upserts = <NoteUpsert>[];
  bool accept = true;

  @override
  Future<bool> upsertNote(NoteUpsert note) async {
    upserts.add(note);
    return accept;
  }

  @override
  Future<bool> deleteNote(String id) async => accept;

  @override
  Future<bool> upsertCategory({
    required String id,
    required String name,
    required NoteColor color,
    required DateTime clientCreatedAt,
  }) async =>
      accept;

  @override
  Future<bool> deleteCategory(String id) async => accept;
}
