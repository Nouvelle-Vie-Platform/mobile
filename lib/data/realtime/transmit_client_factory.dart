/// **La porte du client Transmit, choisie à la compilation** (D8 de
/// `docs/temps-reel-sse.md`) — patron de `web_content_player.dart` côté lecteur.
///
/// Le choix Http (natif iOS/Android, flux `Dio`) vs Web (lecteur `fetch`) ne
/// peut pas se faire à l'exécution seulement : `WebTransmitClient` importera
/// `dart:js_interop` / `package:web`, absents de la VM et du mobile. Un import
/// inconditionnel casserait alors la compilation de `flutter test` et des builds
/// natifs. D'où cette porte, unique frontière que le reste de l'application
/// franchit pour obtenir un [TransmitClient] réel :
///
/// ```dart
/// import 'package:.../data/realtime/transmit_client_factory.dart';
/// final client = createTransmitClient();
/// ```
///
/// Chaque moitié expose le **même** top-level `TransmitClient
/// createTransmitClient()` — `http_transmit_client.dart` rend un
/// `HttpTransmitClient`, `web_transmit_client.dart` rendra un
/// `WebTransmitClient` —, exactement comme `hls_content_player.dart` /
/// `web_content_player_absent.dart` exposent `createWebContentPlayer()`.
///
/// Sur la VM (mobile natif, `flutter test`), c'est `http_transmit_client.dart`
/// qui est choisi — `web_transmit_client.dart` n'est **jamais compilé** hors
/// web, donc son import de `dart:js_interop` / `package:web` ne casse ni les
/// tests ni les builds natifs (exactement le patron du lecteur web #46).
library;

export 'http_transmit_client.dart'
    if (dart.library.js_interop) 'web_transmit_client.dart'
    show createTransmitClient;
