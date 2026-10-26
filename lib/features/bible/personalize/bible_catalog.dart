/// **Le catalogue réel des versions** (M4, mobile#202, décision 9) : les deux
/// versions factices, installées d'office, **fusionnées** avec la collection
/// `bible_versions` (S5), installées ou non selon `bible_installed_versions`.
///
/// Depuis C4 (server-portal#605), « Télécharger » descend la **vraie**
/// archive de la version (`bible_archive.dart`) : M4 ne simulait une
/// progression que parce que le portail n'en servait aucune. Une version
/// n'est donc téléchargeable que si elle **a** une archive — c'est le sens de
/// [BibleCatalogEntry.downloadable], et il a longtemps été écrit à l'envers
/// (`archiveUrl == null`) sans que rien ne le montre, puisque aucune version
/// n'avait d'`archive_url`.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_archive.dart';
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
    this.archiveUrl,
    this.localPath,
    this.builtIn = false,
  });

  final BibleVersion version;
  final int? sizeBytes;

  /// La versification **relevée** de cette version installée (C3, #240), ou
  /// `null` : le canon figé sert alors de repli.
  final BibleVersification? versification;

  /// `bible_versions.archiveUrl` — l'archive à descendre, ou `null` quand le
  /// portail n'en publie pas encore pour cette version.
  final String? archiveUrl;

  /// `bible_installed_versions.localPath` — le dossier où C4 a dézippé les
  /// livres. `null` pour une version non installée, et pour celles que la
  /// progression simulée de M4 avait inscrites sans aucun octet.
  final String? localPath;

  /// Une des deux versions factices : ni téléchargée, ni supprimable.
  final bool builtIn;

  /// **Téléchargeable = le portail en sert une archive.** Dérivé, et non
  /// stocké : c'est la même donnée dite deux fois qui avait permis à
  /// l'inversion de dormir ici. `bible_personalize_test.dart` rougit si elle
  /// revient.
  bool get downloadable => archiveUrl != null;
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
  ///
  /// `localPath` y est depuis C4, et ce n'est pas décoratif : une version
  /// réinstallée depuis son archive change de source (factice → archive) sans
  /// qu'aucun des autres champs bouge, et le provider gardait l'ancien
  /// catalogue — donc l'ancien texte.
  late final String _signature = [
    for (final e in entries)
      '${e.version.code}:${e.version.name}:${e.version.language}:'
          '${e.version.installed}:${e.downloadable}:${e.sizeBytes}'
          ':${e.versification?.signature.hashCode}:${e.localPath}',
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
    final installedPaths = {for (final i in installed) i.code: i.localPath};
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
              installed: installedPaths.containsKey(r.code),
            ),
            sizeBytes: r.sizeBytes,
            versification: versifications[r.code],
            archiveUrl: r.archiveUrl,
            localPath: installedPaths[r.code],
          ),
    ];
  }

  @override
  Future<List<BibleVersion>> versions() async =>
      [for (final e in entries) e.version];

  @override
  String get defaultVersionCode => kPlaceholderVersions.first.code;

  /// Le texte d'une version installée : **celui de son archive** si elle en a
  /// une sur le disque (C4), sinon la Bible factice.
  ///
  /// Le repli factice n'est pas un reste : il tient les deux versions
  /// intégrées, et les lignes qu'avait écrites la progression simulée de M4 —
  /// elles n'ont pas de `localPath`, et un écran vide à la place de l'Écriture
  /// serait pire qu'un texte d'exemple annoncé comme tel.
  @override
  BibleSource? sourceFor(String versionCode) {
    for (final e in entries) {
      if (e.version.code != versionCode || !e.version.installed) continue;
      if (e.localPath case final path?) {
        return InstalledBibleSource(versionCode, path);
      }
      final builtInIndex =
          kPlaceholderVersions.indexWhere((v) => v.code == versionCode);
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

/// **L'installation d'une version**, derrière un provider : l'appareil
/// télécharge et écrit dans son support, les tests posent des octets en
/// mémoire et un dossier temporaire. Sans cette couture, un test d'écran
/// toucherait le réseau et `getApplicationSupportDirectory()`, dont le canal
/// de plugin n'existe pas sous `flutter test`.
final bibleInstallerProvider = Provider<BibleVersionInstaller>(
  (ref) => const BibleVersionInstaller(),
);

final class BibleVersionInstaller {
  const BibleVersionInstaller({
    this.fetch = downloadBibleArchive,
    this.root,
  });

  /// La descente des octets. Remplacée en test.
  final BibleArchiveFetch fetch;

  /// La racine du magasin, `getApplicationSupportDirectory` par défaut.
  final Future<Directory> Function()? root;

  /// **Installe [entry]** : téléchargement, vérification de l'empreinte,
  /// dézippage, ligne `bible_installed_versions`, puis indexation (M3). Le
  /// flux rend la progression de 0 à 1 ; il **lève**
  /// [BibleArchiveException] si l'archive est refusée, et rien n'est alors
  /// installé — l'écran en fait un message.
  ///
  /// La barre s'arrête à 90 % pendant la descente : le dézippage et
  /// l'indexation suivent, et annoncer « fini » avant eux ferait disparaître
  /// l'indicateur sur un écran qui ne répond pas encore.
  Stream<double> install(
    AppDatabase db,
    BibleCatalogEntry entry, {
    required Future<void> Function(String code) ensureIndexed,
  }) {
    final url = entry.archiveUrl;
    if (entry.builtIn || url == null) return const Stream.empty();
    final progress = StreamController<double>();
    // Dans `onListen` : rien ne part tant que personne n'écoute, comme le
    // générateur `async*` qu'il remplace. Un `StreamController` et non
    // `async*` parce que la progression arrive par **rappel** (`dio`), et
    // qu'un générateur ne peut pas émettre depuis un rappel.
    progress.onListen = () async {
      try {
        final bytes = await fetch(url, (received, total) {
          if (total > 0) progress.add(received / total * 0.9);
        });
        final installed = await unpackBibleArchive(
          code: entry.version.code,
          url: url,
          bytes: bytes,
          root: root,
        );
        await db.into(db.bibleInstalledVersions).insertOnConflictUpdate(
              BibleInstalledVersionsCompanion.insert(
                code: entry.version.code,
                name: entry.version.name,
                language: Value(entry.version.language),
                sizeBytes: Value(entry.sizeBytes),
                localPath: Value(installed.localPath),
                installedAt: DateTime.now().toUtc(),
                // Réinstallée : l'index est à refaire (M3).
                indexed: const Value(false),
                // La versification du manifeste vit **ici** et nulle part
                // ailleurs (C3, #240) : `bible_versions` est un miroir que la
                // synchronisation réécrit en `insertOrReplace`.
                versification: Value(installed.versification),
              ),
            );
        await ensureIndexed(entry.version.code);
        progress.add(1);
      } on Object catch (error, stack) {
        progress.addError(error, stack);
      } finally {
        await progress.close();
      }
    };
    return progress.stream;
  }

  /// **Retire une version installée** : les octets, la ligne, l'index. Les
  /// trois, et dans cet ordre — une ligne sans fichiers ferait lire un
  /// chapitre vide à la place de l'Écriture.
  Future<void> remove(AppDatabase db, String code) async {
    final row = await (db.select(db.bibleInstalledVersions)
          ..where((t) => t.code.equals(code)))
        .getSingleOrNull();
    final path = row?.localPath;
    if (path != null) {
      final dir = Directory(path);
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
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
}
