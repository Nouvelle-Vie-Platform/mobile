/// **Le transport FCM** — et le seul fichier du dépôt qui connaisse Firebase.
///
/// Même couture que `JustAudioContentPlayer` derrière `ContentPlayer` : tout le
/// reste de l'application ne connaît que [PushTransport], et un test de source le
/// vérifie (`test/data/push/push_seam_test.dart`). C'est cette couture qui rendra la
/// tranche 4 (UnifiedPush, #99) une addition — un fichier de plus à côté, et une
/// branche de plus au choix de `main.dart`.
///
/// Ce fichier **n'est importé par aucun test**, exactement comme `main.dart` : un
/// canal de greffon Firebase lève sous `flutter test`, et le reste du module de
/// push s'éprouve entièrement sans lui.
///
/// ## Quatre points qui se ratent en silence
///
/// 1. **Le point d'entrée du réveil de fond doit être une fonction de niveau
///    bibliothèque annotée `@pragma('vm:entry-point')`.** Une fermeture, une méthode
///    d'instance ou une fonction locale ne survit pas à la compilation AOT : l'isolate
///    de fond ne la retrouverait pas, et le réveil serait **perdu sans trace**.
/// 2. **iOS : pas de clé APNs, donc aucun push.** Sur iPhone, FCM passe
///    obligatoirement par APNs, et la clé exige un compte Apple Developer Program
///    qui n'est pas pris (PRD §6, D8). `getToken()` y rend d'ailleurs souvent `null`
///    tant qu'aucun jeton APNs n'est arrivé — ce n'est **pas** un défaut de ce
///    fichier, et il n'y a rien à diagnostiquer. Le chemin est écrit entier et
///    s'allumera le jour où la clé sera téléversée.
/// 3. **Android dé-googlé : la détection se fait par le résultat**, pas par une
///    sonde. `Firebase.initializeApp()` réussit sans Play Services ; c'est
///    `getToken()` qui échoue. Interroger `GoogleApiAvailability` demanderait une
///    dépendance native de plus pour une réponse qui mentirait encore (Play Services
///    présents mais l'appareil non enregistré auprès de Google). On tente, et
///    l'absence de cible **est** la réponse : pas de push, application intacte
///    (PRD D4, « dégradé propre »). La tranche 4 branchera son transport exactement
///    là, sur ce `null`.
/// 4. **La permission est demandée ici et pas ailleurs.**
///    `FirebaseMessaging.requestPermission()` est ce qui, sur iOS, autorise
///    l'enregistrement auprès d'APNs : sans elle, pas de jeton du tout. Sur Android
///    13+, la permission `POST_NOTIFICATIONS` est déjà demandée au démarrage par
///    `requestPlaybackNotificationPermission()` — c'est **la même** permission
///    système, et la redemander afficherait deux fenêtres l'une sur l'autre au
///    premier lancement. Un refus ne coûte que la notification : le réveil
///    silencieux, lui, arrive sans permission.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'push_background.dart';
import 'push_transport.dart';

/// **Le point d'entrée du réveil d'une application fermée.**
///
/// Il ne décide de rien : il initialise Firebase pour cet isolate, aplatit le
/// message en une carte, et passe la main à `handleBackgroundWake`, qui ignore
/// Firebase. Voir le point 1 de l'en-tête pour l'annotation.
@pragma('vm:entry-point')
Future<void> fcmBackgroundWake(RemoteMessage message) async {
  // L'isolate de fond est neuf : l'app Firebase de `main()` n'y existe pas.
  // `Firebase.initializeApp` est idempotent, et le greffon de messagerie exige
  // qu'elle soit là avant de rendre la main.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error) {
    // On continue quand même : le réveil n'a besoin que du bloc `data` déjà reçu,
    // du magasin et du client HTTP. Firebase n'y sert plus à rien.
    debugPrint('[push] Firebase indisponible dans l\'isolate de fond : $error');
  }
  await handleBackgroundWake(message.data);
}

class FcmPushTransport implements PushTransport {
  FcmPushTransport({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  String get transport => kFcmTransport;

  @override
  Future<String?> target() async {
    try {
      // iOS et macOS : c'est elle qui déclenche l'enregistrement auprès d'APNs.
      // Sur Android elle rend l'état courant sans rien demander (la permission
      // d'exécution se demande ailleurs — point 4 de l'en-tête).
      final settings = await _messaging.requestPermission();
      // On ne s'arrête **pas** sur un refus : un message `data` silencieux réveille
      // l'application sans aucune permission d'affichage, et c'est précisément le
      // réveil qui nous intéresse. Seule la notification locale s'en trouvera
      // muette, et personne n'en meurt.
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[push] notifications refusées — le réveil reste possible');
      }
      return await _messaging.getToken();
    } on Object catch (error) {
      // Pas de Play Services, pas de jeton APNs, réseau absent : tous normaux.
      debugPrint('[push] aucun jeton FCM : $error');
      return null;
    }
  }

  @override
  Stream<String> get targetChanges => _messaging.onTokenRefresh;

  @override
  Stream<Map<String, Object?>> get wakes =>
      FirebaseMessaging.onMessage.map((message) => message.data);
}
