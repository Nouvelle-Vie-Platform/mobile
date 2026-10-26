/// **Le catalogue réel des versions** (M4, mobile#202, décision 9) : les deux
/// versions factices, installées d'office, **fusionnées** avec la collection
/// `bible_versions` (S5), installées ou non selon `bible_installed_versions`.
///
/// Tant que le chantier du contenu ne sert aucune archive (`archiveUrl` nul),
/// « Télécharger » simule une progression puis installe la **version
/// factice** sous le code de la version servie ; une version qui porterait une
/// archive n'est pas encore téléchargeable.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_source.dart';
import '../data/canon.dart';
import '../data/placeholder_bible.dart';
import '../search/bible_search_index.dart';

/// Une version telle que le catalogue fusionné la décrit.
final class BibleCatalogEntry {
  const BibleCatalogEntry({
    required this.version,
    this.sizeBytes,
    this.versification,
    this.builtIn = false,
    this.downloadable = false,
  });

  final BibleVersion version;
  final int? sizeBytes;

  /// La versification **relevée** de cette version installée (C3, #240), ou
  /// `null` : le canon figé sert alors de repli.
  final BibleVersification? versification;

  /// Une des deux versions factices : ni téléchargée, ni supprimable.
  final bool builtIn;

  /// Servie sans archive : son installation (factice) est possible.
  final bool downloadable;
}

/// Le catalogue fusionné, sur deux listes lues du magasin.
final class MergedBibleCatalog implements BibleCatalog {
  MergedBibleCatalog({
    List<BibleVersionRow> remote = const [],
    List<BibleInstalledVersionRow> installed = const [],
  }) : entries = _merge(remote, installed);

  final List<BibleCatalogEntry> entries;

  /// Ce que le catalogue dit, en une chaîne : deux catalogues qui disent la
  /// même chose sont **égaux**, et le provider ne prévient personne — sinon
  /// chaque émission du magasin rechargerait le chapitre ouvert.
  late final String _signature = [
    for (final e in entries)
      '${e.version.code}:${e.version.name}:${e.version.language}:'
          '${e.version.installed}:${e.downloadable}:${e.sizeBytes}'
          ':${e.versification?.signature.hashCode}',
  ].join('|');

  @override
  bool operator ==(Object other) =>
      other is MergedBibleCatalog && other._signature == _signature;

  @override
  int get hashCode => _signature.hashCode;

  static List<BibleCatalogEntry> _merge(
    List<BibleVersionRow> remote,
    List<BibleInstalledVersionRow> installed,
  ) {
    final builtIn = {for (final v in kPlaceholderVersions) v.code};
    final installedCodes = {for (final i in installed) i.code};
    final versifications = {
      for (final i in installed)
        if (BibleVersification.tryParse(i.versification) case final v?)
          i.code: v,
    };
    final served = [...remote]..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return [
      for (final v in kPlaceholderVersions)
        BibleCatalogEntry(version: v, builtIn: true),
      for (final r in served)
        if (!builtIn.contains(r.code))
          BibleCatalogEntry(
            version: BibleVersion(
              code: r.code,
              name: r.name,
              language: r.language ?? 'fr',
              installed: installedCodes.contains(r.code),
            ),
            sizeBytes: r.sizeBytes,
            versification: versifications[r.code],
            downloadable: r.archiveUrl == null,
          ),
    ];
  }

  @override
  Future<List<BibleVersion>> versions() async =>
      [for (final e in entries) e.version];

  @override
  String get defaultVersionCode => kPlaceholderVersions.first.code;

  @override
  BibleSource? sourceFor(String versionCode) {
    for (final e in entries) {
      if (e.version.code != versionCode || !e.version.installed) continue;
      final builtInIndex =
          kPlaceholderVersions.indexWhere((v) => v.code == versionCode);
      // ponytail: une version servie s'installe en factice (variante tirée du
      // code) ; le chantier du contenu posera ici la source de l'archive.
      final variant = builtInIndex >= 0
          ? builtInIndex
          : versionCode.codeUnits.fold<int>(0, (a, b) => a + b);
      return PlaceholderBibleSource(versionCode, variant: variant);
    }
    return null;
  }

