/// **La sonde du lecteur web** — le seul moyen de prouver que `HlsContentPlayer`
/// joue vraiment.
///
/// `flutter test` tourne sur la VM : il ne compile même pas ce fichier, ni
/// `hls_content_player.dart`. Toute la logique testable a donc été poussée dans
/// `MediaElementPlayback` (voir `test/data/media_element_playback_test.dart`),
/// et il reste ceci, qui ne se vérifie que dans un navigateur : que `hls.js` se
/// charge, que les événements du DOM arrivent, et qu'un `.m3u8` avance.
///
/// Ce n'est **pas** un test : il exige Chrome et le réseau, et il ne tourne ni
/// sous `flutter test` ni en CI. C'est un point d'entrée web alternatif, lancé
/// par `make hls-probe`, qui pilote le lecteur contre un flux HLS public et
/// renvoie au terminal ce qu'il a observé. À relancer après toute montée de
/// version de `hls.js`.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:maison_du_miracle/data/players/hls_content_player.dart';
import 'package:web/web.dart' as web;

/// Flux de démonstration d'Apple : public, stable, et surtout **du vrai HLS
/// segmenté** — c'est exactement ce que `<audio src>` seul ne sait pas lire.
const _stream = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/'
    'bipbop_16x9/bipbop_16x9_variant.m3u8';

Future<void> main() async {
  final observed = <String>[];

  try {
    final player = HlsContentPlayer();
    var emissions = 0;
    player.addListener(() => emissions++);

    observed.add('valeur initiale       : ${player.value}');
    await player.load(contentId: 'sonde', url: _stream, title: 'Sonde');
    observed.add('après load            : ${player.value}');

    player.play();
    await Future<void>.delayed(const Duration(seconds: 8));
    observed.add('après 8 s de lecture  : ${player.value}');
    observed.add('émissions             : $emissions');

    player.seek(const Duration(minutes: 5));
    await Future<void>.delayed(const Duration(seconds: 3));
    observed.add('après seek(5 min)     : ${player.value}');

    player.pause();
    await Future<void>.delayed(const Duration(seconds: 1));
    observed.add('après pause           : ${player.value}');

    // La borne haute : « +30 s » ne doit jamais dépasser la fin du média.
    player.seek(const Duration(hours: 9));
    observed.add('après seek(9 h)       : ${player.value.position}');

    player.stop();
    await Future<void>.delayed(const Duration(seconds: 1));
    observed.add('après stop            : ${player.value}');

    player.dispose();
    observed.add('dispose               : sans exception');
  } catch (error, stackTrace) {
    observed.add('EXCEPTION $error\n$stackTrace');
  }

  // Le résultat repart vers le petit serveur de `tool/hls_probe.sh`, qui
  // l'imprime : un navigateur sans tête n'a pas de sortie standard.
  await web.window
      .fetch(
        '/resultat'.toJS,
        web.RequestInit(method: 'POST', body: observed.join('\n').toJS),
      )
      .toDart;
}
