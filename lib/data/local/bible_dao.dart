import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'tables/bible_tables.dart';

part 'bible_dao.g.dart';

/// **Ma position de lecture**, telle que le lecteur la voit : la ligne locale
/// si elle existe, sinon (membre seulement) le miroir synchronisé.
final class BibleReadingSnapshot {
  const BibleReadingSnapshot({
    this.versionCode,
    this.book,
    this.chapter,
    this.verse,
    this.readChapters = const {},
  });

  final String? versionCode;
  final String? book;
  final int? chapter;
  final int? verse;

  /// `{ "<OSIS>": {chapitres lus} }`.
  final Map<String, Set<int>> readChapters;

  bool hasRead(String book, int chapter) =>
      readChapters[book]?.contains(chapter) ?? false;
}

/// **La lecture du module Bible** (M1, #199) : la position et les chapitres
/// lus. Écrit **seulement** `local_bible_reading_state` — jamais le miroir
/// `bible_reading_states`, que la synchronisation seule remplit (ADR-0026).
/// La ligne locale est `dirty` après chaque geste : l'envoi (`PUT
/// /bible/reading-state`) et la purge au retour du delta appartiennent à M2.
@DriftAccessor(tables: [BibleReadingStates, LocalBibleReadingState])
class BibleDao extends DatabaseAccessor<AppDatabase> with _$BibleDaoMixin {
  BibleDao(super.db);

  /// La position, relue à chaque changement. [member] : un invité ne lit
  /// **jamais** le miroir — il pourrait porter le compte d'une session
  /// précédente.
  Stream<BibleReadingSnapshot?> watchReadingState({required bool member}) {
    final local = select(localBibleReadingState)..limit(1);
    if (!member) {
      return local
          .watchSingleOrNull()
          .map((r) => r == null ? null : _ofLocal(r));
    }
    final synced = (select(bibleReadingStates)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .watchSingleOrNull();
    // Les deux flux **ensemble** (dernière valeur de chacun) : la ligne locale
    // l'emporte dès qu'elle existe, même apparue après coup — un
    // `asyncExpand` restait collé au miroir, dont le flux ne finit jamais.
    LocalBibleReadingStateRow? l;
    BibleReadingStateRow? s;
    var hasLocal = false;
    var hasSynced = false;
    final subs = <StreamSubscription<Object?>>[];
    late final StreamController<BibleReadingSnapshot?> out;
    void emit() {
      if (!hasLocal) return;
      final row = l;
      if (row != null) {
        out.add(_ofLocal(row));
      } else if (hasSynced) {
        final m = s;
        out.add(m == null ? null : _ofSynced(m));
      }
    }

    out = StreamController<BibleReadingSnapshot?>(
      onListen: () {
        subs
          ..add(local.watchSingleOrNull().listen((v) {
            l = v;
            hasLocal = true;
            emit();
          }, onError: out.addError))
          ..add(synced.listen((v) {
            s = v;
            hasSynced = true;
            emit();
          }, onError: out.addError));
      },
      onPause: () {
        for (final x in subs) {
          x.pause();
        }
      },
      onResume: () {
        for (final x in subs) {
          x.resume();
        }
      },
      onCancel: () => Future.wait([for (final x in subs) x.cancel()]),
    );
    return out.stream;
  }

  /// Retient la version et la position.
  Future<void> savePosition({
    required bool member,
    required String versionCode,
    required String book,
    required int chapter,
    int? verse,
    DateTime? now,
  }) =>
      _edit(
        member,
        now,
        (row) => row.copyWith(
          versionCode: Value(versionCode),
          book: Value(book),
          chapter: Value(chapter),
          verse: Value(verse),
        ),
      );

  /// Marque [book] [chapter] lu (idempotent).
  Future<void> markChapterRead({
    required bool member,
    required String book,
    required int chapter,
    DateTime? now,
  }) =>
      _edit(member, now, (row) {
        final read = _decodeRead(row.readChapters.value);
        final added = read.putIfAbsent(book, () => <int>{}).add(chapter);
        final at = now ?? DateTime.now();
        final day = _isoDay(at);
        final last = row.lastReadOn.value;
        if (!added && last == day) return null;
        return row.copyWith(
          readChapters: Value(_encodeRead(read)),
          lastReadOn: Value(day),
          streakDays: Value(
            nextStreak(row.streakDays.value, last, at),
          ),
        );
      });

  /// **La série** après un chapitre lu jusqu'au bout le jour de [now] (jour
  /// local) : même jour que [lastReadOn] → inchangée (au moins 1), lendemain
  /// → +1, plus tard (ou jamais) → 1.
  static int nextStreak(int streak, String? lastReadOn, DateTime now) {
    final gap = _daysSince(lastReadOn, now);
    if (gap == 0) return streak < 1 ? 1 : streak;
    if (gap == 1) return streak + 1;
    return 1;
  }

  /// **La série affichée** : rompue (0) si le dernier jour de lecture est
  /// antérieur à hier.
  static int currentStreak(int streak, String? lastReadOn, DateTime now) {
    final gap = _daysSince(lastReadOn, now);
    return gap == null || gap > 1 ? 0 : streak;
  }

  /// Jours entre [lastReadOn] (`YYYY-MM-DD`) et le jour local de [now] ;
  /// `null` si jamais lu. Calculé sur des dates UTC : pas de piège d'heure
  /// d'été.
  static int? _daysSince(String? lastReadOn, DateTime now) {
    final last = lastReadOn == null ? null : DateTime.tryParse(lastReadOn);
    if (last == null) return null;
    return DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(last.year, last.month, last.day))
        .inDays;
  }

