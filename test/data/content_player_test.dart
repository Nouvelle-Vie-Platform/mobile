import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';

/// Ces tests ne touchent **aucun canal de plugin** : ils n'instancient que la
/// valeur et l'implémentation inerte. C'est la démonstration même de la
/// couture — le contrat se vérifie sans `just_audio`, donc sans
/// `MissingPluginException`.
void main() {
  group('ContentPlayback', () {
    test('progress est nul tant que la durée est inconnue', () {
      const playback = ContentPlayback(position: Duration(seconds: 12));
      // `null` et non `0` : une durée inconnue n'est pas une progression nulle.
      // Rendue à 0, la barre se dessinerait figée au début — un mensonge, là où
      // l'UI doit choisir un rendu indéterminé.
      expect(playback.progress, isNull);
    });

    test('progress vaut 0 quand la durée est connue mais nulle', () {
      const playback = ContentPlayback(duration: Duration.zero);
      expect(playback.progress, 0);
    });

    test('progress est borné à 1', () {
      const playback = ContentPlayback(
        position: Duration(seconds: 9),
        duration: Duration(seconds: 3),
      );
      expect(playback.progress, 1);
    });

    test('copyWith ne modifie que les champs fournis', () {
      const playback = ContentPlayback(
        contentId: 'c1',
        position: Duration(seconds: 4),
        duration: Duration(minutes: 40),
      );
      final updated = playback.copyWith(isPlaying: true);
      expect(updated.contentId, 'c1');
      expect(updated.position, const Duration(seconds: 4));
      expect(updated.duration, const Duration(minutes: 40));
      expect(updated.isPlaying, isTrue);
      expect(updated.hasError, isFalse);
    });

    test('deux valeurs de mêmes champs sont égales', () {
      const a =
          ContentPlayback(contentId: 'c1', position: Duration(seconds: 3));
      const b =
          ContentPlayback(contentId: 'c1', position: Duration(seconds: 3));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      // L'égalité est ce qui empêche l'écran de se reconstruire pour rien : la
      // position émet plusieurs fois par seconde.
      expect(
          a, isNot(equals(a.copyWith(position: const Duration(seconds: 4)))));
    });

    test('hasError suit la panne portée par la valeur', () {
      const sain = ContentPlayback(contentId: 'c1');
      expect(sain.hasError, isFalse);
      expect(sain.copyWith(error: 'réseau coupé').hasError, isTrue);
    });

    group('hasStarted — ce qui départage les deux phrases', () {
      test('une valeur neuve n\'a jamais commencé', () {
        // Et surtout : `isBuffering` ne peut pas servir de test. Les deux
        // implémentations le posent à vrai **dès le chargement**, avant tout
        // aller-retour réseau — une première ouverture qui échoue aurait donc
        // « mis en tampon » sans qu'un son soit jamais sorti.
        const playback = ContentPlayback(contentId: 'c1', isBuffering: true);
        expect(playback.hasStarted, isFalse);
      });

      test('une panne après le premier son reste une lecture commencée', () {
        const commence = ContentPlayback(contentId: 'c1', hasStarted: true);
        expect(commence.copyWith(error: 'réseau coupé').hasStarted, isTrue);
      });

      test('l\'égalité en tient compte', () {
        const jamais = ContentPlayback(contentId: 'c1');
        expect(jamais, isNot(equals(jamais.copyWith(hasStarted: true))));
      });
    });

    group('clampPosition', () {
      test('ramène une position négative à zéro', () {
        const playback = ContentPlayback(duration: Duration(minutes: 10));
        expect(
          playback.clampPosition(const Duration(seconds: -30)),
          Duration.zero,
        );
      });

      test('borne à la durée quand elle est connue', () {
        const playback = ContentPlayback(duration: Duration(minutes: 10));
        expect(
          playback.clampPosition(const Duration(minutes: 42)),
          const Duration(minutes: 10),
        );
      });

      test('ne borne que par le bas quand la durée est inconnue', () {
        // En HLS sur iOS la durée arrive tard, parfois jamais : la refuser
        // reviendrait à interdire l'avance rapide sur tout un système.
        const playback = ContentPlayback();
        expect(
          playback.clampPosition(const Duration(minutes: 42)),
          const Duration(minutes: 42),
        );
      });
    });
  });

  group('InertContentPlayer', () {
    test('part vide : rien de chargé, rien qui joue', () {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      expect(player.value.contentId, isNull);
      expect(player.value.isPlaying, isFalse);
      expect(player.value.position, Duration.zero);
    });

    test('load retient le contenu, son URL et son titre', () async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await player.load(
        contentId: 'c1',
        url: 'https://exemple.test/c1/master.m3u8',
        title: 'La foi qui déplace',
        author: 'Pasteur',
      );

      expect(player.value.contentId, 'c1');
      expect(player.value.position, Duration.zero);
      expect(player.loadedUrl, 'https://exemple.test/c1/master.m3u8');
      expect(player.loadedTitle, 'La foi qui déplace');
      expect(player.loadCount, 1);
    });

    test('load efface la panne et la fin du contenu précédent', () async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      player.emit(
        const ContentPlayback(
          contentId: 'c0',
          isCompleted: true,
          error: 'panne',
        ),
      );
      await player.load(contentId: 'c1', url: 'u', title: 't');

      expect(player.value.isCompleted, isFalse);
      expect(player.value.hasError, isFalse);
    });

    testWidgets('play joue, mais la position ne bouge jamais toute seule', (
      tester,
    ) async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await player.load(contentId: 'c1', url: 'u', title: 't');
      player.play();
      expect(player.value.isPlaying, isTrue);

      // Le cœur de l'implémentation inerte : aucune minuterie, jamais. Sans
      // quoi tout écran qui l'utilise cesse d'être « settleable ».
      await tester.pump(const Duration(minutes: 5));
      expect(player.value.position, Duration.zero);
      expect(player.value.isCompleted, isFalse);
      expect(player.value.isPlaying, isTrue);
    });

    test('pause fige la lecture sans perdre la position', () async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await player.load(contentId: 'c1', url: 'u', title: 't');
      player.emit(player.value.copyWith(position: const Duration(seconds: 90)));
      player.play();
      player.pause();

      expect(player.value.isPlaying, isFalse);
      expect(player.value.position, const Duration(seconds: 90));
    });

    test('seek borne la position au média chargé', () async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await player.load(contentId: 'c1', url: 'u', title: 't');
      player.emit(player.value.copyWith(duration: const Duration(minutes: 10)));

      player.seek(const Duration(seconds: -5));
      expect(player.value.position, Duration.zero);

      player.seek(const Duration(hours: 1));
      expect(player.value.position, const Duration(minutes: 10));
    });

    test('stop relâche le média **et** vide ce que le système affiche',
        () async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);

      await player.load(contentId: 'c1', url: 'u', title: 't');
      player.play();
      player.stop();

      expect(player.value, const ContentPlayback());
      // La moitié qui se rate en silence : un contenu retiré pendant l'écoute
      // dont le titre resterait affiché sur l'écran verrouillé, avec ses
      // commandes. L'implémentation réelle vide son `MediaItem` ; celle-ci vide
      // ce qui en tient lieu.
      expect(player.loadedTitle, isNull);
      expect(player.loadedUrl, isNull);
    });

    test('notifie ses auditeurs à chaque changement, et seulement alors',
        () async {
      final player = InertContentPlayer();
      addTearDown(player.dispose);
      var notifications = 0;
      player.addListener(() => notifications++);

      await player.load(contentId: 'c1', url: 'u', title: 't');
      expect(notifications, 1);

      player.play();
      expect(notifications, 2);

      // Rejouer un lecteur qui joue déjà ne produit pas de valeur nouvelle.
      player.play();
      expect(notifications, 2);
    });

    group('resume — reprendre, et non recommencer', () {
      test('repart de la position atteinte, panne effacée', () async {
        final player = InertContentPlayer();
        addTearDown(player.dispose);

        await player.load(contentId: 'c1', url: 'u', title: 't');
        player.emit(
          player.value.copyWith(
            position: const Duration(minutes: 37),
            duration: const Duration(minutes: 58),
            hasStarted: true,
            error: 'réseau coupé',
          ),
        );

        await player.resume();

        // Tout l'enjeu du mot « Reprendre » : la position tient. Repartir de
        // zéro sur un prêche d'une heure serait la panne, pas le remède.
        expect(player.value.position, const Duration(minutes: 37));
        expect(player.value.duration, const Duration(minutes: 58));
        expect(player.value.hasError, isFalse);
        expect(player.value.isPlaying, isTrue);
        // Le contenu est rouvert, pas rechargé depuis le catalogue : c'est la
        // même écoute qui continue.
        expect(player.value.contentId, 'c1');
        expect(player.loadCount, 1);
      });

      test('sans rien de chargé, il n\'y a rien à reprendre', () async {
        final player = InertContentPlayer();
        addTearDown(player.dispose);

        await player.resume();

        expect(player.value, const ContentPlayback());
        expect(player.resumeCount, 1);
      });

      test('après un stop, plus rien à reprendre non plus', () async {
        final player = InertContentPlayer();
        addTearDown(player.dispose);

        await player.load(contentId: 'c1', url: 'u', title: 't');
        player.stop();
        await player.resume();

        expect(player.value, const ContentPlayback());
      });
    });

    test('après dispose, plus rien ne bouge, et re-disposer est sans effet',
        () async {
      final player = InertContentPlayer();
      await player.load(contentId: 'c1', url: 'u', title: 't');
      player.dispose();

      // Idempotence : le provider global appelle `dispose`, un écran pourrait
      // en faire autant. Un second appel ne doit pas lever.
      player.dispose();
      expect(() => player.play(), returnsNormally);
      expect(() => player.seek(Duration.zero), returnsNormally);
    });
  });

  test(
      'la couture tient : deux fichiers de `lib/` importent just_audio, un par '
      'lecteur', () {
    // Garde-fou de **source**, sur le modèle de « jamais de polling »
    // (`sync_scheduler_test.dart`). Un `import 'package:just_audio/…'` glissé
    // dans un écran ne casserait aucun test de comportement — il rendrait la
    // suite rouge le jour où quelqu'un instancie un `AudioPlayer` dans un
    // `State`, et rendrait impossible la troisième implémentation (le web par
    // `hls.js`), qui est tout l'intérêt de cette couture.
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    expect(sources, isNotEmpty);
    final coupables = <String>[];
    for (final source in sources) {
      // Les commentaires de documentation **parlent** de `just_audio`, ils ne
      // l'importent pas.
      final code = source
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('///'))
          .join('\n');
      if (code.contains('package:just_audio/')) coupables.add(source.path);
    }

    // Deux lecteurs réels, deux contrats : la médiathèque derrière
    // `ContentPlayer`, les statuts derrière `StatusPlayer` (#130). Aucun écran.
    expect(
      coupables..sort(),
      [
        'lib/data/players/just_audio_content_player.dart',
        'lib/data/players/media_status_player.dart',
      ],
      reason: 'seules les implémentations réelles connaissent le moteur ; tout '
          'le reste du dépôt ne connaît que ContentPlayer et StatusPlayer',
    );
  });

  test('la couture tient : un seul fichier de `lib/` importe video_player', () {
    // Même garde-fou pour le moteur vidéo des statuts (#130) : un
    // `VideoPlayerController` construit dans un `State` lèverait
    // `MissingPluginException` sous `flutter test`, et l'écran ne serait plus
    // branchable sur un double.
    final coupables = <String>[];
    for (final source in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final code = source
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('///'))
          .join('\n');
      if (code.contains('package:video_player/')) coupables.add(source.path);
    }

    expect(
      coupables,
      ['lib/data/players/media_status_player.dart'],
      reason: 'seul le lecteur réel des statuts connaît le moteur vidéo',
    );
  });
}
