/// **Les marques, la file d'envoi et la fusion à la connexion** (M2, #200) :
/// écritures dans `local_bible_marks` seulement, lecture fusionnée avec le
/// miroir pour le membre, envoi après un cycle, import en lot.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/data/canon.dart';
import 'package:maison_du_miracle/features/bible/marks/bible_marks_outbox.dart';
import 'package:maison_du_miracle/features/bible/marks/bible_marks_store.dart';
import 'package:maison_du_miracle/features/bible/marks/bible_verse_actions.dart';

import '../../../data/local/local_database_fixtures.dart';
import '../../../helpers/fake_api.dart';

final _t0 = DateTime.utc(2026, 10, 13, 10);

({BibleMarksOutbox outbox, FakeAdapter wire}) _outbox(
  AppDatabase db, {
  bool member = true,
  int status = 200,
}) {
  final wire = FakeAdapter((o) => jsonReply(status, {}));
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = wire;
  return (
    outbox: BibleMarksOutbox(db, dio, isMember: () => member),
    wire: wire,
  );
}

Future<List<LocalBibleMarkRow>> _local(AppDatabase db) =>
    db.select(db.localBibleMarks).get();

void main() {
  late AppDatabase db;
  late BibleMarksStore store;

  setUp(() {
    db = openTestDatabase();
    store = BibleMarksStore(db, now: () => _t0);
  });
  tearDown(() => db.close());

  test('favori : posé puis retiré au même endroit ; un invité efface la ligne',
      () async {
    const link = BibleLink('John', 3, from: 16, to: 18);
    await store.toggleFavorite(member: false, link: link);
    final row = (await _local(db)).single;
    expect((row.kind, row.verseFrom, row.verseTo, row.dirty),
        ('favorite', 16, 18, true));

    await store.toggleFavorite(member: false, link: link);
    expect(await _local(db), isEmpty);
  });

  test('surlignage : une couleur par verset ; effacer retire ce qui touche',
      () async {
    await store.highlight(
      member: false,
      link: const BibleLink('John', 3, from: 16, to: 18),
      color: 'yellow',
    );
    await store.highlight(
      member: false,
      link: const BibleLink('John', 3, from: 17),
      color: 'blue',
    );
    var marks = await store.watch(member: false).first;
    expect(marks.single.color, 'blue');
    expect((marks.single.verseFrom, marks.single.verseTo), (17, 17));

    await store.highlight(
      member: false,
      link: const BibleLink('John', 3, from: 15, to: 17),
    );
    marks = await store.watch(member: false).first;
    expect(marks, isEmpty);
  });

  test('marque-page : un chapitre entier, sans verset', () async {
    await store.toggleBookmark(member: false, book: 'Ps', chapter: 23);
    final m = (await store.watch(member: false, book: 'Ps', chapter: 23).first)
        .single;
    expect((m.kind, m.verseFrom, m.covers(6)),
        (BibleMarkKind.bookmark, null, true));
  });

  test(
      'membre : miroir lu, retrait = tombstone locale ; invité : miroir ignoré',
      () async {
    await db.into(db.bibleMarks).insert(BibleMarksCompanion.insert(
          id: 'm1',
          kind: 'favorite',
          book: 'John',
          chapter: 3,
          verseFrom: const Value(16),
          updatedAt: Value(_t0),
        ));
    expect(await store.watch(member: false).first, isEmpty);
    final mirror = (await store.watch(member: true).first).single;
    expect(mirror.id, 'm1');

    await store.remove(member: true, mark: mirror);
    expect(await store.watch(member: true).first, isEmpty);
    final tomb = (await _local(db)).single;
    expect((tomb.id, tomb.dirty), ('m1', true));
    expect(tomb.deletedAt, isNotNull);
    // Le miroir n'est jamais touché.
    expect(await db.select(db.bibleMarks).get(), hasLength(1));
  });

  test('versets cités par une note : lien nv://bible du chapitre', () async {
    await db.into(db.localNotes).insert(LocalNotesCompanion.insert(
          id: 'n1',
          body: const Value('x'),
          content: Value(bibleNoteContent(
              const BibleLink('John', 3, from: 16, to: 17), 'texte')),
          clientCreatedAt: _t0,
          clientUpdatedAt: _t0,
        ));
    await db.into(db.localNotes).insert(LocalNotesCompanion.insert(
          id: 'n2',
          body: const Value('y'),
          content: Value(
              bibleNoteContent(const BibleLink('John', 30, from: 1), 'autre')),
          clientCreatedAt: _t0,
          clientUpdatedAt: _t0,
        ));
    expect(await store.watchNotedVerses('John', 3).first, {16, 17});
  });

  test('le contenu d\'une note : lien en tête, citation en blockquote', () {
    final ops = (jsonDecode(bibleNoteContent(
            const BibleLink('John', 3, from: 16), 'Car Dieu a tant aimé'))
        as Map)['ops'] as List;
    expect(ops[0], {
      'insert': 'Jean 3:16',
      'attributes': {'link': 'nv://bible/John/3/16'},
    });
    expect(ops[2], {'insert': 'Car Dieu a tant aimé'});
    expect(ops[3], {
      'insert': '\n',
      'attributes': {'blockquote': true},
    });
  });

  group('La file d\'envoi', () {
    test('membre : POST, DELETE, PUT avec clientUpdatedAt, puis purge',
        () async {
      await store.toggleFavorite(
          member: true, link: const BibleLink('John', 3, from: 16));
      await store.remove(
        member: true,
        mark: BibleMark(
          id: 'gone',
          kind: BibleMarkKind.bookmark,
          book: 'Ps',
          chapter: 23,
          updatedAt: _t0,
        ),
      );
      await db.into(db.localBibleReadingState).insert(
            LocalBibleReadingStateCompanion.insert(
              id: 'rs',
              versionCode: const Value('EXA'),
              book: const Value('John'),
              chapter: const Value(3),
              readChapters: const Value('{"John":[3]}'),
              clientUpdatedAt: _t0,
            ),
          );
      final (:outbox, :wire) = _outbox(db);

      await outbox.run();
      final calls = [for (final r in wire.requests) '${r.method} ${r.path}'];
      expect(calls, [
        'POST /bible/marks',
        'DELETE /bible/marks/gone',
        'PUT /bible/reading-state',
      ]);
      final post = (wire.requests[0].data as Map);
      expect(post['clientUpdatedAt'], _t0.toIso8601String());
      expect((post['kind'], post['verseFrom'], post['verseTo']),
          ('favorite', 16, 16));
      final put = (wire.requests[2].data as Map);
      expect(put['readChapters'], {
        'John': [3]
      });
      expect(put['clientUpdatedAt'], _t0.toIso8601String());
      expect((await _local(db)).every((r) => !r.dirty), isTrue);

      // Cycle suivant : le delta a ramené, les lignes partent ; rien ne
      // repart sur le fil.
      await outbox.run();
      expect(wire.requests, hasLength(3));
      expect(await _local(db), isEmpty);
      expect(await db.select(db.localBibleReadingState).get(), isEmpty);
    });

    test('hors ligne : la ligne reste à envoyer', () async {
      await store.toggleFavorite(
          member: true, link: const BibleLink('John', 3, from: 16));
      final (:outbox, wire: _) = _outbox(db, status: 503);
      await outbox.run();
      expect((await _local(db)).single.dirty, isTrue);
    });

    test('invité : rien ne part', () async {
      await store.toggleFavorite(
          member: false, link: const BibleLink('John', 3, from: 16));
      final (:outbox, :wire) = _outbox(db, member: false);
      await outbox.run();
      expect(wire.requests, isEmpty);
      expect((await _local(db)).single.dirty, isTrue);
    });

    test('fusion : un seul POST /bible/import, toutes les tables, puis envoyé',
        () async {
      await store.toggleFavorite(
          member: false, link: const BibleLink('John', 3, from: 16));
      await store.highlight(
        member: false,
        link: const BibleLink('Ps', 23, from: 1, to: 2),
        color: 'green',
      );
      await db.into(db.localBibleReadingState).insert(
            LocalBibleReadingStateCompanion.insert(
              id: 'rs',
              versionCode: const Value('EXA'),
              book: const Value('Ps'),
              chapter: const Value(23),
              clientUpdatedAt: _t0,
            ),
          );
      await db.into(db.localBiblePlanEnrollments).insert(
            LocalBiblePlanEnrollmentsCompanion.insert(
              id: 'p1',
              source: 'builtin',
              planCode: const Value('nt-90'),
              startedOn: const Value('2026-10-01'),
              completedDays: const Value('[0,1]'),
              clientCreatedAt: _t0,
              clientUpdatedAt: _t0,
            ),
          );
      await db.into(db.localBibleQuizResults).insert(
            LocalBibleQuizResultsCompanion.insert(
              id: 'q1',
              quizId: 7,
              score: const Value(3),
              total: const Value(5),
              playedAt: _t0,
              clientUpdatedAt: _t0,
            ),
          );
      final (:outbox, :wire) = _outbox(db, status: 204);
      outbox.importPending = true;

      await outbox.run();
      expect(wire.requests.single.path, '/bible/import');
      final body = wire.requests.single.data as Map;
      expect((body['marks'] as List), hasLength(2));
      expect((body['readingState'] as Map)['book'], 'Ps');
      expect((body['planEnrollments'] as List).single,
          containsPair('completedDays', [0, 1]));
      expect((body['quizResults'] as List).single,
          containsPair('durationSeconds', 0));
      expect(outbox.importPending, isFalse);
      expect((await _local(db)).every((r) => !r.dirty), isTrue);
      expect(
        (await db.select(db.localBiblePlanEnrollments).get()).single.dirty,
        isFalse,
      );

      // Rien ne repart une seconde fois, par aucune route.
      await outbox.run();
      expect(wire.requests, hasLength(1));
    });

    test('déconnexion : les local_bible_* sont vidées', () async {
      await store.toggleFavorite(
          member: true, link: const BibleLink('John', 3, from: 16));
      final (:outbox, wire: _) = _outbox(db);
      await outbox.forgetAccount();
      expect(await _local(db), isEmpty);
    });
  });
}
