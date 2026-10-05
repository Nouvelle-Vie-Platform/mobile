/// **Le contrôleur global de lecture** (#114) — le seul point d'entrée du
/// transport.
///
/// Tout se lit sur l'[InertContentPlayer] : ce que le lecteur a reçu, jamais
/// la façon dont le contrôleur l'a transmis. Et la requête courante se lit
/// comme le mini-lecteur la lira, par le provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/state/playback_controller.dart';
import 'package:maison_du_miracle/state/player_providers.dart';

const _sermon = ContentRequest(
  contentId: 't-1',
  url: 'https://media.example.test/t-1/master.m3u8',
  title: 'La foi qui déplace',
  author: 'Pasteur Samuel',
  artUrl: 'https://media.example.test/t-1/carre.jpg',
);

const _antenna = ContentRequest(
  contentId: 'radio',
  url: 'https://stream.example.test/antenne/index.m3u8',
  title: 'New Life Radio',
  isLive: true,
  headers: {'Cookie': 'hlsSession=abc'},
);

/// Un conteneur sur un lecteur inerte fourni par le test.
({ProviderContainer container, InertContentPlayer player}) _setUp() {
  final player = InertContentPlayer();
  addTearDown(player.dispose);
  final container = ProviderContainer(
    overrides: [contentPlayerProvider.overrideWithValue(player)],
  );
  addTearDown(container.dispose);
  return (container: container, player: player);
}

PlaybackController _controller(ProviderContainer container) =>
    container.read(playbackControllerProvider.notifier);

