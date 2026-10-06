/// **L'enregistrement d'un vocal** (M4, #143 — reprend #98), sans micro : le
/// double de l'enregistreur pousse les niveaux, une horloge factice fait
/// passer le temps.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/messaging/media/voice_recorder.dart';
import 'package:maison_du_miracle/data/messaging/media/voice_recording_controller.dart';

void main() {
  late FakeVoiceRecorder recorder;
  late DateTime now;
  late VoiceRecordingController controller;

  setUp(() {
    recorder = FakeVoiceRecorder();
    now = DateTime.utc(2026, 10, 6, 10);
    controller = VoiceRecordingController(
      recorder: recorder,
      newPath: () async => '/outbox/voice.m4a',
      clock: () => now,
    );
  });

  tearDown(() => controller.dispose());

  test('la permission refusée : rien ne démarre', () async {
    recorder.granted = false;
    expect(await controller.begin(), isFalse);
    expect(controller.isActive, isFalse);
    expect(recorder.started, isEmpty);
  });

  test('commencer, recevoir des niveaux, terminer : le vocal et sa forme',
      () async {
    expect(await controller.begin(), isTrue);
    expect(controller.phase, VoiceRecordingPhase.recording);
    expect(recorder.recordingTo, '/outbox/voice.m4a');

    for (final level in [0.1, 0.9, 0.5]) {
      now = now.add(const Duration(seconds: 1));
      recorder.emit(level);
      await Future<void>.delayed(Duration.zero);
    }
    expect(controller.elapsed, const Duration(seconds: 3));

    final voice = await controller.finish();
    expect(voice, isNotNull);
    expect(voice!.path, '/outbox/voice.m4a');
    expect(voice.duration, const Duration(seconds: 3));
    expect(voice.waveform, [10, 90, 50]);
    expect(controller.isActive, isFalse);
  });

  test('glisser pour annuler : le fichier est jeté, rien ne part', () async {
    await controller.begin();
    now = now.add(const Duration(seconds: 4));
    await controller.cancel();

    expect(recorder.cancels, 1);
    expect(recorder.stops, 0);
    expect(controller.isActive, isFalse);
    expect(await controller.finish(), isNull);
  });

  test('verrouiller : mains libres, puis envoyer', () async {
    await controller.begin();
    controller.lock();
    expect(controller.phase, VoiceRecordingPhase.locked);

    now = now.add(const Duration(seconds: 5));
    final voice = await controller.finish();
    expect(voice!.duration, const Duration(seconds: 5));
  });

  test('un appui trop bref n’est pas un vocal', () async {
    await controller.begin();
    now = now.add(const Duration(milliseconds: 400));
    expect(await controller.finish(), isNull);
  });

  test('le plafond arrête l’enregistrement de lui-même, et le vocal part',
      () async {
    final short = VoiceRecordingController(
      recorder: recorder,
      newPath: () async => '/outbox/long.m4a',
      clock: () => now,
      maxSeconds: 10,
    );
    addTearDown(short.dispose);
    RecordedVoice? sent;
    short.onAutoStop = (voice) => sent = voice;

    await short.begin();
    now = now.add(const Duration(seconds: 10));
    recorder.emit(0.4);
    await pumpEventQueue();

    expect(short.isActive, isFalse);
    expect(sent, isNotNull);
    expect(sent!.duration, const Duration(seconds: 10));
  });

  test('waveformOf ramène à 48 barres au plus, en 0..100', () {
    final bars = waveformOf(List<double>.generate(500, (i) => (i % 10) / 10));
    expect(bars, hasLength(kVoiceWaveformBars));
    expect(bars.every((b) => b >= 0 && b <= 100), isTrue);
    expect(waveformOf(const []), isEmpty);
  });
}
