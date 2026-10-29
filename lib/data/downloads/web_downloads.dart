/// **Les trois pièces web du téléchargement, choisies à la compilation.**
///
/// `main.dart` choisit à l'**exécution** par `kIsWeb`, mais cela ne suffirait
/// pas : `background_fetch_download_backend.dart` importe `dart:js_interop` et
/// `package:web`, qui n'existent pas sur la VM. Un import inconditionnel ferait
/// échouer la compilation de `flutter test` et des builds mobiles, quand bien
/// même la branche `kIsWeb` ne serait jamais prise.
///
/// La porte est la même que celle du lecteur web (`web_content_player.dart`) et
/// de l'invite d'installation (`web_install_prompt.dart`), et pour la même
/// raison.
library;

export 'web_downloads_absent.dart'
    if (dart.library.js_interop) 'background_fetch_download_backend.dart'
    show
        createWebDiskSpace,
        createWebDownloadBackend,
        createWebDownloadCapabilities;
