import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/players/content_player.dart';
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

/// **Le lecteur de la médiathèque — un seul, global, jamais `autoDispose`.**
///
/// Deux raisons, et aucune n'est une préférence :
///
/// 1. **la lecture doit survivre au `context.pop()`.** C'est le sens même de
///    l'écoute en arrière-plan : on quitte l'écran du prêche, le son continue,
///    la notification reste. Un lecteur `autoDispose` mourrait avec le dernier
///    écran qui l'observe ;
/// 2. **un second `AudioPlayer` fait lever le service audio.** Un provider
///    reconstruit à la demande en créerait un par cycle.
///
/// La valeur par défaut est l'[InertContentPlayer] : le **seul** lecteur qu'on
/// puisse construire sans canal de plugin, donc le seul qui tienne sous
/// `flutter test`. Ce n'est pas un bouchon de confort — c'est ce qui garantit
/// qu'aucun test ne rencontre jamais de `MissingPluginException`.
///
/// La vraie implémentation ([JustAudioContentPlayer]) est injectée par
/// `main.dart`, après `AudioService.init()` : **le chemin de démarrage, celui
/// que les tests ne prennent jamais.** Oublier cet écrasement rend
/// l'application silencieuse, pas cassée — d'où la place de cette phrase.
final contentPlayerProvider = Provider<ContentPlayer>((ref) {
  final player = InertContentPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Republie la valeur du [contentPlayerProvider] pour qu'elle soit
/// **`select`ionnable**.
///
/// Sans ce relais, un écran ne pourrait qu'écouter le lecteur en bloc. Or la
/// position émet **plusieurs fois par seconde** : un bouton lecture/pause
/// abonné à la valeur entière se reconstruirait à chaque battement, pendant
/// toute une écoute. Avec lui,
/// `ref.watch(contentPlaybackProvider.select((p) => p.isPlaying))` ne réveille
/// son écouteur que quand ce champ-là change.
class ContentPlaybackNotifier extends Notifier<ContentPlayback> {
  @override
  ContentPlayback build() {
    final player = ref.watch(contentPlayerProvider);
    void onChanged() => state = player.value;
    player.addListener(onChanged);
    // Le lecteur, lui, survit à la portée : l'auditeur, non. Sans ce retrait,
    // le lecteur global garderait une référence vers un état mort et lèverait
    // à la première émission suivante.
    ref.onDispose(() => player.removeListener(onChanged));
    return player.value;
  }
}

/// L'état de lecture courant, champ par champ.
final contentPlaybackProvider =
    NotifierProvider<ContentPlaybackNotifier, ContentPlayback>(
  ContentPlaybackNotifier.new,
);
