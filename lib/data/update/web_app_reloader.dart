/// **Le rechargement, choisi à la compilation.**
///
/// `main.dart` choisit l'implémentation à l'**exécution** par `kIsWeb`, mais
/// cela ne suffirait pas : `browser_app_reloader.dart` importe
/// `dart:js_interop` et `package:web`, qui n'existent pas sur la VM. Même porte
/// que `web_install_prompt.dart` et `web_content_player.dart`, même raison.
library;

export 'web_app_reloader_absent.dart'
    if (dart.library.js_interop) 'browser_app_reloader.dart'
    show createAppReloader;