  /// La versification relevée de la version installée, sinon le canon figé
  /// (C3, #240) : une version servie sans relevé — et les deux factices — se
  /// lisent donc exactement comme avant.
  @override
  BibleVersification versificationFor(String versionCode) {
    for (final e in entries) {
      if (e.version.code == versionCode && e.versification != null) {
        return e.versification!;
      }
    }
    return kCanonVersification;
  }
}

/// Les versions servies par S5 (publiées, non retirées).
final bibleServedVersionsProvider = StreamProvider<List<BibleVersionRow>>(
  (ref) {
    final db = ref.watch(appDatabaseProvider);
    return (db.select(db.bibleVersions)
          ..where((t) => t.publishedAt.isNotNull()))
        .watch();
  },
);

/// Les versions installées sur ce téléphone.
final bibleInstalledVersionsProvider =
    StreamProvider<List<BibleInstalledVersionRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.bibleInstalledVersions).watch();
});

/// Le catalogue fusionné. `bibleCatalogProvider` (M1) le rend.
final mergedBibleCatalogProvider = Provider<MergedBibleCatalog>(
  (ref) => MergedBibleCatalog(
    remote: ref.watch(bibleServedVersionsProvider).value ?? const [],
    installed: ref.watch(bibleInstalledVersionsProvider).value ?? const [],
  ),
);

/// **L'indexation d'une version installée** (M3 : `BibleSearchIndex
/// .ensureIndexed`). Le catalogue est relu dans le magasin au moment de
/// l'appel : celui du provider ne sait pas encore que la version vient
/// d'être installée.
final bibleEnsureIndexedProvider =
    Provider<Future<void> Function(String code)>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (code) async {
    final catalog = MergedBibleCatalog(
      remote: await (db.select(db.bibleVersions)
            ..where((t) => t.publishedAt.isNotNull()))
          .get(),
      installed: await db.select(db.bibleInstalledVersions).get(),
    );
    await BibleSearchIndex(db, catalog).ensureIndexed(code);
  };
});

/// La durée d'un téléchargement simulé, en [kSimulatedSteps] pas.
const int kSimulatedSteps = 20;
const Duration kSimulatedStep = Duration(milliseconds: 120);

/// **Installe** [entry] : progression simulée (0 → 1), ligne
/// `bible_installed_versions`, puis indexation. Sans effet sur une version
/// intégrée ou qui porte une archive.
Stream<double> installBibleVersion(
  AppDatabase db,
  BibleCatalogEntry entry, {
  required Future<void> Function(String code) ensureIndexed,
  Duration step = kSimulatedStep,
}) async* {
  if (entry.builtIn || !entry.downloadable) return;
  for (var i = 1; i <= kSimulatedSteps; i++) {
    await Future<void>.delayed(step);
    yield i / kSimulatedSteps;
  }
  final v = entry.version;
  await db.into(db.bibleInstalledVersions).insertOnConflictUpdate(
        BibleInstalledVersionsCompanion.insert(
          code: v.code,
          name: v.name,
          language: Value(v.language),
          sizeBytes: Value(entry.sizeBytes),
          installedAt: DateTime.now().toUtc(),
          // Réinstallée : l'index est à refaire (M3).
          indexed: const Value(false),
        ),
      );
  await ensureIndexed(v.code);
}

/// Retire une version installée, et son index.
Future<void> removeBibleVersion(AppDatabase db, String code) async {
  await db.transaction(() async {
    await (db.delete(db.bibleInstalledVersions)
          ..where((t) => t.code.equals(code)))
        .go();
    await db.customStatement(
      'DELETE FROM bible_fts WHERE version_code = ?',
      [code],
    );
  });
}
