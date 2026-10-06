/// **Un vocal à la fois** (M4, #143 — reprend #98) : démarrer un second
/// arrête le premier ; la vitesse tourne 1× → 1,5× → 2×.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/chat_audio_player.dart';

void main() {
  late FakeChatAudioEngine engine;
  late ChatAudioController controller;

  setUp(() {
    engine = FakeChatAudioEngine();
    controller = ChatAudioController(engine);
  });

  tearDown(() => controller.dispose());

  test('lire un vocal le charge et le joue', () async {
    await controller.toggle('m-1', resolveUrl: () async => 'https://a');

    expect(controller.value.activeId, 'm-1');
    expect(controller.value.playing, isTrue);
    expect(controller.value.duration, const Duration(seconds: 12));
    expect(engine.calls, ['load https://a', 'speed 1.0', 'play']);
  });

  test('un second vocal arrête le premier', () async {
    await controller.toggle('m-1', resolveUrl: () async => 'https://a');
    await controller.toggle('m-2', resolveUrl: () async => 'https://b');

    expect(controller.value.activeId, 'm-2');
    expect(controller.value.playing, isTrue);
    expect(
      engine.calls,
      [
        'load https://a', 'speed 1.0', 'play', //
        'stop', //
        'load https://b', 'speed 1.0', 'play',
      ],
    );
  });

  test('retoucher le même vocal le met en pause, puis le reprend', () async {
    await controller.toggle('m-1', resolveUrl: () async => 'https://a');
    await controller.toggle('m-1', resolveUrl: () async => 'https://a');
    expect(controller.value.playing, isFalse);
    await controller.toggle('m-1', resolveUrl: () async => 'https://a');
    expect(controller.value.playing, isTrue);
    expect(engine.calls.where((c) => c.startsWith('load')), hasLength(1));
  });

  test('la vitesse : 1× → 1,5× → 2× → 1×', () async {
    await controller.toggle('m-1', resolveUrl: () async => 'https://a');
    await controller.cycleSpeed();
    expect(controller.value.speed, 1.5);
    await controller.cycleSpeed();
    expect(controller.value.speed, 2.0);
    await controller.cycleSpeed();
    expect(controller.value.speed, 1.0);
  });

  test('une URL introuvable : l’échec se dit, rien ne joue', () async {
    await controller.toggle('m-1', resolveUrl: () async => null);
    expect(controller.value.failed, isTrue);
    expect(controller.value.playing, isFalse);
    expect(engine.calls, isEmpty);
  });

  test('la progression suit le moteur ; la fin remet au début', () async {
    await controller.toggle('m-1', resolveUrl: () async => 'https://a');
    engine.emitPosition(const Duration(seconds: 6));
    await Future<void>.delayed(Duration.zero);
    expect(controller.value.position, const Duration(seconds: 6));

    engine.complete();
    await Future<void>.delayed(Duration.zero);
    expect(controller.value.playing, isFalse);
    expect(controller.value.position, Duration.zero);
  });

  test('sauter dans le vocal en cours seulement', () async {
    await controller.toggle('m-1', resolveUrl: () async => 'https://a');
    await controller.seekTo('m-2', 0.5);
    expect(engine.calls.where((c) => c.startsWith('seek')), isEmpty);
    await controller.seekTo('m-1', 0.5);
    expect(engine.calls.last, 'seek 6000');
  });
}
