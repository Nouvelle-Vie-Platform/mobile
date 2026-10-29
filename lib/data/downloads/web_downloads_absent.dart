/// **Le téléchargement web, hors du web** — la moitié de la porte de
/// `web_downloads.dart` qui n'a rien à ouvrir. N'importe ni `dart:js_interop`
/// ni `package:web` : c'est tout son intérêt.
library;

import 'disk_space.dart';
import 'download_backend.dart';
import 'download_capabilities.dart';

/// Ne s'appellent jamais : `main.dart` ne les demande que sous `kIsWeb`.
///
/// Lèvent plutôt que de rendre des doubles inertes, comme
/// `createWebContentPlayer` : un appel ici est une erreur de câblage, et un
/// silence la déguiserait en bouton Télécharger qui ne fait rien — exactement
/// la panne qu'on ne diagnostique pas.
Never _nowhere() {
  throw UnsupportedError(
    'Background Fetch n\'existe que dans un navigateur ; ailleurs, c\'est '
    'BackgroundDownloaderBackend qui sert.',
  );
}

DownloadBackend createWebDownloadBackend() => _nowhere();

DownloadCapabilities createWebDownloadCapabilities() => _nowhere();

DiskSpace createWebDiskSpace() => _nowhere();
