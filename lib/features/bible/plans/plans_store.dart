/// **Mes plans suivis, sur l'appareil** (M5, #203) : la lecture fusionnée
/// (brouillons locaux par-dessus le miroir du membre), l'écriture — dans
/// `local_bible_plan_enrollments` **seulement** (ADR-0026 : le miroir
/// `bible_plan_enrollments` appartient à la synchronisation) — et la file
/// d'envoi du membre.
///
/// Une ligne locale vit jusqu'au retour de la sienne par le delta
/// (`updatedAt ≥ clientUpdatedAt`) ; un plan quitté y garde `deletedAt` jusqu'à
/// ce que le miroir ait perdu le sien. L'import des brouillons de l'invité à
/// la connexion est l'affaire de M2 (`POST /bible/import`), pas d'ici.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import 'plan_logic.dart';
import 'plans_api.dart';

/// `builtin | published | custom` — le contrat §3.
enum PlanSource { builtin, published, custom }

/// Un plan créé par l'utilisateur : des livres, une durée.
@immutable
final class CustomPlanSpec {
  const CustomPlanSpec({
    required this.title,
    required this.books,
    required this.days,
  });

  final String title;
  final List<String> books;
  final int days;

  Map<String, Object?> toJson() => {
        'title': title,
        'books': books,
        'days': days,
      };

