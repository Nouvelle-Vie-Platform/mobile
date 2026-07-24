import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/players/status_player.dart';

/// Fournit l'implémentation courante du [StatusPlayer].
///
/// Même principe que `churchRepositoryProvider` : les écrans ne connaissent que
/// l'abstraction. Brancher la vraie lecture (`just_audio` pour l'audio,
/// `video_player` pour la vidéo) consistera à surcharger ce provider avec une
/// autre implémentation de [StatusPlayer] — **aucun écran n'a besoin de
/// changer**. Les tests, eux, injectent un [InertStatusPlayer] (sans minuterie)
/// pour rester déterministes.
final statusPlayerProvider = Provider<StatusPlayer>((ref) {
  final player = FakeStatusPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Coupure du son des statuts.
///
/// Mémorisée **pour la session seulement** (§1 de la spec) : rien n'est
/// persisté, relancer l'application repart avec le son actif.
class StatusMutedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Force un état précis.
  void set(bool muted) => state = muted;

  /// Bascule muet / non muet.
  void toggle() => state = !state;
}

/// État « muet » partagé par la visionneuse de statuts.
final statusMutedProvider = NotifierProvider<StatusMutedNotifier, bool>(
  StatusMutedNotifier.new,
);
