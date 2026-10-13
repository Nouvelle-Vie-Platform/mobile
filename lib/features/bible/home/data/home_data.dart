/// **Les données de l'accueil du module** (M7, #205) : le verset du jour
/// (miroir `bible_verse_of_days`, sinon la liste intégrée), son fond, le
/// passage du dimanche, le favori du verset, et les gestes comptés au portail.
///
/// Lit les miroirs de référence (S2) et écrit **seulement**
/// `local_bible_marks` (le favori, ADR-0026) et `app_settings` (le
/// dédoublonnage des gestes).
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../data/local/app_database.dart';
import '../../../../models/announcement_view.dart';
import '../../../../state/sync_providers.dart';
import '../../../../state/theme_provider.dart';
import '../../data/bible_providers.dart';
import '../../data/canon.dart';
import 'fallback_verses.dart';

/// `YYYY-MM-DD` du jour **local** de [t] : le verset du jour suit le
/// calendrier de la personne, pas l'UTC.
String bibleDay(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}'
    '-${t.day.toString().padLeft(2, '0')}';

/// Le verset montré aujourd'hui.
final class VerseOfDay {
  const VerseOfDay({
    required this.day,
    required this.link,
    this.comment,
    this.backdrop,
    this.fromServer = false,
  });

  /// `YYYY-MM-DD`.
  final String day;
  final BibleLink link;
  final String? comment;

  /// Le fond `status_backgrounds` choisi au portail, s'il est livré.
  final StatusBackdrop? backdrop;

  /// `false` : la liste intégrée (aucun verset publié pour ce jour).
  final bool fromServer;
}

/// Le verset du jour : celui du portail pour aujourd'hui, sinon la liste
/// intégrée. Jamais d'erreur ni de vide.
// ponytail: le jour est lu à la construction ; l'accueil ouvert à minuit garde
// le verset de la veille jusqu'à sa réouverture.
final verseOfDayProvider = StreamProvider.autoDispose<VerseOfDay>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final today = ref.watch(nowProvider)();
  final day = bibleDay(today);
  final query = db.select(db.bibleVerseOfDays).join([
    leftOuterJoin(
      db.statusBackgrounds,
      db.statusBackgrounds.id.equalsExp(db.bibleVerseOfDays.backgroundId),
    ),
  ])
    ..where(db.bibleVerseOfDays.day.equals(day))
    ..orderBy([OrderingTerm.desc(db.bibleVerseOfDays.id)])
    ..limit(1);
  return query.watchSingleOrNull().map((row) {
    final v = row?.readTable(db.bibleVerseOfDays);
    final link = v == null
        ? null
        : BibleLink(
            v.book,
            v.chapter,
            from: v.verseFrom,
            to: v.verseFrom == null ? null : v.verseTo,
          );
    // Une ligne hors du canon (livre inconnu de cette version de l'appli)
    // retombe sur la liste, plutôt qu'un en-tête vide.
    if (v == null || !isValidBibleRef(link!)) {
      return VerseOfDay(day: day, link: fallbackVerseFor(today));
    }
    final bg = row!.readTableOrNull(db.statusBackgrounds);
    final comment = v.comment?.trim();
    return VerseOfDay(
      day: day,
      link: link,
      comment: comment == null || comment.isEmpty ? null : comment,
      backdrop: bg == null
          ? null
          : StatusBackdrop.read(
              baseColor: bg.baseColor,
              topColor: bg.topColor,
              bottomColor: bg.bottomColor,
              ink: bg.ink,
            ),
      fromServer: true,
    );
  });
});

/// Le texte d'une référence dans la version active, versets joints.
final bibleLinkTextProvider = FutureProvider.family<String, BibleLink>((
  ref,
  link,
) async {
  final version = ref.watch(activeBibleVersionProvider);
  final verses = await ref.watch(
    bibleChapterProvider((
      version: version,
      book: link.book,
      chapter: link.chapter,
    )).future,
  );
  final from = link.from ?? 1;
  final to = link.to ?? link.from ?? verses.length;
  return [
    for (final v in verses)
      if (v.number >= from && v.number <= to) v.text,
  ].join(' ');
});

// ─────────────────────────────────────────────────────────────────────────────
// Passage du dimanche
// ─────────────────────────────────────────────────────────────────────────────

final class SundayPassage {
  const SundayPassage({
    required this.day,
    required this.references,
    this.title,
    this.teachingId,
    this.gatheringId,
  });

  final String day;
  final List<BibleLink> references;
  final String? title;
  final String? teachingId;
  final String? gatheringId;
}

/// Le plus récent passage dont la date est passée (ou aujourd'hui).
final sundayPassageProvider = StreamProvider.autoDispose<SundayPassage?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final day = bibleDay(ref.watch(nowProvider)());
  final query = db.select(db.bibleSundayPassages)
    ..where((t) => t.day.isSmallerOrEqualValue(day))
    ..orderBy([(t) => OrderingTerm.desc(t.day)])
    ..limit(1);
  return query.watchSingleOrNull().map((r) {
    if (r == null) return null;
    final refs = decodeBibleReferences(r.references);
    final title = r.title?.trim();
    if (refs.isEmpty && (title == null || title.isEmpty)) return null;
    return SundayPassage(
      day: r.day,
      references: refs,
      title: title == null || title.isEmpty ? null : title,
      teachingId: r.teachingId,
      gatheringId: r.gatheringId,
    );
  });
});

