/// **L'invite d'installation, choisie à la compilation.**
///
/// `main.dart` choisit l'implémentation à l'**exécution** par `kIsWeb`, mais
/// cela ne suffirait pas : `browser_install_prompt.dart` importe
/// `dart:js_interop` et `package:web`, qui n'existent pas sur la VM. La porte
/// est la même que celle du lecteur web (`web_content_player.dart`), et pour la
/// même raison.
library;

export 'web_install_prompt_absent.dart'
    if (dart.library.js_interop) 'browser_install_prompt.dart'
    show createInstallPrompt;
