import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Les garde-fous de source de la reprise par `Range`** (#216), sur le modèle
/// de `push_seam_test.dart`.
///
/// Deux écarts de l'origine ont été **mesurés en production le 2026-10-15**
/// (streaming ADR-0012, PR streaming-service#52, repris au §6 du PRD). Ils sont
/// contre-intuitifs : les deux gestes que la RFC et l'habitude suggèrent sont
/// précisément ceux qui trompent ici. Aucun test de comportement ne les
/// attrape — le jour où quelqu'un « réparera » la reprise en armant `If-Range`,
/// ou la sondera par un `HEAD`, tout restera vert et la mesure sera perdue.
/// D'où ces garde-fous, qui lisent la source.
///
/// 1. **`If-Range` ne protège de rien.** RustFS l'ignore : validateur périmé ou
///    date, il répond `206` là où la RFC demande `200`. Ce n'est pas une
///    absence de conditionnels — `If-None-Match` rend `304`, `If-Match` rend
///    `412`. La vraie garde est de comparer l'`ETag` que porte le `206` à celui
///    gardé, et de **repartir de zéro** s'il a changé : le plugin le fait
///    (`DownloadTaskRunner.kt`), `DownloadManager._reEnqueue` conclut.
/// 2. **`HEAD` + `Range` répond `200`**, sans `Content-Range`. La commande
///    d'acceptation inscrite dans l'issue d'origine était un `curl -I` : elle
///    aurait fait conclure à une panne inexistante. Tout contrôle passe par un
///    `GET` avec plage — et le moteur n'en émet aucun, le transfert étant sa
///    propre sonde.
void main() {
  /// Le code de `lib/data/downloads/`, commentaires de documentation retirés :
  /// ils **parlent** de ces en-têtes (c'est tout l'objet de leur prose), ils ne
  /// les écrivent pas.
  Map<String, String> sources() {
    final files = Directory('lib/data/downloads')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    return {
      for (final file in files)
        file.path: file
            .readAsLinesSync()
            .where((line) {
              final trimmed = line.trimLeft();
              return !trimmed.startsWith('///') && !trimmed.startsWith('//');
            })
            .join('\n'),
    };
  }

  List<String> mentioning(Pattern needle) {
    final guilty = <String>[];
    sources().forEach((path, code) {
      if (code.contains(needle)) guilty.add(path);
    });
    guilty.sort();
    return guilty;
  }

  test('personne n\'arme If-Range — l\'origine l\'ignore', () {
    expect(
      mentioning(RegExp('[Ii]f-[Rr]ange')),
      isEmpty,
      reason: 'mesuré : 206 même sur un validateur périmé, la garde est '
          'la comparaison d\'ETag puis le départ de zéro',
    );
  });

  test('aucune sonde HEAD : cette origine y répond 200 sans Content-Range', () {
    expect(
      mentioning(RegExp(r'''\bHEAD\b''')),
      isEmpty,
      reason: 'une reprenabilité se sonde par un GET avec plage, jamais un HEAD',
    );
    expect(
      mentioning('ParallelDownloadTask'),
      isEmpty,
      reason: 'seule classe du plugin qui ouvre par un HEAD '
          '(ParallelDownloadTaskRunner.kt, BDPlugin.swift)',
    );
  });

  test('le plugin ne vit qu\'au bout de la couture', () {
    expect(
      mentioning('package:background_downloader/'),
      ['lib/data/downloads/background_downloader_backend.dart'],
      reason: 'tout le reste ne connaît que DownloadBackend, et se teste '
          'donc sur la VM Dart',
    );
  });
}