/// `[{book, chapter, verseFrom?, verseTo?}]` → les références lisibles ;
/// une entrée illisible ou hors canon est sautée, jamais une erreur.
List<BibleLink> decodeBibleReferences(String? json) {
  if (json == null) return const [];
  try {
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map &&
            e['book'] is String &&
            e['chapter'] is int &&
            (e['verseFrom'] == null || e['verseFrom'] is int) &&
            (e['verseTo'] == null || e['verseTo'] is int))
          BibleLink(
            e['book'] as String,
            e['chapter'] as int,
            from: e['verseFrom'] as int?,
            to: e['verseFrom'] == null ? null : e['verseTo'] as int?,
          ),
    ].where(isValidBibleRef).toList();
  } on FormatException {
    return const [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Favori du verset du jour
// ─────────────────────────────────────────────────────────────────────────────

/// `true` si [link] est déjà un favori : brouillon local vivant, ou (membre)
/// marque synchronisée que la file locale ne retire pas.
final bibleIsFavoriteProvider = StreamProvider.family<bool, BibleLink>((
  ref,
  link,
) {
  final db = ref.watch(appDatabaseProvider);
  final member = ref.watch(bibleIsMemberProvider);
  const same = "kind = 'favorite' AND book = ?1 AND chapter = ?2 "
      'AND verse_from IS ?3 AND verse_to IS ?4';
  return db
      .customSelect(
        'SELECT EXISTS(SELECT 1 FROM local_bible_marks WHERE $same '
        'AND deleted_at IS NULL) '
        'OR (?5 AND EXISTS(SELECT 1 FROM bible_marks WHERE $same AND id NOT IN '
        '(SELECT id FROM local_bible_marks WHERE deleted_at IS NOT NULL))) '
        'AS fav',
        variables: [
          Variable.withString(link.book),
          Variable.withInt(link.chapter),
          Variable(link.from),
          Variable(link.to),
          Variable.withBool(member),
        ],
        readsFrom: {db.localBibleMarks, db.bibleMarks},
      )
      .watchSingle()
      .map((r) => r.read<bool>('fav'));
});

/// Crée le favori de [link] dans `local_bible_marks` (`dirty`) : brouillon de
/// l'invité, ou file d'envoi du membre — l'envoi est à M2.
Future<void> addBibleFavorite(AppDatabase db, BibleLink link, {DateTime? now}) {
  final at = (now ?? DateTime.now()).toUtc();
  return db.into(db.localBibleMarks).insert(
        LocalBibleMarksCompanion.insert(
          id: const Uuid().v7(),
          kind: 'favorite',
          book: link.book,
          chapter: link.chapter,
          verseFrom: Value(link.from),
          verseTo: Value(link.to),
          clientCreatedAt: at,
          clientUpdatedAt: at,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Gestes sur le verset du jour — `POST /bible/verse-of-day/events`
// ─────────────────────────────────────────────────────────────────────────────

enum VerseOfDayEventKind { opened, shared, favorited }

/// **Compte un geste**, une fois par jour et par type : retenu dans
/// `app_settings` (`bible_vod_<type>` = dernier jour compté) **après** une
/// réponse du serveur, invités compris (le jeton d'appareil suffit).
/// Silencieux : un échec n'affiche rien, il sera retenté au prochain geste.
class VerseOfDayEvents {
  VerseOfDayEvents({
    required AppDatabase db,
    Dio? dio,
    Future<String> Function()? deviceId,
  })  : _db = db,
        _dio = dio ?? ApiClient.instance.dio,
        _deviceId = deviceId ?? ApiClient.instance.deviceIdentity.current;

  final AppDatabase _db;
  final Dio _dio;
  final Future<String> Function() _deviceId;
  final Set<String> _inFlight = {};

  static String settingKey(VerseOfDayEventKind kind) =>
      'bible_vod_${kind.name}';

  /// À appeler sans `await` depuis l'interface : ne lève jamais.
  Future<void> record(String day, VerseOfDayEventKind kind) async {
    final key = settingKey(kind);
    if (!_inFlight.add('$key/$day')) return;
    try {
      final last = await (_db.select(
        _db.appSettings,
      )..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      if (last?.value == day) return;
      await _dio.post<void>(
        '/bible/verse-of-day/events',
        data: {'day': day, 'kind': kind.name, 'deviceId': await _deviceId()},
      );
      await _db
          .into(_db.appSettings)
          .insertOnConflictUpdate(AppSettingRow(key: key, value: day));
    } on DioException catch (e) {
      // Un 422 (jour hors fenêtre) ne passera jamais : on le tient pour compté.
      if (e.response?.statusCode == 422) {
        await _db
            .into(_db.appSettings)
            .insertOnConflictUpdate(AppSettingRow(key: key, value: day));
      }
    } catch (e) {
      debugPrint('[bible] geste du verset du jour non compté : $e');
    } finally {
      _inFlight.remove('$key/$day');
    }
  }
}

final verseOfDayEventsProvider = Provider<VerseOfDayEvents>(
  (ref) => VerseOfDayEvents(db: ref.watch(appDatabaseProvider)),
);