  static String _isoDay(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Lit la ligne locale (ou l'amorce depuis le miroir pour un membre),
  /// applique [change], et l'écrit `dirty`. [change] rend `null` : rien à
  /// écrire.
  Future<void> _edit(
    bool member,
    DateTime? now,
    LocalBibleReadingStateCompanion? Function(
      LocalBibleReadingStateCompanion row,
    ) change,
  ) {
    return transaction(() async {
      final existing =
          await (select(localBibleReadingState)..limit(1)).getSingleOrNull();
      LocalBibleReadingStateCompanion base;
      if (existing != null) {
        base = existing.toCompanion(false);
      } else {
        final synced = member
            ? await (select(bibleReadingStates)
                  ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
                  ..limit(1))
                .getSingleOrNull()
            : null;
        base = LocalBibleReadingStateCompanion(
          // L'identifiant du serveur quand il existe : l'envoi retombe sur la
          // même ligne. Sinon un UUIDv7 client, comme partout.
          id: Value(synced?.id ?? const Uuid().v7()),
          versionCode: Value(synced?.versionCode),
          book: Value(synced?.book),
          chapter: Value(synced?.chapter),
          verse: Value(synced?.verse),
          readChapters: Value(synced?.readChapters),
          streakDays: Value(synced?.streakDays ?? 0),
          lastReadOn: Value(synced?.lastReadOn),
        );
      }
      final next = change(base);
      if (next == null) return;
      await into(localBibleReadingState).insertOnConflictUpdate(
        next.copyWith(
          clientUpdatedAt: Value((now ?? DateTime.now()).toUtc()),
          dirty: const Value(true),
        ),
      );
    });
  }

  static BibleReadingSnapshot _ofLocal(LocalBibleReadingStateRow r) =>
      BibleReadingSnapshot(
        versionCode: r.versionCode,
        book: r.book,
        chapter: r.chapter,
        verse: r.verse,
        readChapters: _decodeRead(r.readChapters),
      );

  static BibleReadingSnapshot _ofSynced(BibleReadingStateRow r) =>
      BibleReadingSnapshot(
        versionCode: r.versionCode,
        book: r.book,
        chapter: r.chapter,
        verse: r.verse,
        readChapters: _decodeRead(r.readChapters),
      );

  /// `{ "John": [3, 4] }` → `{John: {3, 4}}`. Illisible ⇒ vide, jamais une
  /// erreur.
  static Map<String, Set<int>> _decodeRead(String? json) {
    if (json == null) return {};
    try {
      final map = jsonDecode(json);
      if (map is! Map) return {};
      return {
        for (final e in map.entries)
          if (e.value is List)
            e.key.toString(): {
              for (final c in e.value as List)
                if (c is int) c,
            },
      };
    } on FormatException {
      return {};
    }
  }

  static String _encodeRead(Map<String, Set<int>> read) => jsonEncode({
        for (final e in read.entries) e.key: (e.value.toList()..sort()),
      });
}
