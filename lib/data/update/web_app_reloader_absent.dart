/// **Le rechargement, hors du web** — la moitié de la porte qui n'a rien à
/// recharger. N'importe ni `dart:js_interop` ni `package:web`.
library;

import 'app_reloader.dart';

/// Ne s'appelle jamais : `main.dart` ne la demande que sous `kIsWeb`.
///
/// Lève plutôt que de rendre un rechargeur inerte, comme
/// `createWebContentPlayer` : un appel ici est une erreur de câblage, et un
/// silence la déguiserait en bouton qui ne fait rien — exactement la panne
/// qu'on ne diagnostique pas.
AppReloader createAppReloader() {
  throw UnsupportedError(
    'Le rechargement n\'existe que sur le web ; ailleurs, c\'est le magasin '
    'qui porte la mise à jour.',
  );
}