  static CustomPlanSpec? decode(String? json) {
    if (json == null) return null;
    try {
      final m = jsonDecode(json);
      if (m is! Map) return null;
      final title = m['title'];
      final books = m['books'];
      final days = m['days'];
      if (title is! String || books is! List || days is! int) return null;
      return CustomPlanSpec(
        title: title,
        books: books.whereType<String>().toList(),
        days: days,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Une inscription à un plan, telle que l'écran la lit.
@immutable
final class PlanEnrollment {
  const PlanEnrollment({
    required this.id,
    required this.source,
    this.planCode,
    this.planId,
    this.custom,
    required this.startedOn,
    this.completedDays = const {},
    this.challengeId,
    required this.clientCreatedAt,
  });

  final String id;
  final PlanSource source;
  final String? planCode;
  final String? planId;
  final CustomPlanSpec? custom;

  /// `YYYY-MM-DD`.
  final String startedOn;
  final Set<int> completedDays;
  final String? challengeId;
  final DateTime clientCreatedAt;

  PlanEnrollment copyWith({Set<int>? completedDays, CustomPlanSpec? custom}) =>
      PlanEnrollment(
        id: id,
        source: source,
        planCode: planCode,
        planId: planId,
        custom: custom ?? this.custom,
        startedOn: startedOn,
        completedDays: completedDays ?? this.completedDays,
        challengeId: challengeId,
        clientCreatedAt: clientCreatedAt,
      );
}

PlanSource? _sourceOf(String raw) => PlanSource.values.asNameMap()[raw];

Set<int> _decodeDays(String? json) {
  if (json == null) return {};
  try {
    final list = jsonDecode(json);
    return list is List ? list.whereType<int>().toSet() : {};
  } on FormatException {
    return {};
  }
}

String _encodeDays(Set<int> days) => jsonEncode(days.toList()..sort());

class BiblePlansStore {
  BiblePlansStore(this._db);

  final AppDatabase _db;

  /// Mes inscriptions, relues à chaque changement. [member] : un invité ne
  /// lit **jamais** le miroir (il pourrait porter le compte d'une session
  /// précédente).
  Stream<List<PlanEnrollment>> watchEnrollments({required bool member}) => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.localBiblePlanEnrollments, _db.biblePlanEnrollments},
      )
      .watch()
      .asyncMap((_) => enrollments(member: member));

  Future<List<PlanEnrollment>> enrollments({required bool member}) async {
    final locals = await _db.select(_db.localBiblePlanEnrollments).get();
    final byId = <String, PlanEnrollment?>{};
    if (member) {
      for (final r in await _db.select(_db.biblePlanEnrollments).get()) {
        byId[r.id] = _ofMirror(r);
      }
    }
    for (final r in locals) {
      byId[r.id] = r.deletedAt != null ? null : _ofLocal(r);
    }
    final out = byId.values.nonNulls.toList()
      ..sort((a, b) => a.clientCreatedAt.compareTo(b.clientCreatedAt));
    return out;
  }

  /// Commence un plan ; rend l'inscription créée.
  Future<PlanEnrollment> enroll({
    required PlanSource source,
    String? planCode,
    String? planId,
    CustomPlanSpec? custom,
    required DateTime startedOn,
    String? challengeId,
    DateTime? now,
  }) async {
    final at = (now ?? DateTime.now()).toUtc();
    final e = PlanEnrollment(
      id: const Uuid().v7(),
      source: source,
      planCode: source == PlanSource.builtin ? planCode : null,
      planId: source == PlanSource.published ? planId : null,
      custom: source == PlanSource.custom ? custom : null,
      startedOn: formatDay(startedOn),
      challengeId: challengeId,
      clientCreatedAt: at,
    );
    await save(e, now: at);
    return e;
  }

  /// Écrit [e] (progression, plan perso modifié) dans la file locale.
  Future<void> save(PlanEnrollment e, {DateTime? now, DateTime? deletedAt}) =>
      _db.into(_db.localBiblePlanEnrollments).insertOnConflictUpdate(
            LocalBiblePlanEnrollmentsCompanion.insert(
              id: e.id,
              source: e.source.name,
              planCode: Value(e.planCode),
              planId: Value(e.planId),
              custom: Value(e.custom == null ? null : jsonEncode(e.custom)),
              startedOn: Value(e.startedOn),
              completedDays: Value(_encodeDays(e.completedDays)),
              challengeId: Value(e.challengeId),
              clientCreatedAt: e.clientCreatedAt,
              clientUpdatedAt: (now ?? DateTime.now()).toUtc(),
              dirty: const Value(true),
              lastError: const Value(null),
              deletedAt: Value(deletedAt),
            ),
          );

  /// Quitte (ou supprime) un plan. L'invité efface sa ligne ; le membre la
  /// garde marquée jusqu'à l'envoi du `DELETE` et au retour du delta.
  Future<void> remove(
    PlanEnrollment e, {
    required bool member,
    DateTime? now,
  }) async {
    if (!member) {
      await (_db.delete(
        _db.localBiblePlanEnrollments,
      )..where((t) => t.id.equals(e.id)))
          .go();
      return;
    }
    final at = (now ?? DateTime.now()).toUtc();
    await save(e, now: at, deletedAt: at);
  }

  /// Efface les lignes **envoyées** lors d'une exécution précédente : le
  /// cycle réussi qui a suivi les a ramenées dans le miroir — ou le serveur
  /// ne les rendra jamais sous cet `id` (fusion, refus) : les garder serait
  /// une fuite éternelle. Même règle que les marques (M2).
  Future<void> purgeReconciled() => (_db.delete(
        _db.localBiblePlanEnrollments,
      )..where((t) => t.dirty.equals(false)))
          .go();

  /// **La file d'envoi du membre**, après chaque synchronisation réussie :
  /// purge, puis un `POST` (ou un `DELETE`) par ligne en attente. Un échec
  /// reste en file pour le cycle suivant.
  Future<void> resendDirty(BiblePlansApi api) async {
    await purgeReconciled();
    final rows = await (_db.select(
      _db.localBiblePlanEnrollments,
    )..where((t) => t.dirty.equals(true)))
        .get();
    for (final r in rows) {
      final sent = r.deletedAt != null
          ? await api.deleteEnrollment(r.id)
          : await api.upsertEnrollment(enrollmentPayload(r));
      final mine = _db.update(_db.localBiblePlanEnrollments)
        ..where(
          (t) =>
              t.id.equals(r.id) & t.clientUpdatedAt.equals(r.clientUpdatedAt),
        );
      await mine.write(
        sent
            ? const LocalBiblePlanEnrollmentsCompanion(
                dirty: Value(false),
                lastError: Value(null),
              )
            : const LocalBiblePlanEnrollmentsCompanion(
                lastError: Value('send failed'),
              ),
      );
    }
  }

  static PlanEnrollment? _ofLocal(LocalBiblePlanEnrollmentRow r) {
    final source = _sourceOf(r.source);
    if (source == null) return null;
    return PlanEnrollment(
      id: r.id,
      source: source,
      planCode: r.planCode,
      planId: r.planId,
      custom: CustomPlanSpec.decode(r.custom),
      startedOn: r.startedOn ?? formatDay(r.clientCreatedAt.toLocal()),
      completedDays: _decodeDays(r.completedDays),
      challengeId: r.challengeId,
      clientCreatedAt: r.clientCreatedAt,
    );
  }

  static PlanEnrollment? _ofMirror(BiblePlanEnrollmentRow r) {
    final source = _sourceOf(r.source);
    final created = r.clientCreatedAt ?? r.createdAt;
    if (source == null || r.startedOn == null) return null;
    return PlanEnrollment(
      id: r.id,
      source: source,
      planCode: r.planCode,
      planId: r.planId,
      custom: CustomPlanSpec.decode(r.custom),
      startedOn: r.startedOn!,
      completedDays: _decodeDays(r.completedDays),
      challengeId: r.challengeId,
      clientCreatedAt: created ?? DateTime.utc(1970),
    );
  }
}

/// Le corps de `POST /bible/plan-enrollments` (contrat §3, validateur S1) :
/// la clé de la source et **elle seule**, les jours triés, les instants en UTC.
@visibleForTesting
Map<String, Object?> enrollmentPayload(LocalBiblePlanEnrollmentRow r) => {
      'id': r.id,
      'source': r.source,
      'planCode': r.source == 'builtin' ? r.planCode : null,
      'planId': r.source == 'published' ? r.planId : null,
      'custom': r.source == 'custom' && r.custom != null
          ? jsonDecode(r.custom!)
          : null,
      'startedOn': r.startedOn,
      'completedDays': _decodeDays(r.completedDays).toList()..sort(),
      'challengeId': r.challengeId,
      'clientCreatedAt': r.clientCreatedAt.toUtc().toIso8601String(),
      'clientUpdatedAt': r.clientUpdatedAt.toUtc().toIso8601String(),
    };
