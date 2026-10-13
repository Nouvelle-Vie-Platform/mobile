/// **La voix naturelle Piper fr « siwis »** (M4, mobile#202, décision 10,
/// piège 6) : **jamais embarquée**, téléchargée à la demande, vérifiée
/// (taille + sha256), décompressée, supprimable.
///
/// L'URL et l'empreinte sont figées ici (plan §6). L'archive se télécharge
/// par un `Dio` **nu** : aucun jeton de l'API ne part vers GitHub.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const String kPiperUrl = 'https://github.com/k2-fsa/sherpa-onnx/releases/'
    'download/tts-models/vits-piper-fr_FR-siwis-medium.tar.bz2';
const int kPiperBytes = 67207459;

/// Calculé le 2026-10-13 sur l'archive publiée (M4).
const String kPiperSha256 =
    '375909aa30842b3a4efa10b1beb1d761af792960ae6873b4d53889f96c66195b';

const String _modelDir = 'vits-piper-fr_FR-siwis-medium';

/// Les fichiers que `sherpa_onnx` lit.
final class PiperModel {
  PiperModel(String root)
      : model = '$root/$_modelDir/fr_FR-siwis-medium.onnx',
        tokens = '$root/$_modelDir/tokens.txt',
        dataDir = '$root/$_modelDir/espeak-ng-data';

  final String model;
  final String tokens;
  final String dataDir;
}

/// L'archive reçue n'est pas celle qu'on attend : elle est effacée.
final class PiperVerificationError implements Exception {
  const PiperVerificationError(this.reason);
  final String reason;
  @override
  String toString() => 'PiperVerificationError: $reason';
}

/// Rend `null` si [file] fait [size] octets et a l'empreinte [sha256Hex],
/// sinon la raison du refus.
Future<String?> verifyPiperArchive(
  File file, {
  int size = kPiperBytes,
  String sha256Hex = kPiperSha256,
}) async {
  final length = await file.length();
  if (length != size) return 'taille $length, attendue $size';
  final digest = await sha256.bind(file.openRead()).first;
  if (digest.toString() != sha256Hex) return 'empreinte $digest';
  return null;
}

/// Télécharge [url] dans [path] en rapportant la progression.
typedef PiperDownload = Future<void> Function(
  String url,
  String path,
  void Function(int received, int total) onProgress,
);

Future<void> _dioDownload(
  String url,
  String path,
  void Function(int, int) onProgress,
) =>
    Dio().download(url, path, onReceiveProgress: onProgress);

/// Le dossier de la voix, son téléchargement et sa suppression.
class PiperVoiceStore {
  PiperVoiceStore({
    Future<Directory> Function()? root,
    PiperDownload? download,
    this.size = kPiperBytes,
    this.sha256Hex = kPiperSha256,
  })  : _root = root ?? _defaultRoot,
        _download = download ?? _dioDownload;

  final Future<Directory> Function() _root;
  final PiperDownload _download;
  final int size;
  final String sha256Hex;

  static Future<Directory> _defaultRoot() async => Directory(
        '${(await getApplicationSupportDirectory()).path}/bible_voice',
      );

  /// La voix installée, ou `null`.
  Future<PiperModel?> installed() async {
    try {
      final model = PiperModel((await _root()).path);
      final ok = await File(model.model).exists() &&
          await File(model.tokens).exists() &&
          await Directory(model.dataDir).exists();
      return ok ? model : null;
    } on Object {
      return null;
    }
  }

  /// Télécharge, vérifie, décompresse. Émet la progression (0 → 1) du
  /// téléchargement ; lève [PiperVerificationError] sur une archive fausse.
  Stream<double> install() {
    final out = StreamController<double>();
    Future<void> run() async {
      File? archive;
      (Object, StackTrace)? failure;
      try {
        final root = await _root();
        await root.create(recursive: true);
        archive = File('${root.path}/voice.tar.bz2');
        var last = 0.0;
        await _download(kPiperUrl, archive.path, (received, total) {
          final p = (received / (total > 0 ? total : size)).clamp(0.0, 1.0);
          if (p - last >= 0.01) out.add(last = p);
        });
        final refused = await verifyPiperArchive(
          archive,
          size: size,
          sha256Hex: sha256Hex,
        );
        if (refused != null) throw PiperVerificationError(refused);
        await _extract(archive.path, root.path);
      } on Object catch (error, stack) {
        failure = (error, stack);
      }
      // L'archive part avant qu'on annonce quoi que ce soit.
      try {
        await archive?.delete();
      } on FileSystemException {
        // Jamais écrite.
      }
      if (failure != null) {
        out.addError(failure.$1, failure.$2);
      } else {
        out.add(1.0);
      }
      await out.close();
    }

    unawaited(run());
    return out.stream;
  }

  /// Efface la voix et tout ce qui l'accompagne.
  Future<void> remove() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

/// Hors de toute fermeture : l'isolate n'emporte que les deux chemins.
Future<void> _extract(String from, String to) =>
    Isolate.run(() => extractFileToDisk(from, to));

final piperVoiceStoreProvider = Provider<PiperVoiceStore>(
  (ref) => PiperVoiceStore(),
);

/// La voix installée (`null` : absente). À invalider après une installation
/// ou une suppression.
final piperVoiceProvider = FutureProvider<PiperModel?>(
  (ref) => ref.watch(piperVoiceStoreProvider).installed(),
);
