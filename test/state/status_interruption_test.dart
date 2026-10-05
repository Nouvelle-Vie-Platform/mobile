/// **Un statut à son tait le lecteur principal, et la sortie le fait reprendre**
/// (#130, décision du 05/10/2026).
///
/// La règle vit dans le contrôleur global — pas de second contrôleur — et se
/// vérifie ici sur l'[InertContentPlayer] : ce que le lecteur a reçu, jamais la
/// façon dont on le lui a transmis. La radio reprend **au direct** (la source
/// est rouverte, pré-vol compris), un enseignement **à sa position** (un simple
/// `play()` après la pause).
///
/// Le conteneur porte un magasin en mémoire et des rapporteurs muets, comme
/// `playback_controller_test.dart` : charger un enseignement ouvre un suivi
/// d'écoute.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/radio/radio_handshake.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/measurement_providers.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/playback_controller.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../helpers/playback_doubles.dart';
import '../helpers/radio_doubles.dart';

const _sermon = ContentRequest(
  contentId: 't-1',
  url: 'https://media.example.test/t-1/master.m3u8',
  title: 'La foi qui déplace',
);

({ProviderContainer container, InertContentPlayer player}) _setUp() {
  final player = InertContentPlayer();
  addTearDown(player.dispose);
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final container = ProviderContainer(
    overrides: [
      contentPlayerProvider.overrideWithValue(player),
      appDatabaseProvider.overrideWithValue(database),
      playbackProgressReporterProvider
          .overrideWithValue(FakePlaybackProgressReporter()),
      playReporterProvider.overrideWithValue(FakePlayReporter()),
      playSpoolProvider.overrideWithValue(FakePlaySpool()),
      mediathequeRepositoryProvider
          .overrideWithValue(InMemoryMediathequeRepository()),
      gatheringRepositoryProvider
          .overrideWithValue(InMemoryGatheringRepository()),
      // L'antenne de test, et un pré-vol qui n'ouvre aucune socket.
      radioRepositoryProvider
          .overrideWithValue(const FixedRadioRepository(kTestAntennaOnAir)),
      radioHandshakeProvider.overrideWithValue(const DirectRadioHandshake()),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, player: player);
}

PlaybackController _controller(ProviderContainer container) =>
    container.read(playbackControllerProvider.notifier);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Un enseignement', () {
    test('se met en pause quand un statut à son commence', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      _controller(container).play();

      _controller(container).interruptForStatus();

      expect(player.value.isPlaying, isFalse);
      // Une pause, pas un arrêt : la notification et la requête restent.
      expect(container.read(playbackControllerProvider)?.contentId, 't-1');
    });

    test('reprend à sa position en quittant la visionneuse, sans recharger',
        () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      _controller(container).play();
      player.emit(player.value.copyWith(
        position: const Duration(minutes: 12, seconds: 7),
      ));
      final loads = player.loadCount;

      _controller(container).interruptForStatus();
      await _controller(container).resumeAfterStatus();

      expect(player.value.isPlaying, isTrue);
      expect(player.value.position, const Duration(minutes: 12, seconds: 7));
      expect(player.loadCount, loads, reason: 'recharger repartirait du début');
    });

    test('une seconde interruption du même passage ne change rien', () async {
      // Chaque statut à son de la visionneuse rappelle l'interruption : seule
      // la première compte, sans quoi la seconde — le lecteur étant déjà en
      // pause — effacerait le souvenir de ce qui jouait.
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      _controller(container).play();

      _controller(container).interruptForStatus();
      _controller(container).interruptForStatus();
      await _controller(container).resumeAfterStatus();

      expect(player.value.isPlaying, isTrue);
    });
  });

  group('L\'antenne', () {
    test('se met en pause, puis reprend au direct : la source est rouverte',
        () async {
      final (:container, :player) = _setUp();
      await container
          .read(radioListeningProvider.notifier)
          .start(title: 'New Life Radio');
      expect(player.value.contentId, RadioConfig.contentId);
      expect(player.value.isPlaying, isTrue);
      final loads = player.loadCount;

      _controller(container).interruptForStatus();
      expect(player.value.isPlaying, isFalse);

      await _controller(container).resumeAfterStatus();

      // Un `play()` repartirait là où le tampon s'est arrêté, en retard sur
      // l'église : la reprise rouvre la source, comme un premier appui.
      expect(player.loadCount, loads + 1);
      expect(player.loadedIsLive, isTrue);
      expect(player.loadedTitle, 'New Life Radio');
      expect(player.value.contentId, RadioConfig.contentId);
      expect(player.value.isPlaying, isTrue);
    });
  });

  group('Ce qui ne reprend pas', () {
    test('une lecture déjà en pause n\'est pas relancée', () async {
      // Rien ne jouait : le statut n'a rien interrompu, et la sortie de la
      // visionneuse ne doit faire sortir aucun son que personne n'a demandé.
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);

      _controller(container).interruptForStatus();
      await _controller(container).resumeAfterStatus();

      expect(player.value.isPlaying, isFalse);
    });

    test('sans interruption, la sortie ne fait rien', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      _controller(container).play();
      _controller(container).pause();

      await _controller(container).resumeAfterStatus();

      expect(player.value.isPlaying, isFalse);
    });

    test('un contenu arrêté pendant le statut ne revient pas', () async {
      // Arrêté depuis la notification pendant l'annonce : c'est une décision,
      // et la sortie de la visionneuse ne la défait pas.
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      _controller(container).play();
      _controller(container).interruptForStatus();

      _controller(container).stop();
      await _controller(container).resumeAfterStatus();

      expect(player.value.contentId, isNull);
      expect(player.value.isPlaying, isFalse);
    });

    test('un contenu remplacé pendant le statut n\'est pas relancé', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      _controller(container).play();
      _controller(container).interruptForStatus();

      await _controller(container).load(const ContentRequest(
        contentId: 't-2',
        url: 'https://media.example.test/t-2/master.m3u8',
        title: 'Un autre message',
      ));
      await _controller(container).resumeAfterStatus();

      expect(player.value.contentId, 't-2');
      expect(player.value.isPlaying, isFalse);
    });

    test('un contenu déjà relancé n\'est pas relancé deux fois', () async {
      // Relancé depuis l'écran verrouillé pendant l'annonce : la sortie n'a
      // plus rien à faire — surtout pas rouvrir l'antenne une seconde fois.
      final (:container, :player) = _setUp();
      await container
          .read(radioListeningProvider.notifier)
          .start(title: 'New Life Radio');
      _controller(container).interruptForStatus();
      _controller(container).play();
      final loads = player.loadCount;

      await _controller(container).resumeAfterStatus();

      expect(player.loadCount, loads);
      expect(player.value.isPlaying, isTrue);
    });
  });
}
