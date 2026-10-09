/// **L'économie de données et le battement, dans le contrôleur d'écoute**
/// (M2 du plan `server-portal/docs/radio-adaptative-plan.md`).
///
/// Un conteneur nu sur l'[InertContentPlayer], comme
/// `status_interruption_test.dart` : ce qu'on vérifie est l'URL que le lecteur a
/// reçue et les battements que la route a reçus. `test` et non `testWidgets` :
/// le réglage passe par le vrai flux Drift (base en mémoire), qui se figerait
/// sous l'horloge factice. La cadence de 60 s est vérifiée à part, sur
/// `RadioHeartbeat` seul (`test/data/radio_heartbeat_test.dart`).
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_handshake.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/data/radio/radio_status.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/measurement_providers.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_controller.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../helpers/playback_doubles.dart';

const _adaptive = 'https://antenne.test/antenne-hls/master.m3u8';
const _eco = 'https://antenne.test/antenne-hls/a32/index.m3u8';
const _title = 'New Life Radio';

/// Une route d'antenne qui note les battements reçus.
class _RecordingRadioRepository implements RadioRepository {
  _RecordingRadioRepository(this.value);

  final RadioAntenna value;
  final List<String> beats = [];

  @override
  Future<RadioAntenna> antenna() async => value;

  @override
  Future<void> reportListening(String listenId) async => beats.add(listenId);
}

typedef _Rig = ({
  ProviderContainer container,
  InertContentPlayer player,
  AppDatabase db,
  _RecordingRadioRepository radio,
});

Future<_Rig> _setUp({
  RadioAntenna antenna =
      const RadioAntenna(streamUrl: _adaptive, ecoStreamUrl: _eco),
  RadioQuality quality = RadioQuality.auto,
  RadioHandshakeResolver handshake = const DirectRadioHandshake(),
}) async {
  final player = InertContentPlayer();
  addTearDown(player.dispose);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (quality != RadioQuality.auto) {
    await db.settingsDao.setRadioQuality(quality);
  }
  final radio = _RecordingRadioRepository(antenna);
  final container = ProviderContainer(
    overrides: [
      contentPlayerProvider.overrideWithValue(player),
      appDatabaseProvider.overrideWithValue(db),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
      playReporterProvider.overrideWithValue(FakePlayReporter()),
      playSpoolProvider.overrideWithValue(FakePlaySpool()),
      mediathequeRepositoryProvider
          .overrideWithValue(InMemoryMediathequeRepository()),
      gatheringRepositoryProvider
          .overrideWithValue(InMemoryGatheringRepository()),
      radioRepositoryProvider.overrideWithValue(radio),
      radioHandshakeProvider.overrideWithValue(handshake),
      // Le vrai signal réseau ouvre un canal de plugin absent sous test.
      radioNetworkChangesProvider.overrideWithValue(const Stream.empty()),
    ],
  );
  addTearDown(container.dispose);
  // Le contrôleur naît et ouvre le réglage ; on attend que le flux réponde.
  // **Écouté, pas seulement lu** : Riverpod 3 met en pause un provider sans
  // auditeur, et avec lui le flux Drift des réglages — comme le bouton
  // d'antenne, qui l'observe, le fait dans l'application.
  container.listen(radioListeningProvider, (_, __) {});
  await _until(() => container.read(radioQualityProvider) == quality);
  return (container: container, player: player, db: db, radio: radio);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// **Attend une condition au lieu d'un délai fixe** : le premier flux Drift
/// d'une base en mémoire peut dépasser 20 ms sur une machine chargée.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'le flux des réglages n\'a pas répondu');
}

/// Pose le choix radio, et attend que le contrôleur l'ait vu passer.
Future<void> _setQuality(_Rig r, RadioQuality quality) async {
  await r.db.settingsDao.setRadioQuality(quality);
  await _until(() => r.container.read(radioQualityProvider) == quality);
  await _settle();
}

RadioListening _radio(ProviderContainer c) =>
    c.read(radioListeningProvider.notifier);

