/// **Le push du navigateur, choisi à la compilation** (#283).
///
/// `main.dart` choisit l'implémentation à l'**exécution** par `kIsWeb`, mais
/// cela ne suffirait pas : `web_push_transport.dart` importe `dart:js_interop`
/// et `package:web`, qui n'existent pas sur la VM. Un import inconditionnel
/// ferait échouer la compilation de `flutter test` et des builds mobiles, quand
/// bien même la branche `kIsWeb` ne serait jamais prise.
///
/// Même porte que le lecteur web (`web_content_player.dart`), l'invite
/// d'installation et le téléchargement hors ligne, et pour la même raison.
library;

export 'web_push_absent.dart'
    if (dart.library.js_interop) 'web_push_transport.dart' show createWebPush;
