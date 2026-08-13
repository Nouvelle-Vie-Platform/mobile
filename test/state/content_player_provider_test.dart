import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/state/player_providers.dart';

void main() {
  group('contentPlayerProvider', () {
    test('rend un lecteur inerte par défaut', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Le défaut n'est pas « le lecteur des développeurs » : c'est le seul
      // qu'on puisse construire **sans canal de plugin**. La vraie
      // implémentation est injectée par le démarrage de l'application, chemin
      // que les tests ne prennent jamais.
      expect(container.read(contentPlayerProvider), isA<InertContentPlayer>());
    });

    test('n\'est pas autoDispose : le lecteur survit à la perte d\'auditeurs',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final subscription = container.listen(contentPlayerProvider, (_, __) {});
      final premier = container.read(contentPlayerProvider);
      subscription.close();
      await Future<void>.delayed(Duration.zero);

      // C'est le sens même de la lecture en arrière-plan : on quitte l'écran
      // (`context.pop()`), le son continue. Un lecteur `autoDispose` serait
      // détruit avec le dernier écran qui l'observait — et un **second**
      // `AudioPlayer` reconstruit derrière fait lever le service audio.
      expect(identical(container.read(contentPlayerProvider), premier), isTrue);
    });

    test('s\'écrase par un lecteur fourni par le test', () {
      final mien = InertContentPlayer();
      addTearDown(mien.dispose);
      final container = ProviderContainer(
        overrides: [contentPlayerProvider.overrideWithValue(mien)],
      );
      addTearDown(container.dispose);

      expect(identical(container.read(contentPlayerProvider), mien), isTrue);
    });
  });

  group('contentPlaybackProvider', () {
    test('publie la valeur du lecteur, et la suit', () async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final container = ProviderContainer(
        overrides: [contentPlayerProvider.overrideWithValue(player)],
      );
      addTearDown(container.dispose);

      expect(container.read(contentPlaybackProvider), const ContentPlayback());

      await player.load(contentId: 'c1', url: 'u', title: 't');
      expect(container.read(contentPlaybackProvider).contentId, 'c1');
    });

    test(
        'un select isole : la position ne reconstruit pas qui écoute la lecture',
        () {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final container = ProviderContainer(
        overrides: [contentPlayerProvider.overrideWithValue(player)],
      );
      addTearDown(container.dispose);

      var reveils = 0;
      container.listen(
        contentPlaybackProvider.select((playback) => playback.isPlaying),
        (_, __) => reveils++,
        fireImmediately: false,
      );

      // La position émet plusieurs fois par seconde. Sans cette isolation, tout
      // écran abonné se reconstruirait en continu pendant une écoute.
      player.emit(player.value.copyWith(position: const Duration(seconds: 1)));
      player.emit(player.value.copyWith(position: const Duration(seconds: 2)));
      player.emit(player.value.copyWith(position: const Duration(seconds: 3)));
      expect(reveils, 0);

      player.play();
      expect(reveils, 1);
    });

    test('se détache du lecteur quand la portée meurt', () {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      final container = ProviderContainer(
        overrides: [contentPlayerProvider.overrideWithValue(player)],
      );

      container.read(contentPlaybackProvider);
      container.dispose();

      // Un auditeur oublié sur un lecteur global tiendrait la portée en vie et
      // ferait lever `ValueNotifier` après son `dispose`.
      expect(() => player.play(), returnsNormally);
    });
  });
}