void main() {
  group('La requête courante', () {
    test('vaut `null` tant que rien n\'est chargé', () {
      final (:container, player: _) = _setUp();

      expect(container.read(playbackControllerProvider), isNull);
    });

    test('porte ce que le mini-lecteur affichera, une fois chargée', () async {
      final (:container, player: _) = _setUp();

      await _controller(container).load(_sermon);

      final request = container.read(playbackControllerProvider);
      expect(request?.contentId, 't-1');
      expect(request?.title, 'La foi qui déplace');
      expect(request?.author, 'Pasteur Samuel');
      expect(request?.artUrl, 'https://media.example.test/t-1/carre.jpg');
      expect(request?.isLive, isFalse);
    });

    test('dit qu\'une antenne est un direct', () async {
      final (:container, player: _) = _setUp();

      await _controller(container).load(_antenna);

      expect(container.read(playbackControllerProvider)?.isLive, isTrue);
    });

    test('retombe à `null` après un arrêt', () async {
      final (:container, player: _) = _setUp();
      await _controller(container).load(_sermon);

      _controller(container).stop();

      expect(container.read(playbackControllerProvider), isNull);
    });

    test('suit le chargement suivant, sans garder l\'ancien titre', () async {
      final (:container, player: _) = _setUp();
      await _controller(container).load(_sermon);

      // La radio **remplace** l'enseignement : il n'y a qu'un lecteur.
      await _controller(container).load(_antenna);

      expect(
          container.read(playbackControllerProvider)?.title, 'New Life Radio');
    });

    test('le lecteur reste juge : arrêté ailleurs, la requête tombe', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);

      // Un arrêt qui ne passe pas par le contrôleur — le lecteur qui relâche
      // son média de lui-même. Une requête qui survivrait afficherait le titre
      // d'un prêche que plus rien ne joue.
      player.stop();

      expect(container.read(playbackControllerProvider), isNull);
    });

    test('un abonné est prévenu du chargement et de l\'arrêt', () async {
      final (:container, player: _) = _setUp();
      final seen = <String?>[];
      container.listen<ContentRequest?>(
        playbackControllerProvider,
        (_, next) => seen.add(next?.contentId),
      );

      await _controller(container).load(_sermon);
      _controller(container).stop();

      expect(seen, ['t-1', null]);
    });

    test('n\'est pas autoDispose : elle survit à la perte d\'abonnés',
        () async {
      final (:container, player: _) = _setUp();
      final subscription =
          container.listen(playbackControllerProvider, (_, __) {});
      await _controller(container).load(_sermon);
      subscription.close();
      await Future<void>.delayed(Duration.zero);

      // On quitte la fiche, le son continue : ce qui le décrit doit rester
      // lisible par le prochain écran qui le demande.
      expect(container.read(playbackControllerProvider)?.contentId, 't-1');
    });
  });

  group('Le chargement', () {
    test('remet toute la requête au lecteur, sans jouer', () async {
      final (:container, :player) = _setUp();

      await _controller(container).load(
        const ContentRequest(
          contentId: 't-1',
          url: 'https://media.example.test/t-1/master.m3u8',
          title: 'La foi qui déplace',
          author: 'Pasteur Samuel',
          filePath: '/telechargements/t-1.aac',
        ),
      );

      expect(player.value.contentId, 't-1');
      expect(player.loadedUrl, 'https://media.example.test/t-1/master.m3u8');
      expect(player.loadedFilePath, '/telechargements/t-1.aac');
      expect(player.loadedTitle, 'La foi qui déplace');
      expect(player.loadedAuthor, 'Pasteur Samuel');
      expect(player.loadedIsLive, isFalse);
      expect(player.loadCount, 1);
      // Charger ne joue pas : ouvrir un enseignement ne doit pas faire sortir
      // du son dans une salle de culte.
      expect(player.value.isPlaying, isFalse);
    });

    test('le régime direct et le cookie de l\'antenne descendent', () async {
      final (:container, :player) = _setUp();

      await _controller(container).load(_antenna);

      // Le chemin du cookie de MediaMTX (#108) : perdu ici, la radio se tairait
      // sur un 401 qu'aucun écran ne relierait à sa cause.
      expect(player.loadedIsLive, isTrue);
      expect(player.loadedHeaders, {'Cookie': 'hlsSession=abc'});
    });
  });

  group('Le transport', () {
    test('lecture et pause', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);

      _controller(container).play();
      expect(player.value.isPlaying, isTrue);

      _controller(container).pause();
      expect(player.value.isPlaying, isFalse);
    });

    test('déplacer la tête de lecture', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      player.emit(player.value.copyWith(duration: const Duration(minutes: 40)));

      _controller(container).seek(const Duration(minutes: 12));

      expect(player.value.position, const Duration(minutes: 12));
    });

    test('les sauts sont de trente secondes, dans les deux sens', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      player.emit(
        player.value.copyWith(
          duration: const Duration(minutes: 40),
          position: const Duration(minutes: 10),
        ),
      );

      // Écrit en clair, jamais relu depuis `kContentSkipInterval` : c'est la
      // constante qu'on éprouve, et la notification promet « 30 s ».
      _controller(container).skipForward();
      expect(player.value.position, const Duration(minutes: 10, seconds: 30));

      _controller(container).skipBackward();
      _controller(container).skipBackward();
      expect(player.value.position, const Duration(minutes: 9, seconds: 30));
    });

    test('un recul au début s\'arrête à zéro', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      player.emit(player.value.copyWith(position: const Duration(seconds: 12)));

      _controller(container).skipBackward();

      expect(player.value.position, Duration.zero);
    });

    test('une avance s\'arrête à la fin quand la durée est connue', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      player.emit(
        player.value.copyWith(
          duration: const Duration(minutes: 40),
          position: const Duration(minutes: 39, seconds: 50),
        ),
      );

      _controller(container).skipForward();

      expect(player.value.position, const Duration(minutes: 40));
    });

    test('un direct ne saute pas', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_antenna);
      player.emit(player.value.copyWith(position: const Duration(seconds: 50)));

      // Ni position à reprendre, ni durée à parcourir — et la fenêtre de
      // l'antenne ne porte que quarante secondes de rattrapage.
      _controller(container).skipBackward();
      _controller(container).skipForward();

      expect(player.value.position, const Duration(seconds: 50));
    });

    test('l\'arrêt relâche le média et vide ce que le système affiche',
        () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      _controller(container).play();

      _controller(container).stop();

      expect(player.value, const ContentPlayback());
      expect(player.loadedTitle, isNull);
      expect(player.loadedUrl, isNull);
    });

    test('rejouer repart du début, et joue', () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      player.emit(
        player.value.copyWith(
          duration: const Duration(minutes: 40),
          position: const Duration(minutes: 40),
          isCompleted: true,
        ),
      );

      _controller(container).replay();

      expect(player.value.position, Duration.zero);
      expect(player.value.isPlaying, isTrue);
      expect(player.loadCount, 1, reason: 'aucun rechargement');
    });

    test('reprendre après une panne repart de la position, pas de zéro',
        () async {
      final (:container, :player) = _setUp();
      await _controller(container).load(_sermon);
      player.emit(
        player.value.copyWith(
          position: const Duration(minutes: 23),
          hasStarted: true,
          error: Exception('réseau coupé'),
        ),
      );

      await _controller(container).resume();

      expect(player.resumeCount, 1);
      expect(player.value.hasError, isFalse);
      expect(player.value.position, const Duration(minutes: 23));
      expect(player.loadCount, 1, reason: 'reprendre n\'est pas recharger');
      // La panne n'a pas changé ce qui est chargé.
      expect(container.read(playbackControllerProvider)?.contentId, 't-1');
    });
  });
}
