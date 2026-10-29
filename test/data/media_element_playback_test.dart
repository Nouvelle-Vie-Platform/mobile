import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/players/media_element_playback.dart';
import 'package:maison_du_miracle/data/players/playback_watchdog.dart';

/// Ce que fait `HlsContentPlayer` à sa construction, sans le DOM : armer le
/// chien de garde sur sa propre réouverture de source.
///
/// La classe nue, elle, ne l'arme pas — sans quoi chacun des tests ci-dessus
/// laisserait une minuterie en suspens.
class _WatchedPlayback extends MediaElementPlayback {
  _WatchedPlayback() {
    armStallWatchdog(reopened.add);
  }

  final List<Duration> reopened = [];
}

/// **La part vérifiable du lecteur web.**
///
/// `flutter test` tourne sur la VM : ni `<audio>`, ni `hls.js`, ni interop. Ce
/// qui se teste ici est donc tout ce qui n'est **pas** un câble — les décisions
/// du lecteur web, séparées de l'interop exprès pour ça.
///
/// Ce que ces tests ne prouvent pas, et qui ne se vérifie que dans un
/// navigateur : que les événements arrivent, et dans cet ordre.
void main() {
  group('MediaElementPlayback — la durée d\'un média HTML', () {
    test('NaN reste une durée inconnue', () {
      // La valeur que porte l'élément pendant tout le début d'un chargement
      // HLS : les métadonnées ne sont pas arrivées.
      expect(MediaElementPlayback.durationFromSeconds(double.nan), isNull);
    });

    test('un flux live (Infinity) reste une durée inconnue', () {
      expect(MediaElementPlayback.durationFromSeconds(double.infinity), isNull);
    });

    test('zéro et le négatif restent une durée inconnue', () {
      // Rendus tels quels, ils dessineraient une lecture terminée d'avance.
      expect(MediaElementPlayback.durationFromSeconds(0), isNull);
      expect(MediaElementPlayback.durationFromSeconds(-3), isNull);
    });

    test('une durée réelle se convertit à la microseconde', () {
      expect(
        MediaElementPlayback.durationFromSeconds(2532.5),
        const Duration(seconds: 2532, milliseconds: 500),
      );
    });
  });

  group('MediaElementPlayback — la position', () {
    test('une position non finie ne dit rien', () {
      expect(MediaElementPlayback.positionFromSeconds(double.nan), isNull);
    });

    test('une position négative se ramène à zéro', () {
      expect(MediaElementPlayback.positionFromSeconds(-0.5), Duration.zero);
    });

    test('une position réelle se convertit à la microseconde', () {
      expect(
        MediaElementPlayback.positionFromSeconds(12.25),
        const Duration(seconds: 12, milliseconds: 250),
      );
    });
  });

  group('MediaElementPlayback — la traduction des événements', () {
    late MediaElementPlayback playback;

    setUp(() => playback = MediaElementPlayback());
    tearDown(() => playback.dispose());

    test('la valeur de départ est vide', () {
      expect(playback.value, const ContentPlayback());
    });

    test('un chargement met en tampon et retient le contenu', () {
      playback.startLoading('c1');
      expect(playback.value.contentId, 'c1');
      expect(playback.value.isBuffering, isTrue);
      // Charger ne démarre pas la lecture : ouvrir un enseignement ne doit pas
      // faire sortir du son dans une salle de culte.
      expect(playback.value.isPlaying, isFalse);
      expect(playback.value.position, Duration.zero);
    });

    test('un nouveau chargement efface durée, fin et panne du précédent', () {
      playback.startLoading('c1');
      playback.updateDuration(600);
      playback.markEnded();
      playback.fail(MediaPlaybackError('media', 'réseau coupé'));

      playback.startLoading('c2');

      expect(playback.value.contentId, 'c2');
      expect(playback.value.duration, isNull);
      expect(playback.value.isCompleted, isFalse);
      expect(playback.value.hasError, isFalse);
    });

    test('timeupdate avance la position', () {
      playback.startLoading('c1');
      playback.updatePosition(30);
      expect(playback.value.position, const Duration(seconds: 30));
    });

    test('une position illisible ne fait pas reculer la lecture', () {
      playback.startLoading('c1');
      playback.updatePosition(30);
      playback.updatePosition(double.nan);
      // Un `currentTime` illisible ne veut pas dire « retour au début ».
      expect(playback.value.position, const Duration(seconds: 30));
    });

    test('une position identique ne republie pas la valeur', () {
      // Le point qui protège l'écran : `timeupdate` bat plusieurs fois par
      // seconde, et un abonné ne doit se réveiller que si quelque chose a
      // changé.
      playback.startLoading('c1');
      var emissions = 0;
      playback.addListener(() => emissions++);
      playback.updatePosition(30);
      playback.updatePosition(30);
      playback.updatePosition(30);
      expect(emissions, 1);
    });

    test('durationchange pose la durée', () {
      playback.startLoading('c1');
      playback.updateDuration(2532);
      expect(playback.value.duration, const Duration(seconds: 2532));
    });

    test('une durée redevenue NaN n\'efface pas la durée connue', () {
      // Au détachement de la source, l'élément repasse par `NaN` : la barre de
      // l'écran sauterait en indéterminé au dernier instant d'un enseignement.
      playback.startLoading('c1');
      playback.updateDuration(2532);
      playback.updateDuration(double.nan);
      expect(playback.value.duration, const Duration(seconds: 2532));
    });

    test('play annonce l\'intention avant que le son ne sorte', () {
      // Même sémantique que `just_audio`, dont `playing` est une intention et
      // non un constat : l'écran bascule son bouton tout de suite.
      playback.startLoading('c1');
      playback.markPlayRequested();
      expect(playback.value.isPlaying, isTrue);
      // Le tampon ne bouge pas : pas de clignotement entre `play` et `playing`.
      expect(playback.value.isBuffering, isTrue);
    });

    test('playing sort du tampon, waiting y remet', () {
      playback.startLoading('c1');
      playback.markRendering();
      expect(playback.value.isPlaying, isTrue);
      expect(playback.value.isBuffering, isFalse);

      playback.markWaiting();
      expect(playback.value.isBuffering, isTrue);
      // Une attente n'est pas une pause : la lecture est toujours demandée.
      expect(playback.value.isPlaying, isTrue);

      playback.markRendering();
      expect(playback.value.isBuffering, isFalse);
    });

    test('canplay sort du tampon sans prétendre que le son sort', () {
      playback.startLoading('c1');
      playback.markReady();
      expect(playback.value.isBuffering, isFalse);
      expect(playback.value.isPlaying, isFalse);
    });

    test('pause fige la lecture sans toucher à la position', () {
      playback.startLoading('c1');
      playback.updatePosition(42);
      playback.markRendering();
      playback.markPaused();
      expect(playback.value.isPlaying, isFalse);
      expect(playback.value.position, const Duration(seconds: 42));
    });

    test('ended arrête tout et marque la fin', () {
      playback.startLoading('c1');
      playback.markRendering();
      playback.markEnded();
      expect(playback.value.isCompleted, isTrue);
      expect(playback.value.isPlaying, isFalse);
      expect(playback.value.isBuffering, isFalse);
    });

    test('reprendre après la fin efface la fin atteinte', () {
      playback.startLoading('c1');
      playback.markEnded();
      playback.markPlayRequested();
      expect(playback.value.isCompleted, isFalse);
      expect(playback.value.isPlaying, isTrue);
    });

    test('une panne coupe la mise en tampon et la lecture', () {
      playback.startLoading('c1');
      playback.markRendering();
      playback.fail(MediaPlaybackError('hls.js', 'manifeste introuvable'));
      expect(playback.value.hasError, isTrue);
      expect(playback.value.isBuffering, isFalse);
      expect(playback.value.isPlaying, isFalse);
      // L'identifiant reste : l'écran doit pouvoir proposer un réessai du
      // **même** enseignement.
      expect(playback.value.contentId, 'c1');
    });

    test('deux pannes identiques restent deux émissions distinctes', () {
      // Un réessai qui échoue de la même façon doit se voir. Une chaîne de
      // caractères serait égale à la précédente et n'émettrait rien.
      playback.startLoading('c1');
      var emissions = 0;
      playback.addListener(() => emissions++);
      playback.fail(MediaPlaybackError('media', 'code 4'));
      playback.fail(MediaPlaybackError('media', 'code 4'));
      expect(emissions, 2);
    });

    test('une panne avant tout son n\'a jamais commencé', () {
      // Le manifeste ne répond pas : rien n'est jamais sorti. L'écran doit
      // dire « il faut du réseau », pas « lecture interrompue » — il n'y a
      // aucune position à défendre.
      playback.startLoading('c1');
      playback.fail(MediaPlaybackError('hls.js', 'manifeste introuvable'));
      expect(playback.value.hasStarted, isFalse);
    });

    test('canplay suffit à dire que le son a commencé', () {
      playback.startLoading('c1');
      playback.markReady();
      expect(playback.value.hasStarted, isTrue);
    });

    test('une panne après le premier son reste une lecture commencée', () {
      playback.startLoading('c1');
      playback.markRendering();
      playback.updatePosition(2214);
      playback.fail(MediaPlaybackError('media', 'code 2'));
      expect(playback.value.hasStarted, isTrue);
      expect(playback.value.position, const Duration(seconds: 2214));
    });

    test('un nouveau chargement oublie que le son avait commencé', () {
      playback.startLoading('c1');
      playback.markRendering();
      playback.startLoading('c2');
      expect(playback.value.hasStarted, isFalse);
    });

    test('clear repart d\'une valeur vide', () {
      playback.startLoading('c1');
      playback.updateDuration(600);
      playback.clear();
      expect(playback.value, const ContentPlayback());
    });
  });

  group('MediaElementPlayback — le déplacement', () {
    late MediaElementPlayback playback;

    setUp(() => playback = MediaElementPlayback());
    tearDown(() => playback.dispose());

    test('rend les secondes à écrire dans currentTime', () {
      playback.startLoading('c1');
      playback.updateDuration(600);
      expect(playback.seekTo(const Duration(seconds: 90)), 90.0);
    });

    test('pose la position sans attendre le navigateur', () {
      // Sans ça, le curseur reviendrait en arrière le temps de la recherche.
      playback.startLoading('c1');
      playback.updateDuration(600);
      playback.seekTo(const Duration(seconds: 90));
      expect(playback.value.position, const Duration(seconds: 90));
    });

    test('borne à la durée quand elle est connue', () {
      playback.startLoading('c1');
      playback.updateDuration(600);
      // Le « +30 s » à trente secondes de la fin.
      expect(playback.seekTo(const Duration(minutes: 42)), 600.0);
      expect(playback.value.position, const Duration(seconds: 600));
    });

    test('n\'interdit pas d\'avancer quand la durée est inconnue', () {
      // Refuser d'avancer faute de durée priverait de l'avance rapide tout le
      // début d'un flux HLS, avant l'arrivée du manifeste.
      playback.startLoading('c1');
      expect(playback.seekTo(const Duration(seconds: 90)), 90.0);
    });

    test('ramène le négatif à zéro', () {
      // Le « −30 s » à dix secondes du début.
      playback.startLoading('c1');
      playback.updatePosition(10);
      expect(playback.seekTo(const Duration(seconds: -20)), 0.0);
      expect(playback.value.position, Duration.zero);
    });

    test('un déplacement annule la fin atteinte', () {
      playback.startLoading('c1');
      playback.updateDuration(600);
      playback.markEnded();
      playback.seekTo(const Duration(seconds: 120));
      expect(playback.value.isCompleted, isFalse);
    });
  });

  group('MediaElementPlayback — la reprise', () {
    late MediaElementPlayback playback;

    setUp(() => playback = MediaElementPlayback());
    tearDown(() => playback.dispose());

    test('rend la position à restaurer et efface la panne', () {
      playback.startLoading('c1');
      playback.markRendering();
      playback.updateDuration(3480);
      playback.updatePosition(2214);
      playback.fail(MediaPlaybackError('media', 'réseau coupé'));

      expect(playback.beginResume(), const Duration(seconds: 2214));

      // Ce que le mot « Reprendre » promet : la position tient, la durée
      // aussi, et le lecteur repart en attente de données.
      expect(playback.value.position, const Duration(seconds: 2214));
      expect(playback.value.duration, const Duration(seconds: 3480));
      expect(playback.value.hasError, isFalse);
      expect(playback.value.isPlaying, isTrue);
      expect(playback.value.isBuffering, isTrue);
      expect(playback.value.hasStarted, isTrue);
    });

    test('sans rien de chargé, il n\'y a rien à reprendre', () {
      expect(playback.beginResume(), isNull);
      expect(playback.value, const ContentPlayback());
    });
  });

  group('MediaElementPlayback — le chien de garde', () {
    testWidgets('la classe nue ne pose aucune minuterie', (tester) async {
      // Ce qui protège les vingt tests ci-dessus : une minuterie posée d'office
      // les ferait tous rougir sur « pending timer ».
      final playback = MediaElementPlayback();
      addTearDown(playback.dispose);
      playback.startLoading('c1');
      playback.markPlayRequested();

      await tester.pump(kPlaybackStallTimeout * 3);
    });

    testWidgets('une position figée en tampon rouvre la source', (
      tester,
    ) async {
      final playback = _WatchedPlayback();
      addTearDown(playback.dispose);

      playback.startLoading('c1');
      playback.markRendering();
      playback.updatePosition(2214);
      // `waiting` : le média s'est arrêté faute de données. Sur iOS, plus rien
      // n'arrivera jamais — ni segment, ni erreur.
      playback.markWaiting();

      await tester.pump(kPlaybackStallTimeout + const Duration(seconds: 1));

      expect(playback.reopened, [const Duration(seconds: 2214)]);
    });

    testWidgets('une lecture qui avance n\'est jamais rouverte', (
      tester,
    ) async {
      final playback = _WatchedPlayback();
      addTearDown(playback.dispose);

      playback.startLoading('c1');
      playback.markRendering();
      for (var second = 1; second <= 60; second++) {
        playback.updatePosition(second.toDouble());
        await tester.pump(const Duration(seconds: 1));
      }

      expect(playback.reopened, isEmpty);
    });
  });

  group('MediaElementPlayback — après libération', () {
    test('un événement en vol ne fait pas lever un notifier libéré', () {
      // Les événements du DOM arrivent encore un instant après le détachement
      // d'une source.
      final playback = MediaElementPlayback()..startLoading('c1');
      playback.dispose();
      expect(playback.isDisposed, isTrue);
      expect(() => playback.updatePosition(30), returnsNormally);
      expect(() => playback.markRendering(), returnsNormally);
      expect(
          () => playback.fail(MediaPlaybackError('x', 'y')), returnsNormally);
      expect(() => playback.dispose(), returnsNormally);
    });
  });

  // Ce que le lecteur **remet au navigateur** (#272) : les décisions, prises
  // ici, qu'`HlsContentPlayer` ne fait que câbler. Ce qu'aucun test ne peut
  // dire reste écrit en toutes lettres — qu'un cookie traverse jusqu'à
  // MediaMTX ne se prouve que dans un navigateur, sur la vraie origine.
  group('MediaElementPlayback — les identifiants du flux', () {
    test('un direct les demande, un enseignement jamais', () {
      // Sans eux, l'antenne rend `401 session not found` ; avec eux partout,
      // la médiathèque casserait — ses routes répondent `Allow-Origin: *`.
      expect(MediaElementPlayback.wantsCredentials(isLive: true), isTrue);
      expect(MediaElementPlayback.wantsCredentials(isLive: false), isFalse);
    });
  });

  group('MediaElementPlayback — la session média', () {
    test('un direct n\'offre pas de saut, un enseignement si', () {
      // La règle de la notification native (#104) : 40 s de rattrapage.
      expect(
        MediaElementPlayback.mediaSessionAllowsSkip(isLive: true),
        isFalse,
      );
      expect(
        MediaElementPlayback.mediaSessionAllowsSkip(isLive: false),
        isTrue,
      );
    });

    test('la ligne d\'état passe par-dessus l\'auteur', () {
      const request = ContentRequest(
        contentId: 'radio',
        url: 'https://x/master.m3u8',
        title: 'New Life Radio',
        author: 'Pasteur',
        isLive: true,
      );
      expect(
        MediaElementPlayback.mediaSessionArtist(request, 'Reconnexion…'),
        'Reconnexion…',
      );
      // `null` rend l'auteur — le contrat de `setStatusLine`.
      expect(
        MediaElementPlayback.mediaSessionArtist(request, null),
        'Pasteur',
      );
    });

    test('sans auteur ni ligne d\'état, aucune seconde ligne', () {
      const request = ContentRequest(
        contentId: 'c1',
        url: 'https://x/master.m3u8',
        title: 'Prêche',
      );
      // Jamais « Auteur inconnu » : `MediaMetadata` n'accepte pas de `null`,
      // et la chaîne vide est ce qui n'affiche rien.
      expect(MediaElementPlayback.mediaSessionArtist(request, null), '');
    });

    test('sans contenu tenu, le système reprend sa fiche', () {
      expect(
        MediaElementPlayback.mediaSessionPlaybackState(const ContentPlayback()),
        'none',
      );
    });

    test('l\'état suit la lecture et la pause', () {
      final playback = MediaElementPlayback()..startLoading('c1');
      expect(
        MediaElementPlayback.mediaSessionPlaybackState(playback.value),
        'paused',
      );
      playback.markPlayRequested();
      expect(
        MediaElementPlayback.mediaSessionPlaybackState(playback.value),
        'playing',
      );
      playback.markPaused();
      expect(
        MediaElementPlayback.mediaSessionPlaybackState(playback.value),
        'paused',
      );
      // Un arrêt rend la fiche, même après avoir joué.
      playback.clear();
      expect(
        MediaElementPlayback.mediaSessionPlaybackState(playback.value),
        'none',
      );
      playback.dispose();
    });
  });
}