/// Le premier son : le lecteur dit qu'il joue pour de bon.
Future<void> _sound(InertContentPlayer player) async {
  player.emit(player.value.copyWith(hasStarted: true, isPlaying: true));
  await _settle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Le choix de l\'URL au démarrage', () {
    test('Automatique : l\'adaptative', () async {
      final r = await _setUp();
      await _radio(r.container).start(title: _title);
      expect(r.player.loadedUrl, _adaptive);
    });

    test('Économie avec URL économie : l\'URL économie', () async {
      final r = await _setUp(quality: RadioQuality.economy);
      await _radio(r.container).start(title: _title);
      expect(r.player.loadedUrl, _eco);
    });

    test('Économie sans URL économie : a32 dérivé du master (#184)',
        () async {
      final r = await _setUp(
        quality: RadioQuality.economy,
        antenna: const RadioAntenna(streamUrl: _adaptive),
      );
      await _radio(r.container).start(title: _title);
      expect(
        r.player.loadedUrl,
        'https://antenne.test/antenne-hls/a32.m3u8',
      );
    });

    test('Minimum et Haute : les paliers dérivés du master (#184)',
        () async {
      final minimum = await _setUp(quality: RadioQuality.minimum);
      await _radio(minimum.container).start(title: _title);
      expect(
        minimum.player.loadedUrl,
        'https://antenne.test/antenne-hls/a16.m3u8',
      );

      final high = await _setUp(quality: RadioQuality.high);
      await _radio(high.container).start(title: _title);
      expect(
        high.player.loadedUrl,
        'https://antenne.test/antenne-hls/a128.m3u8',
      );
    });
  });

  group('Changer le réglage pendant l\'écoute', () {
    test('relance l\'antenne sur la bonne URL, sans changer de séance',
        () async {
      final r = await _setUp();
      await _radio(r.container).start(title: _title);
      await _sound(r.player);
      expect(r.radio.beats, hasLength(1));
      final loads = r.player.loadCount;

      await _setQuality(r, RadioQuality.economy);

      expect(r.player.loadCount, loads + 1);
      expect(r.player.loadedUrl, _eco);
      expect(r.player.value.contentId, RadioConfig.contentId);

      await _sound(r.player);
      // Une relance n'est pas un nouveau démarrage par l'auditeur.
      expect(r.radio.beats, hasLength(1));
    });

    test('en pause, il vaut à la reprise : la source est rouverte, pas rejouée',
        () async {
      final r = await _setUp();
      await _radio(r.container).start(title: _title);
      await _sound(r.player);
      r.container.read(playbackControllerProvider.notifier).pause();
      await _settle();
      final loads = r.player.loadCount;

      await _setQuality(r, RadioQuality.economy);
      expect(r.player.loadCount, loads, reason: 'rien ne joue en pause');

      await _radio(r.container).start(title: _title);
      expect(r.player.loadCount, loads + 1);
      expect(r.player.loadedUrl, _eco);
    });

    test('en pause, la notification qui relance rouvre aussi', () async {
      final r = await _setUp(quality: RadioQuality.economy);
      await _radio(r.container).start(title: _title);
      await _sound(r.player);
      r.player.pause();
      await _settle();

      await _setQuality(r, RadioQuality.auto);
      r.player.play();
      await _settle();
      expect(r.player.loadedUrl, _adaptive);
    });

    test('pendant un essai en vol : l\'essai renonce, on rouvre au bon choix',
        () async {
      final handshake = _ManualHandshake();
      final r = await _setUp(handshake: handshake);
      unawaited(_radio(r.container).start(title: _title));
      await _settle();
      expect(handshake.pending, hasLength(1), reason: 'pré-vol en vol');

      await _setQuality(r, RadioQuality.economy);
      expect(handshake.pending, hasLength(2), reason: 'un essai neuf');
      handshake.pending[0].complete(const RadioHandshake(url: _adaptive));
      handshake.pending[1].complete(const RadioHandshake(url: _eco));
      await _settle();
      expect(handshake.urls, [_adaptive, _eco]);
      expect(r.player.loadCount, 1, reason: 'l\'essai périmé a renoncé');
      expect(r.player.loadedUrl, _eco);
      _radio(r.container).stop();
    });

    test('à l\'arrêt, ne fait rien', () async {
      final r = await _setUp();
      await _setQuality(r, RadioQuality.economy);
      expect(r.player.loadCount, 0);
    });
  });

  group('Le battement', () {
    test('rien tant que le son n\'est pas sorti, un battement dès qu\'il sort',
        () async {
      final r = await _setUp();
      await _radio(r.container).start(title: _title);
      await _settle();
      expect(r.container.read(radioListeningProvider), RadioStatus.connecting);
      expect(r.radio.beats, isEmpty);

      await _sound(r.player);
      expect(r.container.read(radioListeningProvider), RadioStatus.playing);
      expect(r.radio.beats, hasLength(1));
    });

    test('un listenId neuf à chaque démarrage par l\'auditeur', () async {
      final r = await _setUp();
      await _radio(r.container).start(title: _title);
      await _sound(r.player);

      // Arrêt, puis nouveau démarrage.
      _radio(r.container).stop();
      await _settle();
      await _radio(r.container).start(title: _title);
      await _sound(r.player);

      // Pause, puis reprise par l'auditeur.
      r.container.read(playbackControllerProvider.notifier).pause();
      await _settle();
      expect(r.container.read(radioListeningProvider), RadioStatus.idle);
      await _radio(r.container).start(title: _title);
      await _settle();

      expect(r.radio.beats, hasLength(3));
      expect(r.radio.beats.toSet(), hasLength(3));
    });

    test('un échec de lecture ne bat pas', () async {
      final r = await _setUp();
      await _radio(r.container).start(title: _title);
      await _sound(r.player);
      expect(r.radio.beats, hasLength(1));

      r.player.emit(r.player.value.copyWith(error: Exception('coupure')));
      await _settle();
      expect(r.container.read(radioListeningProvider).phase,
          isNot(RadioPhase.playing));
      expect(r.radio.beats, hasLength(1));
      _radio(r.container).stop();
    });
  });
}

/// Un pré-vol qu'on libère à la main, pour tenir un essai en vol.
class _ManualHandshake implements RadioHandshakeResolver {
  final List<Completer<RadioHandshake>> pending = [];
  final List<String> urls = [];

  @override
  Future<RadioHandshake> resolve(String url) {
    urls.add(url);
    final call = Completer<RadioHandshake>();
    pending.add(call);
    return call.future;
  }
}
