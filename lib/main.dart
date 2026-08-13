import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'data/players/content_player.dart';
import 'data/players/just_audio_content_player.dart';
import 'data/players/playback_notifications.dart';
import 'data/players/web_content_player.dart';
import 'state/player_providers.dart';

/// **Le seul chemin qui monte un lecteur réel** — et le seul endroit du dépôt
/// qui sache qu'il y en a deux.
///
/// Ce fichier n'est importé par aucun test, et c'est la condition qui tient
/// toute la suite verte : `AudioService.init()` produit sous `flutter test` une
/// **erreur asynchrone non rattrapée** — elle traverse le `try/catch` qui
/// l'entoure et fait rougir des tests qui n'ont rien demandé. Le lecteur réel
/// ne se construit donc qu'ici, et les écrans ne connaissent que
/// `contentPlayerProvider`.
Future<void> main() async {
  // Exigé avant tout appel de plugin : `AudioService.init()` en est un.
  WidgetsFlutterBinding.ensureInitialized();

  // Garde-fou de configuration : en release, une URL de backend en HTTP clair
  // fait échouer le démarrage plutôt que d'exposer le token Bearer en clair.
  // Volontairement avant `runApp` : mieux vaut un crash immédiat et lisible
  // qu'une app qui tourne en fuyant les identifiants.
  ApiClient.ensureSecureBaseUrl();

  final player = await _startPlayback();

  runApp(
    ProviderScope(
      overrides: [
        if (player != null) contentPlayerProvider.overrideWithValue(player),
      ],
      child: const MaisonDuMiracleApp(),
    ),
  );
}

/// Monte la lecture et rend le lecteur à brancher sur `contentPlayerProvider`.
///
/// Rend `null` si la plateforme ne sait pas l'héberger : l'application démarre
/// alors avec le lecteur inerte du provider. Une médiathèque muette vaut mieux
/// qu'une application qui refuse de s'ouvrir — c'est vrai des deux côtés du
/// `kIsWeb`, et c'est pourquoi les deux chemins sont sous `try`.
Future<ContentPlayer?> _startPlayback() async {
  // **Le web ne monte pas `audio_service`.** Notification, écran verrouillé et
  // service de premier plan n'y existent pas : `AudioService.init()` y est un
  // no-op qui coûte une initialisation et un risque d'échec au démarrage. Les
  // boutons « −30 s / +30 s » s'y rendent dans l'interface Flutter, comme sur
  // mobile, au même pas (`kContentSkipInterval`).
  //
  // Et surtout : sur le web, `just_audio` **ne joue rien** hors Safari — son
  // implémentation pose l'URL `.m3u8` dans un `<audio>` sans lecteur HLS. C'est
  // `HlsContentPlayer` qui sert, sans aucun des trois paquets audio.
  if (kIsWeb) {
    try {
      return createWebContentPlayer();
    } catch (error, stackTrace) {
      debugPrint('Le lecteur web n\'a pas démarré : $error\n$stackTrace');
      return null;
    }
  }

  try {
    final handler = await AudioService.init(
      builder: ContentAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.maisondumiracle.maison_du_miracle.channel.audio',
        androidNotificationChannelName: 'Lecture des enseignements',
        // **Le défaut (`true`) est un piège.** Mettre en pause arrêterait le
        // service de premier plan, et le relancer depuis l'arrière-plan lève
        // `ForegroundServiceStartNotAllowedException` sur Android 12+. Or
        // mettre un prêche en pause est le geste le plus banal d'un fidèle.
        androidStopForegroundOnPause: false,
        // Le pas des boutons « −30 s / +30 s » de la notification et de l'écran
        // verrouillé — la même valeur que celle des boutons de l'écran.
        fastForwardInterval: kContentSkipInterval,
        rewindInterval: kContentSkipInterval,
      ),
    );

    // **Après** l'initialisation, jamais avant : les plugins audio écrasent
    // mutuellement la session partagée de l'application, et le dernier à
    // configurer gagne. Profil « parole » et non le défaut « musique », qui
    // fait baisser le volume à chaque instruction du GPS — un prêche s'écoute
    // en voiture.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    // Android 13+ : sans cette demande, la notification de lecture n'apparaît
    // jamais. Ne bloque pas le démarrage, et son refus n'empêche pas d'écouter.
    await requestPlaybackNotificationPermission();

    return JustAudioContentPlayer(handler);
  } catch (error, stackTrace) {
    debugPrint('Le service de lecture n\'a pas démarré : $error\n$stackTrace');
    return null;
  }
}
