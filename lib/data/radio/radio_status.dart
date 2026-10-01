/// **Ce que le bouton d'antenne a à dire**, en une valeur immuable.
///
/// Cinq états, et ils viennent du tableau d'apparence du cadrage — pas d'une
/// envie de symétrie :
///
/// | état | apparence |
/// | --- | --- |
/// | hors antenne | éteint, « Hors antenne » — **mais appuyable quand même** |
/// | au repos | « Suivre New Life Radio » |
/// | en connexion | animation continue |
/// | en lecture | couleur changée, « New Life Radio » |
/// | en reprise | animation, et le bouton dit qu'il réessaie |
///
/// ⚠️ **« Hors antenne » n'est pas un état de ce type-ci**, et c'est délibéré :
/// il ne décrit pas ce que l'application *fait*, mais ce que la route publique a
/// *dit* (`RadioAntenna.isSilent`). Les deux se superposent à l'écran — on peut
/// être en connexion sur une antenne annoncée muette, parce qu'elle a pu reprendre
/// sans qu'on le sache —, et les mélanger dans un seul enum obligerait à choisir
/// entre les deux là où le bouton doit montrer les deux.
library;

import 'package:flutter/foundation.dart';

import 'radio_failure.dart';

enum RadioPhase {
  /// Le lecteur ne tient pas la radio, ou ne la joue plus.
  idle,

  /// **La connexion initiale est en cours** — et c'est le seul état inerte : on
  /// ne peut ni relancer ni arrêter tant que ça cherche, parce que c'est
  /// exactement ce qui casse une connexion en cours.
  connecting,

  /// Le son est sorti au moins une fois, et il sort.
  playing,

  /// Un échec a eu lieu, les tentatives espacées sont en cours.
  retrying,

  /// Deux minutes (ou six tentatives) sans succès : le bouton s'éteint et dit
  /// pourquoi.
  failed,
}

@immutable
class RadioStatus {
  const RadioStatus(this.phase) : failure = null;

  const RadioStatus.failed(this.failure) : phase = RadioPhase.failed;

  static const RadioStatus idle = RadioStatus(RadioPhase.idle);
  static const RadioStatus connecting = RadioStatus(RadioPhase.connecting);
  static const RadioStatus playing = RadioStatus(RadioPhase.playing);
  static const RadioStatus retrying = RadioStatus(RadioPhase.retrying);

  final RadioPhase phase;

  /// La cause, **et seulement quand on a renoncé** : c'est le seul moment où une
  /// phrase d'échec a sa place sur le bouton. Pendant les tentatives, le bouton
  /// dit qu'il réessaie — nommer la panne pendant qu'on la combat ferait
  /// renoncer l'auditeur avant l'application.
  final RadioFailureKind? failure;

  /// **Quelque chose tourne** — on cherche, on joue, ou on réessaie.
  ///
  /// La connexion en fait partie, et ce n'est pas une subtilité : c'est ce qui
  /// rend [allowsTransport] nécessaire plutôt que décoratif. Sans elle, un appui
  /// pendant la connexion **arrêterait** — exactement ce que le cadrage interdit.
  bool get isOn =>
      phase == RadioPhase.connecting ||
      phase == RadioPhase.playing ||
      phase == RadioPhase.retrying;

  /// Vrai quand le bouton accepte de lancer ou d'arrêter.
  ///
  /// **L'inertie protège la connexion, pas la navigation** : seule la connexion
  /// *initiale* la pose — une antenne déjà entendue s'arrête toujours, y compris
  /// pendant qu'elle regarnit son tampon —, et ouvrir la page reste possible dans
  /// tous les cas (c'est l'appelant du geste qui le sait, pas cette valeur).
  bool get allowsTransport => phase != RadioPhase.connecting;

  /// Vrai quand il y a un arrêt à **offrir**.
  ///
  /// Les deux conditions, et pas une : il faut quelque chose à arrêter, et le
  /// droit de le faire. Pendant la connexion le bouton d'arrêt n'est donc pas
  /// grisé — il n'est **pas là**, pour la raison du sélecteur de canaux (#83) :
  /// une commande offerte qui ne répond pas est une promesse que personne ne
  /// tient.
  bool get offersStop => isOn && allowsTransport;

  /// Vrai quand le bouton doit montrer qu'il travaille.
  bool get isWorking =>
      phase == RadioPhase.connecting || phase == RadioPhase.retrying;

  @override
  bool operator ==(Object other) =>
      other is RadioStatus && other.phase == phase && other.failure == failure;

  @override
  int get hashCode => Object.hash(phase, failure);

  @override
  String toString() =>
      'RadioStatus($phase${failure == null ? '' : ', $failure'})';
}
