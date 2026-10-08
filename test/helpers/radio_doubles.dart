/// Doubles de **l'antenne de New Life Radio** (#104) et de sa **poignée de main**
/// (#108).
library;

import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_handshake.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';

/// **La route publique qui échoue**, pour les deux phrases d'échec.
///
/// Elle existe parce que la distinction réseau / antenne ne se prouve qu'en
/// faisant échouer l'écoute, et qu'un test ne peut pas débrancher le wifi de la
/// machine qui l'exécute. [error] est levée telle quelle — c'est
/// `classifyRadioFailure` qui en tire la phrase, et c'est elle qu'on éprouve.
class FailingRadioRepository implements RadioRepository {
  const FailingRadioRepository(this.error);

  final Object error;

  @override
  Future<RadioAntenna> antenna() async => throw error;

  @override
  Future<void> reportListening(String listenId) async {}
}

/// Une antenne de test : l'adresse est courte et visiblement factice, pour qu'un
/// test qui la relit sur le lecteur ne puisse pas la confondre avec l'adresse de
/// production.
const RadioAntenna kTestAntennaOnAir = RadioAntenna(
  streamUrl: 'https://antenne.test/antenne/index.m3u8',
  onAir: true,
);

/// La même adresse, annoncée **hors antenne** : ce qui doit éteindre le bouton
/// sans l'empêcher de lancer.
const RadioAntenna kTestAntennaSilent = RadioAntenna(
  streamUrl: 'https://antenne.test/antenne/index.m3u8',
  onAir: false,
);

/// **Un pré-vol qui note ce qu'on lui demande, et rend une session différente à
/// chaque appel** (#108).
///
/// Les deux moitiés comptent. [urls] prouve **quand** la négociation a lieu — avant
/// le `load`, et une fois par ouverture. Et la session **change à chaque appel** :
/// c'est ce qui rend visible la différence entre « renégocier » et « rejouer », et
/// sans quoi un test de réouverture passerait au vert sur un cookie mis en cache.
class RecordingRadioHandshake implements RadioHandshakeResolver {
  RecordingRadioHandshake();

  /// Les adresses pour lesquelles on a négocié, dans l'ordre.
  final List<String> urls = [];

  /// Combien de négociations ont eu lieu.
  int get count => urls.length;

  /// L'adresse finale rendue pour [url] — la redirection de MediaMTX, feinte à
  /// l'identique : son `Location` est **absolu et à la racine**, donc l'adresse de
  /// départ n'est pas celle qu'il faut ouvrir. Un test peut ainsi distinguer les
  /// deux, ce qu'une adresse inchangée ne permettrait pas.
  static String resolvedUrlFor(String url) =>
      Uri.parse(url).replace(path: '/antenne/stream.m3u8').toString();

  /// Le cookie rendu au n-ième appel (le premier porte `1`).
  static String sessionAt(int call) => 'hlsSession=session-$call';

  @override
  Future<RadioHandshake> resolve(String url) async {
    urls.add(url);
    return RadioHandshake(
      url: resolvedUrlFor(url),
      headers: {'Cookie': sessionAt(count)},
    );
  }
}

/// **Un pré-vol qui échoue**, pour que les deux phrases restent celles de #104.
///
/// [error] est levée telle quelle : c'est `classifyRadioFailure` qui en tire la
/// phrase, exactement comme pour la route d'antenne et pour le lecteur. Un pré-vol
/// qui composerait lui-même son message serait la troisième voix que le cadrage
/// interdit.
class FailingRadioHandshake implements RadioHandshakeResolver {
  const FailingRadioHandshake(this.error);

  final Object error;

  @override
  Future<RadioHandshake> resolve(String url) async => throw error;
}
