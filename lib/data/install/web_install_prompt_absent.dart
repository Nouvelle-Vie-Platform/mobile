/// **L'invite d'installation, hors du web** — la moitié de la porte qui n'a
/// rien à ouvrir. N'importe ni `dart:js_interop` ni `package:web`.
library;

import 'install_prompt.dart';

/// Ne s'appelle jamais : `main.dart` ne la demande que sous `kIsWeb`.
///
/// Lève plutôt que de rendre l'inerte, comme `createWebContentPlayer` : un
/// appel ici est une erreur de câblage, et un silence la déguiserait en
/// bandeau qui ne paraît jamais — exactement la panne qu'on ne diagnostique pas.
InstallPrompt createInstallPrompt() {
  throw UnsupportedError(
    'L\'invite d\'installation n\'existe que sur le web ; ailleurs, '
    'l\'application est déjà installée.',
  );
}
