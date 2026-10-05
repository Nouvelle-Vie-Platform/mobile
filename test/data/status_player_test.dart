import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/status_player.dart';
import 'package:maison_du_miracle/state/player_providers.dart';

/// Les tests utilisent `testWidgets` : son horloge est simulée (`FakeAsync`),
/// donc `tester.pump(duration)` fait réellement avancer les `Timer.periodic`
/// du lecteur, sans attente réelle.
void main() {
  group('StatusPlayback', () {
    test('progress vaut 0 quand la durée est nulle', () {
      const playback = StatusPlayback(position: Duration(seconds: 3));
      expect(playback.progress, 0);
    });

    test('progress est borné à 1', () {
      const playback = StatusPlayback(
        position: Duration(seconds: 9),
        duration: Duration(seconds: 3),
      );
      expect(playback.progress, 1);
    });

    test('copyWith ne modifie que les champs fournis', () {
      const playback = StatusPlayback(
        statusId: 'a1',
        position: Duration(seconds: 1),
        duration: Duration(seconds: 5),
      );
      final updated = playback.copyWith(isPlaying: true);
      expect(updated.statusId, 'a1');
      expect(updated.position, const Duration(seconds: 1));
      expect(updated.duration, const Duration(seconds: 5));
      expect(updated.isPlaying, isTrue);
    });
  });

  group('FakeStatusPlayer', () {
    testWidgets('progresse et notifie ses auditeurs', (tester) async {
      final player = FakeStatusPlayer();
      var notifications = 0;
      player.addListener(() => notifications++);

      player.load(statusId: 'a1', fallbackDuration: const Duration(seconds: 1));
      expect(player.value.statusId, 'a1');
      expect(player.value.duration, const Duration(seconds: 1));
      expect(player.value.position, Duration.zero);

      player.play();
      expect(player.value.isPlaying, isTrue);

      await tester.pump(const Duration(milliseconds: 500));

      expect(player.value.position, const Duration(milliseconds: 500));
      expect(player.value.progress, closeTo(0.5, 0.001));
      expect(player.value.isPlaying, isTrue);
      expect(player.value.isCompleted, isFalse);
      expect(notifications, greaterThan(5));

      player.dispose();
    });

    testWidgets('s\'arrête pile à la durée et annule sa minuterie', (
      tester,
    ) async {
      final player = FakeStatusPlayer();
      player.load(
        statusId: 'a1',
        fallbackDuration: const Duration(milliseconds: 200),
      );
      player.play();

      await tester.pump(const Duration(milliseconds: 200));

      expect(player.value.position, const Duration(milliseconds: 200));
      expect(player.value.isPlaying, isFalse);
      expect(player.value.isCompleted, isTrue);
      expect(player.value.progress, 1);
      // Aucune minuterie en vol : sans cela le test échouerait au démontage sur
      // « pending timer ».
      expect(player.hasPendingTimer, isFalse);

      var notifications = 0;
      player.addListener(() => notifications++);
      await tester.pump(const Duration(seconds: 5));
      expect(player.value.position, const Duration(milliseconds: 200));
      expect(notifications, 0);

      player.dispose();
    });

    testWidgets('pause fige la position', (tester) async {
      final player = FakeStatusPlayer();
      player.load(statusId: 'a1', fallbackDuration: const Duration(seconds: 2));
      player.play();

      await tester.pump(const Duration(milliseconds: 300));
      player.pause();
      final frozen = player.value.position;
      expect(player.value.isPlaying, isFalse);
      expect(player.hasPendingTimer, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(player.value.position, frozen);

      // La reprise repart de la position figée.
      player.play();
      await tester.pump(const Duration(milliseconds: 100));
      expect(player.value.position, frozen + const Duration(milliseconds: 100));

      player.dispose();
    });

    testWidgets('load d\'un autre statut réinitialise tout', (tester) async {
      final player = FakeStatusPlayer();
      player.load(
        statusId: 'a1',
        fallbackDuration: const Duration(milliseconds: 200),
      );
      player.play();
      await tester.pump(const Duration(milliseconds: 200));
      expect(player.value.isCompleted, isTrue);

      player.load(statusId: 'a2', fallbackDuration: const Duration(seconds: 3));
      expect(player.value.statusId, 'a2');
      expect(player.value.position, Duration.zero);
      expect(player.value.duration, const Duration(seconds: 3));
      expect(player.value.isPlaying, isFalse);
      expect(player.value.isCompleted, isFalse);
      expect(player.value.progress, 0);
      expect(player.hasPendingTimer, isFalse);

      player.dispose();
    });

    testWidgets('seek borne la position et dispose est idempotent', (
      tester,
    ) async {
      final player = FakeStatusPlayer();
      player.load(statusId: 'a1', fallbackDuration: const Duration(seconds: 2));

      player.seek(const Duration(seconds: -5));
      expect(player.value.position, Duration.zero);

      player.seek(const Duration(seconds: 1));
      expect(player.value.position, const Duration(seconds: 1));

      player.seek(const Duration(seconds: 9));
      expect(player.value.position, const Duration(seconds: 2));
      expect(player.value.isCompleted, isTrue);

      player.dispose();
      player.dispose();
    });

    testWidgets('l\'état muet est retenu par le lecteur', (tester) async {
      final player = FakeStatusPlayer();
      expect(player.isMuted, isFalse);
      player.setMuted(true);
      expect(player.isMuted, isTrue);
      player.dispose();
    });
  });

  group('InertStatusPlayer', () {
    testWidgets('n\'avance jamais, même après un long pump', (tester) async {
      final player = InertStatusPlayer();
      player.load(statusId: 'a1', fallbackDuration: const Duration(seconds: 5));
      player.play();

      expect(player.value.isPlaying, isTrue);

      await tester.pump(const Duration(minutes: 10));

      expect(player.value.position, Duration.zero);
      expect(player.value.progress, 0);
      expect(player.value.isCompleted, isFalse);
      expect(player.value.isPlaying, isTrue);

      player.dispose();
    });
  });

  group('Providers', () {
    test('statusPlayerProvider fournit un lecteur remplaçable', () {
      final container = ProviderContainer.test();
      expect(container.read(statusPlayerProvider), isA<FakeStatusPlayer>());

      final inert = InertStatusPlayer();
      final overridden = ProviderContainer.test(
        overrides: [statusPlayerProvider.overrideWithValue(inert)],
      );
      expect(overridden.read(statusPlayerProvider), same(inert));
      inert.dispose();
    });

    test('statusMutedProvider bascule et démarre non muet', () {
      final container = ProviderContainer.test();
      expect(container.read(statusMutedProvider), isFalse);

      container.read(statusMutedProvider.notifier).toggle();
      expect(container.read(statusMutedProvider), isTrue);

      container.read(statusMutedProvider.notifier).set(false);
      expect(container.read(statusMutedProvider), isFalse);
    });
  });

  group('La durée effective — réelle, puis annoncée, puis par défaut', () {
    test('la durée réelle du lecteur prime sur celle du transcodeur', () {
      expect(
        effectiveStatusDuration(
          real: const Duration(seconds: 41, milliseconds: 870),
          announcedMs: 42000,
          hasMedia: true,
        ),
        const Duration(seconds: 41, milliseconds: 870),
      );
    });

    test('sans durée réelle, celle mesurée par le transcodeur', () {
      expect(
        effectiveStatusDuration(announcedMs: 42000, hasMedia: true),
        const Duration(seconds: 42),
      );
    });

    test('sans rien, 30 s pour un média', () {
      expect(effectiveStatusDuration(hasMedia: true), StatusDurations.media);
      expect(StatusDurations.media, const Duration(seconds: 30));
    });

    test('sans rien, 5 s pour un texte ou une image', () {
      expect(effectiveStatusDuration(hasMedia: false), StatusDurations.still);
      expect(StatusDurations.still, const Duration(seconds: 5));
    });

    test('une durée nulle ne compte pour aucun maillon', () {
      // Elle finirait le statut à la seconde où il commence.
      expect(
        effectiveStatusDuration(
          real: Duration.zero,
          announcedMs: 0,
          hasMedia: true,
        ),
        StatusDurations.media,
      );
    });
  });

  group('Le contrat du média', () {
    test('load retient ce que l\'URL désigne', () {
      final player = InertStatusPlayer();
      addTearDown(player.dispose);

      player.load(
        statusId: 'v',
        mediaUrl: 'https://media.example.test/v/master.m3u8',
        mediaKind: StatusMediaKind.video,
        fallbackDuration: StatusDurations.media,
      );

      expect(player.mediaUrl, 'https://media.example.test/v/master.m3u8');
      expect(player.mediaKind, StatusMediaKind.video);
      // Rien n'est décodé : ni image, ni dimensions, ni surface.
      expect(player.value.hasVideoFrame, isFalse);
      expect(player.value.videoSize, isNull);
      expect(player.videoSurface(), isNull);
    });

    test('un chargement efface l\'image et les dimensions du précédent', () {
      final player = InertStatusPlayer();
      addTearDown(player.dispose);
      player.emit(const StatusPlayback(
        statusId: 'v',
        hasVideoFrame: true,
        videoSize: Size(1920, 1080),
      ));

      player.load(statusId: 't', fallbackDuration: StatusDurations.still);

      expect(player.value.hasVideoFrame, isFalse);
      expect(player.value.videoSize, isNull);
    });

    test('l\'égalité porte aussi l\'image et les dimensions', () {
      const a = StatusPlayback(statusId: 'v', videoSize: Size(1, 2));
      expect(a, const StatusPlayback(statusId: 'v', videoSize: Size(1, 2)));
      expect(a == a.copyWith(hasVideoFrame: true), isFalse);
    });
  });
}
