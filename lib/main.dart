import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_env.dart';
import 'core/network/api_client.dart';
import 'data/devices/http_device_repository.dart';
import 'data/players/bitrate_cap_controller.dart';
import 'data/players/content_player.dart';
import 'models/media_preferences.dart';
import 'data/players/just_audio_content_player.dart';
import 'data/players/media_status_player.dart';
import 'data/players/playback_notifications.dart';
import 'data/install/web_install_prompt.dart';
import 'data/players/web_content_player.dart';
import 'data/push/fcm_push_transport.dart';
import 'data/push/push_transport.dart';
import 'data/push/wake_notifier.dart';
import 'data/update/web_app_reloader.dart';
import 'firebase_options.dart';
import 'state/app_update_providers.dart';
import 'state/install_providers.dart';
import 'state/media_settings_providers.dart';
import 'state/player_providers.dart';
import 'state/push_providers.dart';
import 'state/startup_providers.dart';
import 'state/season_providers.dart';

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

  // **Le mode invité s'installe ici, avant la première requête.**
  //
  // L'ordre des quatre lignes qui suivent est l'ordre du démarrage, et chacune
  // est à sa place pour une raison :
  //
  // 1. `wire()` **avant tout appel réseau** : c'est lui qui donne à
  //    l'intercepteur 401 quelqu'un à qui demander un jeton frais. Câblé après la
  //    première requête, le premier 401 d'un invité éjecterait encore vers
  //    `/auth` ;
  // 2. la **lecture du coffre**, attendue : deux lectures locales, aucun réseau,
  //    et c'est ce qui décide de l'existence du splash. C'est le seul `await`
  //    ajouté avant `runApp`, et il est d'un ordre de grandeur sous
  //    `AudioService.init()` qui l'entoure déjà ;
  // 3. `ensureSession()` **lancé sans être attendu** : le premier écran ne doit
  //    pas attendre le réseau. L'application s'ouvre, le jeton arrive. Ce qui en
  //    dépend vraiment — le premier cycle de synchronisation — l'attend de son
  //    côté, borné, dans `app.dart` ;
  // 4. et si le coffre porte déjà un jeton (de membre comme d'appareil),
  //    `ensureSession()` ne demande rien du tout : il n'y a **pas** de requête
  //    par ouverture d'application.
  // (1) Le porteur, installé sur le client HTTP. Hors backend il n'y a personne
  // à qui parler, et l'application reste celle d'avant.
  final device = AppEnv.useBackend ? HttpDeviceRepository.wire() : null;

  // (2) Ce que le coffre portait, lu **avant** d'y écrire quoi que ce soit.
  final vault = device == null ? StartupVault.unread : await readStartupVault();

  // (3) L'ouverture de session, lancée et **pas attendue**. Le `onError` n'est
  // pas une ceinture de plus : personne n'attend ce `Future` avant le premier
  // frame, et une erreur sans écouteur remonterait en « unhandled async error »
  // à l'ouverture de l'application.
  var bootstrap = DeviceBootstrap.none;
  if (device != null) {
    final session = device.ensureSession().onError<Object>((_, __) => false);
    bootstrap = DeviceBootstrap(repository: device, session: session);
  }

  final player = await _startPlayback();

  // (4) **Le transport de réveil**, choisi ici et nulle part ailleurs — c'est le
  // seul fichier du dépôt qui sache que Firebase existe, exactement comme il est le
  // seul à savoir qu'il y a deux lecteurs. `null` veut dire « cet appareil n'a pas
  // de push », et l'application tourne alors sur le double inerte
  // (`pushTransportProvider`) : c'est le cas du web, de macOS, et d'un Android
  // dé-googlé jusqu'à la tranche 4 (#99).
  final push = await _startPush();

  // (5) **Le fond déjà sur le disque**, lu avant le premier frame. L'écran de
  // marque dure le temps de résoudre une session : un fond qui arriverait après
  // lui n'aurait servi à personne. Pas de réseau, pas de base — un seul fichier
  // dans un dossier —, et `null` au premier lancement : l'écran retombe alors
  // sur le dernier étage de la cascade, l'image du dépôt, celle-là même que
  // peint le démarrage natif.
  final startupBackground =
      AppEnv.useBackend ? await readStartupBackground() : null;

  // Le conteneur est construit ici plutôt que par `ProviderScope` seul : c'est
  // ce qui permet de brancher le plafond de débit **hors de l'arbre de
  // widgets**, sur le lecteur réel. `UncontrolledProviderScope` le rend ensuite
  // à l'application, qui n'en sait rien.
  final container = ProviderContainer(
    overrides: [
      if (player != null) contentPlayerProvider.overrideWithValue(player),
      // **Les lecteurs réels des statuts** (#130) : `just_audio` pour l'audio,
      // `video_player` pour la vidéo. Pas sur le web, où ni l'un ni l'autre ne
      // lit le HLS hors Safari (#46) : le provider y garde `FakeStatusPlayer`,
      // et un statut média y défile avec son affiche, sans son. Construit à la
      // demande — rien ne s'ouvre avant le premier statut affiché.
      if (!kIsWeb)
        statusPlayerProvider.overrideWith((ref) {
          final statusPlayer = MediaStatusPlayer();
          ref.onDispose(statusPlayer.dispose);
          return statusPlayer;
        }),
      // **L'invite d'installation**, sur le web seulement : ailleurs
      // l'application est déjà installée, et `browser_install_prompt.dart`
      // importe `dart:js_interop`, qui n'existe pas sur la VM. Même porte que
      // le lecteur web, même raison.
      if (kIsWeb)
        installPromptProvider.overrideWithValue(createInstallPrompt()),
      // **Le rechargement**, sur le web seulement : c'est là que le bouton du
      // bandeau de mise à jour n'a aucun magasin à ouvrir. Même porte, même
      // raison.
      if (kIsWeb) appReloaderProvider.overrideWithValue(createAppReloader()),
      // Les deux seules choses que `main()` sait et que l'arbre de widgets ne
      // pourrait pas apprendre à temps : ce que portait le coffre, et le porteur
      // d'appareil de cette exécution.
      startupVaultProvider.overrideWithValue(vault),
      deviceBootstrapProvider.overrideWithValue(bootstrap),
      startupCachedBackgroundProvider.overrideWithValue(startupBackground),
      // **Le transport de réveil et le tap, posés ensemble ou pas du tout.** Sans
      // transport il n'y a aucune notification locale à recevoir, et initialiser le
      // greffon de notifications pour rien coûterait un canal natif au démarrage.
      //
      // ⚠️ `wakeNotifierProvider` n'est **pas** surchargé, et ce n'est pas un oubli :
      // l'affichage appartient au réveil de l'application *fermée*, dans son isolate
      // (`push_background.dart`). Application ouverte, les écrans se repeignent du
      // magasin — voir `push_providers.dart`.
      if (push != null) ...[
        pushTransportProvider.overrideWithValue(push),
        wakeTapsProvider.overrideWithValue(LocalWakeTaps()),
        // **Effacer**, oui (M5) : la notification d'une conversation qu'on
        // vient de lire part, application ouverte. Afficher, toujours non —
        // c'est `wakeNotifierProvider`, inerte au premier plan.
        wakeDismisserProvider.overrideWithValue(LocalWakeNotifier()),
      ],
    ],
  );

  // **La qualité d'écoute atteint le lecteur ici, et nulle part ailleurs.**
  //
  // Ce câblage a d'abord été tenté dans `ContentPlayerView` : dès que l'écran
  // de lecture touchait la chaîne des réglages, son montage sous `flutter test`
  // se bloquait — processus à 0 % de CPU pendant dix minutes, donc une attente
  // de ressource, avant expiration. Le poser ici le sort définitivement du
  // chemin des tests d'écran : `main()` n'est jamais exécuté par le harnais.
  //
  // Sans lecteur réel (web sans HLS, plateforme non supportée), il n'y a rien à
  // plafonner et on ne branche rien.
  if (player != null) {
    // Un `StreamController` **non diffusé** : il tamponne, donc la valeur posée
    // par `fireImmediately` n'est pas perdue alors que le contrôleur ne s'y
    // abonne qu'à la ligne suivante.
    final targets = StreamController<int?>();
    container.listen<int?>(
      streamingBitrateTargetProvider,
      (_, next) => targets.add(next),
      fireImmediately: true,
    );
    final qualities = StreamController<MediaQuality>();
    container.listen<MediaQuality>(
      streamingQualityProvider,
      (_, next) => qualities.add(next),
      fireImmediately: true,
    );
    final cellular = StreamController<bool>();
    container.listen<bool>(
      onCellularProvider.select((v) => v.value ?? false),
      (_, next) => cellular.add(next),
      fireImmediately: true,
    );
    BitrateCapController(
      player: player,
      qualities: qualities.stream,
      onCellular: cellular.stream,
      targets: targets.stream,
    );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MaisonDuMiracleApp(),
    ),
  );
}

