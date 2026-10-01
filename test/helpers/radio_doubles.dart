/// Doubles de **l'antenne de New Life Radio** (#104).
library;

import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
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
