/// **Ce que le bouton d'antenne a à dire**, en une valeur immuable.
///
/// Cinq états, et ils viennent des tableaux d'apparence des cadrages (#104,
/// #179) — pas d'une envie de symétrie :
///
/// | état | apparence |
/// | --- | --- |
/// | hors antenne | éteint, « Hors antenne » — **mais appuyable quand même** |
/// | au repos | « Suivre New Life Radio » |
/// | en connexion | animation continue |
/// | en lecture | couleur changée, « New Life Radio » |
/// | connexion instable | animation, « Connexion instable… » |
/// | en reprise | animation, « Reconnexion… » — sans fin, sans abandon |
///
/// ⚠️ **« Hors antenne » n'est pas un état de ce type-ci**, et c'est délibéré :
/// il ne décrit pas ce que l'application *fait*, mais ce que la route publique a
/// *dit* (`RadioAntenna.isSilent`). Les deux se superposent à l'écran — on peut
/// être en connexion sur une antenne annoncée muette, parce qu'elle a pu reprendre
/// sans qu'on le sache —, et les mélanger dans un seul enum obligerait à choisir
/// entre les deux là où le bouton doit montrer les deux.
library;

import 'package:flutter/foundation.dart';

enum RadioPhase {
  /// Le lecteur ne tient pas la radio, ou ne la joue plus.
  idle,

  /// **La connexion initiale est en cours** — et c'est le seul état inerte : on
  /// ne peut ni relancer ni arrêter tant que ça cherche, parce que c'est
  /// exactement ce qui casse une connexion en cours.
  connecting,

  /// Le son est sorti au moins une fois, et il sort.
  playing,

  /// **« Connexion instable… »** (#179) : l'antenne devrait jouer, et le tampon
  /// attend depuis au moins deux secondes. On n'a encore rien relancé — l'ABR a
  /// peut-être de quoi descendre de palier.
  unstable,

  /// **« Reconnexion… »** : une relance est en cours ou programmée, au bord du
  /// direct, et elle se répète **sans fin** tant que l'auditeur n'arrête pas.
  retrying,
}

@immutable
class RadioStatus {
  const RadioStatus(this.phase);

  static const RadioStatus idle = RadioStatus(RadioPhase.idle);
  static const RadioStatus connecting = RadioStatus(RadioPhase.connecting);
  static const RadioStatus playing = RadioStatus(RadioPhase.playing);
  static const RadioStatus unstable = RadioStatus(RadioPhase.unstable);
  static const RadioStatus retrying = RadioStatus(RadioPhase.retrying);

  final RadioPhase phase;

  /// **Quelque chose tourne** — on cherche, on joue, on vacille ou on réessaie.
  ///
  /// La connexion en fait partie, et ce n'est pas une subtilité : c'est ce qui
  /// rend [allowsTransport] nécessaire plutôt que décoratif. Sans elle, un appui
  /// pendant la connexion **arrêterait** — exactement ce que le cadrage interdit.
  bool get isOn => phase != RadioPhase.idle;

  /// Vrai quand le bouton accepte de lancer ou d'arrêter.
  ///
  /// **L'inertie protège la connexion, pas la navigation** : seule la connexion
  /// *initiale* la pose — une antenne déjà entendue s'arrête toujours, y compris
  /// pendant qu'elle vacille ou se reconnecte —, et ouvrir la page reste
  /// possible dans tous les cas (c'est l'appelant du geste qui le sait, pas
  /// cette valeur).
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
      phase == RadioPhase.connecting ||
      phase == RadioPhase.unstable ||
      phase == RadioPhase.retrying;

  @override
  bool operator ==(Object other) =>
      other is RadioStatus && other.phase == phase;

  @override
  int get hashCode => phase.hashCode;

  @override
  String toString() => 'RadioStatus($phase)';
}
