/// **Le catalogue réel des versions** (M4, mobile#202, décision 9) : les deux
/// versions factices, installées d'office, **fusionnées** avec la collection
/// `bible_versions` (S5), installées ou non selon `bible_installed_versions`.
///
/// Depuis #249, les factices ne paraissent que **tant qu'aucune vraie version
/// n'est proposée** — voir [MergedBibleCatalog._merge].
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

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';
import '../data/bible_archive.dart';
import '../data/bible_source.dart';
import '../data/bible_store.dart';
import '../data/canon.dart';
import '../data/placeholder_bible.dart';
import '../search/bible_search_index.dart';

/// Une version telle que le catalogue fusionné la décrit.
final class BibleCatalogEntry {
  const BibleCatalogEntry({
    required this.version,
    this.sizeBytes,
    this.license,
    this.versification,
    this.archiveUrl,
    this.localPath,
    this.builtIn = false,
  });

  final BibleVersion version;
  final int? sizeBytes;

  /// `bible_versions.license` — la mention que plusieurs ayants droit exigent
  /// **là où le texte est lu** (la S21 : « Reproduit avec aimable
  /// autorisation »). Elle vit ici et non sur [BibleVersion] : les deux
  /// exemples figés n'en ont pas, et ce n'est pas l'identité d'une traduction.
  final String? license;

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
          ':${e.versification?.signature.hashCode}:${e.localPath}'
          ':${e.license}',
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
    // **Les exemples s'effacent dès qu'une vraie version est proposée**
    // (#249, décision du 26/10/2026) : constaté sur l'émulateur, « Bible
    // Bovet Bonnet » installée et lisible, et les deux exemples toujours
    // affichés à côté d'elle.
    //
    // « Proposée » = servie par la synchro **et** porteuse d'une archive.
    // Pas « publiée » : une version déposée mais pas encore convertie n'a pas
    // d'`archive_url`, n'est utilisable d'aucune façon, et laisser les
    // exemples disparaître pour elle priverait le fidèle de tout texte sans
    // rien lui donner en échange. Un code factice servi est exclu du
    // catalogue quelques lignes plus bas — il ne compte donc pas ici non
    // plus, sinon les exemples s'effaceraient au profit d'une ligne que
    // personne ne verrait.
    final proposed = served.any(
      (r) => r.archiveUrl != null && !builtIn.contains(r.code),
    );
    return [
      if (!proposed)
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
            license: r.license,
            versification: versifications[r.code],
            archiveUrl: r.archiveUrl,
            localPath: installedPaths[r.code],
          ),
    ];
  }

  @override
  Future<List<BibleVersion>> versions() async =>
      [for (final e in entries) e.version];

  /// **La version ouverte par défaut** (`ActiveBibleVersion.build`) : la
  /// première **installée** du catalogue.
  ///
  /// C'était le code du premier exemple, qui n'existe plus dans le catalogue
  /// dès qu'une vraie version est proposée (#249). « La première ligne » n'y
  /// suffisait pas : le portail sert ses versions avant qu'aucune ne soit
  /// descendue, et le lecteur se serait ouvert sur l'invitation à télécharger
  /// alors qu'une autre version était déjà lisible. Catalogue vide — avant la
  /// première synchro, aucune ligne du tout : le code du premier exemple, ce
  /// que rendait M4.
  @override
  String get defaultVersionCode {
    for (final e in entries) {
      if (e.version.installed) return e.version.code;
    }
    return entries.isEmpty
        ? kPlaceholderVersions.first.code
        : entries.first.version.code;
  }

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

  /// La langue déclarée par la version — celle du catalogue servi, ou celle
  /// que son archive a laissée dans `bible_installed_versions`.
  @override
  String languageFor(String versionCode) {
    for (final e in entries) {
      if (e.version.code == versionCode) return e.version.language;
    }
    return 'fr';
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

/// **Une vraie Bible est-elle sur le téléphone ?** (#265) — une version au
/// `localPath` posé, donc descendue de son archive. Les exemples
/// (`kPlaceholderVersions`, installés d'office) ne comptent **jamais** : sans
/// vraie version, la coquille montre l'invitation à en télécharger une.
///
/// Tant que le magasin n'a rien répondu, `true` : l'invitation ne clignote pas
/// à chaque ouverture chez qui a déjà sa Bible.
final bibleHasRealVersionProvider = Provider<bool>((ref) {
  if (!ref.watch(bibleServedVersionsProvider).hasValue ||
      !ref.watch(bibleInstalledVersionsProvider).hasValue) {
    return true;
  }
  return ref
      .watch(mergedBibleCatalogProvider)
      .entries
      .any((e) => e.localPath != null);
});

/// **Oublie les versions dont les octets ont disparu.**
///
/// Une ligne de `bible_installed_versions` survit à ses fichiers : un appareil
/// réinstallé, une place disque rendue, une sauvegarde restaurée. La version se
/// disait alors installée, le lecteur répondait « ce chapitre n'est pas
/// disponible dans cette version », et le fidèle n'avait **aucun moyen de la
/// retélécharger** — l'écran des versions lui proposait une corbeille, pas une
/// flèche. Constaté sur iPad le 30/10/2026.
///
/// Oublier la ligne remet tout d'aplomb d'un coup : l'écran des versions
/// repropose le téléchargement, et l'index plein texte de cette version part
/// avec elle ([BibleVersionInstaller.remove] s'en charge). Appelé une fois au
/// démarrage, dans `app.dart`.
///
/// Ne lève jamais : sans magasin lisible, on préfère laisser l'état en place
/// plutôt que d'effacer ce qu'on n'a pas su lire.
final bibleForgetMissingProvider = Provider<Future<void> Function()>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final installer = ref.watch(bibleInstallerProvider);
  return () async {
    try {
      final store = bibleStore();
      for (final row in await db.select(db.bibleInstalledVersions).get()) {
        final path = row.localPath;
        // `localPath` nul : la ligne n'a jamais porté d'archive. Elle rend un
        // texte d'exemple sous le nom d'une vraie version — le même mensonge.
        if (path != null && await store.has(path)) continue;
        await installer.remove(db, row.code);
      }
    } on Object {
      // Magasin indisponible : l'état reste tel quel.
    }
  };
});

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
  /// Ignorée dans un navigateur, qui n'a pas de dossier (`bible_store.dart`).
  final Future<String> Function()? root;

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
    if (path != null) await bibleStore().remove(path);
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
