import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'data/players/content_player.dart';
import 'data/players/just_audio_content_player.dart';
import 'data/players/playback_notifications.dart';
import 'state/player_providers.dart';

/// **Le seul chemin qui monte le lecteur réel.**
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

/// Monte le service de lecture et rend le lecteur qui s'y branche.
///
/// Rend `null` si la plateforme ne sait pas l'héberger : l'application démarre
/// alors avec le lecteur inerte du provider. Une médiathèque muette vaut mieux
/// qu'une application qui refuse de s'ouvrir.
Future<ContentPlayer?> _startPlayback() async {
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
