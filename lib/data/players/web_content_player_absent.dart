/// **Le lecteur web, hors du web** — la moitié de la porte de
/// `web_content_player.dart` qui n'a rien à ouvrir.
///
/// Compilée pour la VM et pour le mobile, elle n'importe **ni**
/// `dart:js_interop` **ni** `package:web` : c'est tout son intérêt.
library;

import 'content_player.dart';

/// Ne s'appelle jamais : `main.dart` ne demande le lecteur web que sous
/// `kIsWeb`, et sous `kIsWeb` c'est `hls_content_player.dart` qui répond.
///
/// Lève plutôt que de rendre un lecteur inerte : un appel ici est une erreur de
/// câblage, et un silence la déguiserait en application muette — la panne
/// exactement la plus longue à diagnostiquer.
ContentPlayer createWebContentPlayer() {
  throw UnsupportedError(
    'Le lecteur hls.js n\'existe que sur le web ; ailleurs, c\'est '
    'JustAudioContentPlayer qui sert.',
  );
}
