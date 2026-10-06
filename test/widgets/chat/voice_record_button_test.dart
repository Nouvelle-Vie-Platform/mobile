/// **Le geste du micro** (M4, #143 — reprend #98), avec le double du micro :
/// appui maintenu pour enregistrer, relâcher pour envoyer, glisser à gauche
/// pour annuler, glisser vers le haut pour verrouiller.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/messaging/media/voice_recorder.dart';
import 'package:maison_du_miracle/data/messaging/media/voice_recording_controller.dart';
import 'package:maison_du_miracle/l10n/app_localizations.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/chat/media/voice_record_button.dart';

void main() {
  late FakeVoiceRecorder recorder;
  late VoiceRecordingController controller;
  late DateTime now;
  late List<RecordedVoice> recorded;
  late int denied;
  late int tooShort;

  setUp(() {
    recorder = FakeVoiceRecorder();
    now = DateTime.utc(2026, 10, 6, 10);
    controller = VoiceRecordingController(
      recorder: recorder,
      newPath: () async => '/outbox/voice.m4a',
      clock: () => now,
    );
    recorded = [];
    denied = 0;
    tooShort = 0;
  });

  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Expanded(child: VoiceRecordingStrip(controller: controller)),
                  VoiceRecordButton(
                    controller: controller,
                    onRecorded: recorded.add,
                    onDenied: () => denied++,
                    onTooShort: () => tooShort++,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pose le doigt et le garde : l'appui long se déclare après son délai.
  Future<TestGesture> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('m4_voice_button'))),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump();
    return gesture;
  }

  testWidgets('appui maintenu : on enregistre ; relâcher envoie le vocal',
      (tester) async {
    await pump(tester);
    final gesture = await hold(tester);

    expect(controller.phase, VoiceRecordingPhase.recording);
    expect(recorder.started, ['/outbox/voice.m4a']);

    now = now.add(const Duration(seconds: 3));
    recorder.emit(0.6);
    await tester.pump();
    expect(find.text('0:03'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(recorded, hasLength(1));
    expect(recorded.single.path, '/outbox/voice.m4a');
    expect(recorded.single.duration, const Duration(seconds: 3));
    expect(recorded.single.waveform, [60]);
    expect(recorder.stops, 1);
  });

  testWidgets('glisser à gauche annule : rien ne part', (tester) async {
    await pump(tester);
    final gesture = await hold(tester);
    now = now.add(const Duration(seconds: 2));

    await gesture.moveBy(const Offset(-(kVoiceCancelDistance + 20), 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(recorder.cancels, 1);
    expect(recorded, isEmpty);
    expect(controller.isActive, isFalse);
  });

  testWidgets('glisser vers le haut verrouille ; le bouton envoie ensuite',
      (tester) async {
    await pump(tester);
    final gesture = await hold(tester);

    await gesture.moveBy(const Offset(0, -(kVoiceLockDistance + 20)));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // Verrouillé : le doigt levé n'a rien envoyé, l'enregistrement continue.
    expect(controller.phase, VoiceRecordingPhase.locked);
    expect(recorded, isEmpty);
    expect(find.byKey(const Key('m4_voice_discard')), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);

    now = now.add(const Duration(seconds: 7));
    await tester.tap(find.byKey(const Key('m4_voice_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(recorded.single.duration, const Duration(seconds: 7));
  });

  testWidgets('verrouillé, la corbeille jette le vocal', (tester) async {
    await pump(tester);
    final gesture = await hold(tester);
    await gesture.moveBy(const Offset(0, -(kVoiceLockDistance + 20)));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    await tester.tap(find.byKey(const Key('m4_voice_discard')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(recorder.cancels, 1);
    expect(recorded, isEmpty);
  });

  testWidgets('micro refusé : on le dit, rien ne démarre', (tester) async {
    recorder.granted = false;
    await pump(tester);
    final gesture = await hold(tester);
    await gesture.up();
    await tester.pump();

    expect(denied, 1);
    expect(recorder.started, isEmpty);
  });

  testWidgets('un appui bref dit le geste, sans rien enregistrer',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('m4_voice_button')));
    await tester.pump();

    expect(tooShort, 1);
    expect(recorder.started, isEmpty);
  });
}
