/// **Le push du navigateur, hors du navigateur** — la moitié de la porte de
/// `web_push.dart` qui n'a rien à ouvrir. N'importe ni `dart:js_interop` ni
/// `package:web` : c'est tout son intérêt.
library;

import 'push_transport.dart';

/// Ne s'appelle jamais : `main.dart` ne la demande que sous `kIsWeb`.
///
/// Lève plutôt que de rendre `null`, comme `createWebContentPlayer` : un appel
/// ici est une erreur de câblage, et un `null` la déguiserait en « cet appareil
/// n'a pas de push » — exactement la panne qu'on ne diagnostique pas.
Future<({PushTransport transport, PushPermissionRequest? askPermission})?>
    createWebPush() async {
  throw UnsupportedError(
    'Le push du navigateur n\'existe que sur le web ; ailleurs, c\'est '
    'FcmPushTransport qui sert.',
  );
}