/// **Choisit le transport de réveil** (PRD D4), et rend `null` quand il n'y en a
/// pas — ce qui est un mode de fonctionnement normal et non une panne.
///
/// Trois sorties par `null`, et chacune est un vrai cas du parc :
///
/// 1. **sans backend** — il n'y a personne à qui déclarer une cible de réveil ;
/// 2. **plateforme hors jeu** — macOS, Linux, Windows ne sont pas du jeu fermé de
///    `POST /devices/tokens`, et le **web** n'a aucune application déclarée dans le
///    projet Firebase (`firebase_options.dart` y lève exprès). Écarté **ici**, à un
///    seul endroit, plutôt que rattrapé plus bas ;
/// 3. **Firebase n'a pas démarré** — et c'est aussi par là que passe l'Android
///    dé-googlé. `Firebase.initializeApp()` y réussit pourtant : c'est `getToken()`
///    qui ne rend rien, donc l'absence de cible, donc aucun enregistrement. Le
///    résultat est le même — pas de push, application intacte —, et c'est
///    exactement là que la tranche 4 (#99) branchera UnifiedPush : une branche de
///    plus dans cette fonction, et rien d'autre à reprendre.
///
/// L'ordre des deux appels du `try` compte : `onBackgroundMessage` **doit** être
/// posé avant que l'application ne commence à tourner, et il se pose une fois pour
/// toute la vie du processus. Le poser plus tard — à la première connexion, par
/// exemple — laisserait tomber les réveils reçus entre-temps.
Future<PushTransport?> _startPush() async {
  if (!AppEnv.useBackend) return null;

  final platform = devicePlatform();
  if (platform == null || platform == 'web') return null;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundWake);
    return FcmPushTransport();
  } catch (error, stackTrace) {
    // Même `try` que le lecteur : un transport qui ne démarre pas ne doit jamais
    // empêcher l'application de s'ouvrir. Une médiathèque muette vaut mieux qu'une
    // application qui refuse de s'ouvrir, et un téléphone sans réveil encore plus.
    debugPrint('Le réveil push n\'a pas démarré : $error\n$stackTrace');
    return null;
  }
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
        androidNotificationChannelName: 'Lecture des messages',
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
