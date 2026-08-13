/// **Le lecteur web, choisi à la compilation.**
///
/// `main.dart` choisit l'implémentation à l'**exécution** par `kIsWeb`, mais
/// cela ne suffirait pas : `hls_content_player.dart` importe `dart:js_interop`
/// et `package:web`, qui n'existent pas sur la VM. Un import inconditionnel
/// ferait échouer la compilation de `flutter test` et des builds mobiles, quand
/// bien même la branche `kIsWeb` ne serait jamais prise.
///
/// D'où cette porte : le web reçoit la vraie implémentation, tout le reste
/// reçoit un refus qui ne compile aucun interop.
library;

export 'web_content_player_absent.dart'
    if (dart.library.js_interop) 'hls_content_player.dart'
    show createWebContentPlayer;
