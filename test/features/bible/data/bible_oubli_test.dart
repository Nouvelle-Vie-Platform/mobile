/// **Une Bible dont les octets ont disparu doit se reproposer** (30/10/2026).
///
/// Une ligne de `bible_installed_versions` survit à ses fichiers : un appareil
/// réinstallé, une place disque rendue, une sauvegarde restaurée. Constaté sur
/// un iPad, et le symptôme ne ressemblait pas à sa cause — le lecteur
/// répondait « ce chapitre n'est pas disponible dans cette version », ce qui
/// désigne la version alors que c'est l'appareil qui a perdu le texte. Pire :
/// l'écran des versions proposait une corbeille au lieu d'une flèche, donc
/// aucun moyen de la retélécharger.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/features/bible/personalize/bible_catalog.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/local_database_fixtures.dart';

void main() {
  late AppDatabase db;
  late Directory root;

  setUp(() {
    db = openTestDatabase();
    root = Directory.systemTemp.createTempSync('bible_oubli_');
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Inscrit une version comme installée, avec ou sans ses fichiers.
  Future<void> inscrire(String code, {required bool avecFichiers}) async {
    final dossier = Directory('${root.path}/bible/$code');
    if (avecFichiers) {
      dossier.createSync(recursive: true);
      File('${dossier.path}/manifest.json')
          .writeAsStringSync('{"code":"$code"}');
    }
    await db.into(db.bibleInstalledVersions).insert(
          BibleInstalledVersionsCompanion.insert(
            code: code,
            name: code,
            localPath: Value(dossier.path),
            installedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<List<String>> inscrites() async =>
      (await db.select(db.bibleInstalledVersions).get())
          .map((r) => r.code)
          .toList();

  Future<void> oublier() async {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    await c.read(bibleForgetMissingProvider)();
  }

  test('celle dont les fichiers ont disparu est oubliée, l\'autre reste',
      () async {
    await inscrire('ewe2020', avecFichiers: false);
    await inscrire('frebbb', avecFichiers: true);
    expect(await inscrites(), containsAll(['ewe2020', 'frebbb']));

    await oublier();

    expect(await inscrites(), ['frebbb'],
        reason: 'ewe2020 n\'a plus de fichiers : elle doit se reproposer');
  });

  test('une ligne sans chemin est oubliée aussi', () async {
    await db.into(db.bibleInstalledVersions).insert(
          BibleInstalledVersionsCompanion.insert(
            code: 'sanschemin',
            name: 'Sans chemin',
            installedAt: DateTime.now().toUtc(),
          ),
        );
    await oublier();
    // Sans chemin, le catalogue sert un texte d'exemple sous le nom d'une
    // vraie version : le même mensonge, par une autre porte.
    expect(await inscrites(), isEmpty);
  });

  test('rien n\'est oublié quand tout est là', () async {
    await inscrire('frebbb', avecFichiers: true);
    await inscrire('ewe2020', avecFichiers: true);
    await oublier();
    expect(await inscrites(), hasLength(2));
  });
}
