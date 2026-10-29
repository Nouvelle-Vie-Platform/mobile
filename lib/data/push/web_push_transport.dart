/// **Le transport FCM du navigateur** (#283) — le second fichier du dépôt qui
/// connaisse Firebase, et le seul qui charge son SDK.
///
/// Même couture que `FcmPushTransport` derrière [PushTransport] : tout le reste
/// de l'application ne connaît que le contrat, et un test de source le vérifie
/// (`test/data/push/push_seam_test.dart`). Ce fichier **n'est importé par aucun
/// test** — il importe `dart:js_interop`, qui n'existe pas sur la VM —, et c'est
/// la porte `web_push.dart` qui l'isole.
///
/// ## Pourquoi un transport à part, et pas une branche dans `FcmPushTransport`
///
/// C'est le **même** transport au sens du serveur (`fcm`), et trois choses
/// diffèrent pourtant, dont deux sont le cœur de la tranche :
///
/// 1. **la permission ne se demande pas au démarrage.** Sur le web un refus est
///    quasi définitif et il emporte **tout** — sans permission, pas de jeton,
///    donc pas même le réveil silencieux (l'inverse du natif, où le réveil
///    passe quand l'affichage est refusé). [target] lit donc l'état courant et
///    ne demande **jamais** rien ; c'est [WebPushTransport.requestPermission]
///    qui demande, dans la foulée de l'installation ;
/// 2. **`onTokenRefresh` est un flux mort sur le web** — `firebase_messaging_web`
///    rend un `StreamController` que personne n'alimente (« deprecated on
///    web »). [targetChanges] est donc **le nôtre**, et c'est par lui que le
///    jeton obtenu après l'installation rejoint `PushEnrolment`, qui s'y est
///    abonné au démarrage. Aucune pièce à rebrancher ;
/// 3. **il faut une clé VAPID**, qui n'existe sur aucune autre plateforme.
///
/// ## Le SDK JS est servi depuis notre origine, et c'est mesuré
///
/// `firebase_core_web` **injecte** `firebase-app.js` et `firebase-messaging.js`
/// depuis `https://www.gstatic.com/firebasejs/<version>/` dès
/// `Firebase.initializeApp()` — ce que `web/WEB_ASSETS.md` interdit (« aucun
/// CDN »), et ce que la CSP de l'origine refuserait **deux fois** : l'origine
/// `gstatic.com` n'est pas dans `script-src`, et le paquet charge ces modules
/// par un `<script>` **en ligne** qu'il fabrique lui-même.
///
/// Il a une porte de sortie, écrite dans son code (`firebase_core_web-3.12.0`,
/// `lib/src/firebase_core_web.dart`) :
///
/// ```dart
///   // If Firebase is already available, core has already been initialized
///   // (or the user has added the scripts to their html file).
///   if (globalContext.getProperty('firebase_core'.toJS) != null) return;
/// ```
///
/// [_loadSdkFromOurOrigin] remplit donc `window.firebase_core` et
/// `window.firebase_messaging` — les deux noms que les `@JS('firebase_core')` et
/// `@JS('firebase_messaging')` des paquets lisent — avec les modules importés
/// depuis `web/firebase/`, **avant** d'appeler `Firebase.initializeApp()`. Rien
/// n'est alors injecté et rien ne sort de l'origine. Les deux fichiers sont
/// versionnés et empreintés comme `sqlite3.wasm` et `hls.min.js`
/// (`tool/web_assets.sh`), et `make push-probe` prouve dans un Chrome sans tête
/// qu'aucune requête ne part vers `gstatic.com`.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../firebase_options.dart';
import 'push_transport.dart';

/// **LA CLÉ VAPID DE L'APPLICATION WEB — à remplir.**
///
/// D'où elle vient : console Firebase → ⚙️ *Paramètres du projet* → onglet
/// *Cloud Messaging* → section *Configuration Web* → **Certificats push web** →
/// « Générer une paire de clés ». La valeur à recopier ici est la **clé
/// publique** (87 caractères, base64url, commence par `B`). Elle n'est pas un
/// secret : elle part dans le bundle servi à chaque navigateur, et c'est le
/// serveur FCM qui vérifie la clé privée, qui reste chez Google.
///
/// **Ce qui se passe tant qu'elle est vide, et c'est délibéré** : aucun jeton
/// n'est demandé, **aucune permission n'est demandée** (brûler l'unique
/// autorisation d'un fidèle pour un jeton impossible serait le pire usage de
/// ce moment-là), aucune exception n'est levée, et chaque refus laisse une
/// trace `[push]` dans la console. L'app web tourne alors exactement comme
/// avant cette tranche — l'installation, la médiathèque, l'antenne et le
/// hors-ligne n'en dépendent pas.
///
/// Une fois posée : rien d'autre à changer. `make push-probe` la lit.
/// **La borne du jeton**, et elle n'est pas décorative.
///
/// Le SDK de Firebase réessaie son enregistrement avec un délai croissant : sur
/// un réseau qui ne répond pas, `getToken()` peut ne **jamais** rendre la main.
/// L'enregistrement resterait alors pendu pour toute la session — ni jeton, ni
/// échec, donc **aucune reprise**, puisque c'est le démarrage suivant qui
/// réessaie. Mesuré le 29/10/2026 par `make push-probe`, dont la sonde n'a
/// jamais rendu son verdict dès que la clé VAPID a été posée : Google y est
/// injoignable par construction.
///
/// Même raison que `kRadioHandshakeTimeout` pour l'antenne, et même forme : une
/// constante nommée à un seul endroit. **Valeur à confirmer.** La dépasser ne
/// coûte qu'un réveil, et le démarrage suivant retente.
const Duration kWebPushTokenTimeout = Duration(seconds: 15);

const String kWebPushVapidKey =
    'BIyite0_RrrMVJnVfxXa_Zrl_1BumIwunxEP_WaM7sGn9HlAslQYGoVGaFtLZaZb1SeIV9vpHdq0_xog5S_KddY';

/// **Le nom des deux modules du SDK dans `window`**, tels que
/// `firebase_core_web` et `firebase_messaging_web` les lisent par leurs
/// annotations `@JS(...)`. Les changer casse la porte de sortie décrite en tête
/// de fichier, sans qu'aucune compilation ne s'en aperçoive.
const String _coreGlobal = 'firebase_core';
const String _messagingGlobal = 'firebase_messaging';

/// Le dossier des deux fichiers, relatif au `<base href>` de la page.
const String _sdkDirectory = 'firebase/';

/// **Monte le push du navigateur**, ou rend `null` — ce qui est un mode de
/// fonctionnement normal et non une panne, comme sur mobile.
///
/// Appelée par `main.dart` (par la porte `web_push.dart`) et par la sonde.
Future<({PushTransport transport, PushPermissionRequest? askPermission})?>
    createWebPush() async {
  try {
    await _loadSdkFromOurOrigin();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error, stackTrace) {
    // Navigateur sans `import()` dynamique, fichiers du SDK absents du bundle,
    // origine qui refuse le module : aucun n'empêche l'application de s'ouvrir.
    debugPrint('[push] le push web n\'a pas démarré : $error\n$stackTrace');
    return null;
  }

  final transport = WebPushTransport();
  return (transport: transport, askPermission: transport.requestPermission);
}

/// Charge les deux modules **depuis notre origine** et les pose là où les
/// paquets les cherchent. Voir l'en-tête du fichier pour le pourquoi.
Future<void> _loadSdkFromOurOrigin() async {
  // Déjà chargés : un rechargement à chaud, ou une seconde initialisation.
  // `firebase_core_web` fait exactement ce test, et pour la même raison.
  if (globalContext.getProperty(_coreGlobal.toJS) != null) return;

  // Résolu contre le `<base href>` de la page et non contre l'URL du script :
  // c'est la même base que celle par laquelle `firebase-messaging.js` importera
  // `./firebase-app.js`, donc les deux modules n'existent qu'une fois dans la
  // carte du navigateur — condition pour que le module de messagerie voie
  // l'application que `Firebase.initializeApp()` aura créée dans le cœur.
  final base = '${web.document.baseURI}$_sdkDirectory';

  // Le cœur d'abord : `firebase-messaging.js` l'importe statiquement, et le
  // charger en parallèle ferait courir deux évaluations du même module.
  globalContext[_coreGlobal] =
      await importModule('${base}firebase-app.js'.toJS).toDart;
  globalContext[_messagingGlobal] =
      await importModule('${base}firebase-messaging.js'.toJS).toDart;
}

class WebPushTransport implements PushTransport {
  WebPushTransport({
    FirebaseMessaging? messaging,
    String vapidKey = kWebPushVapidKey,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _vapidKey = vapidKey;

  final FirebaseMessaging _messaging;
  final String _vapidKey;

  /// Les cibles obtenues **après** le démarrage — c'est-à-dire après que la
  /// permission a été accordée dans la foulée de l'installation. `PushEnrolment`
  /// y est abonné depuis le démarrage : le jeton part donc vers
  /// `POST /devices/tokens` sans que personne n'ait à rappeler qui que ce soit.
  final StreamController<String> _targets =
      StreamController<String>.broadcast();

  @override
  String get transport => kFcmTransport;

  @override
  Stream<String> get targetChanges => _targets.stream;

  /// Les réveils reçus **onglet ouvert**. Le SDK les livre par son propre
  /// `onMessage` ; le bloc `data` est lu par `push_wake.dart`, comme partout.
  @override
  Stream<Map<String, Object?>> get wakes =>
      FirebaseMessaging.onMessage.map((message) => message.data);

  /// **Ne demande jamais la permission** — voir le point 1 de l'en-tête. Rend
  /// `null` tant qu'elle n'est pas accordée, ce qui est le cas au tout premier
  /// démarrage et le reste tant que l'app web n'est pas installée.
  @override
  Future<String?> target() async {
    if (_vapidKey.isEmpty) {
      _trace('clé VAPID absente — aucun jeton web ne sera demandé');
      return null;
    }
    try {
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        _trace(
            'permission ${settings.authorizationStatus.name} — pas de jeton');
        return null;
      }
      return await _token();
    } on Object catch (error) {
      // Navigateur sans `Notification`, onglet non sécurisé : tous normaux.
      _trace('état de permission illisible : $error');
      return null;
    }
  }

  /// **La permission, demandée dans la foulée de l'installation** (#283), puis
  /// le jeton poussé dans [targetChanges] pour qu'il soit enregistré.
  ///
  /// Ne lève jamais : c'est `InstallBanner` qui l'appelle, et un bandeau
  /// informatif ne doit pas pouvoir poser un écran rouge.
  Future<void> requestPermission() async {
    if (_vapidKey.isEmpty) {
      // **On ne demande pas une permission qu'on ne saurait pas employer** : un
      // refus web est quasi définitif, et le moment de l'installation ne se
      // rejoue pas. Mieux vaut ne rien demander et le dire.
      _trace('clé VAPID absente — permission NON demandée');
      return;
    }
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        // Un refus ne casse rien : l'app web continue sans push, et sans
        // synchronisation réveillée. Rien à réessayer — le navigateur ne
        // redemandera pas.
        _trace('permission ${settings.authorizationStatus.name} — sans push');
        return;
      }
      final token = await _token();
      if (token == null) return;
      _targets.add(token);
    } on Object catch (error) {
      _trace('permission impossible à demander : $error');
    }
  }

  /// Sans `serviceWorkerScriptPath` : le SDK enregistre lui-même
  /// `/firebase-messaging-sw.js` sur sa propre portée
  /// (`/firebase-cloud-messaging-push-scope`), distincte de celle du worker de
  /// Flutter et de celle de `sw-offline.js`. Trois workers, trois portées.
  Future<String?> _token() async {
    try {
      return await _messaging
          .getToken(vapidKey: _vapidKey)
          .timeout(kWebPushTokenTimeout);
    } on Object catch (error) {
      // Permission retirée entre-temps, clé VAPID refusée par FCM, réseau
      // absent : un réveil de perdu, pas une fonctionnalité.
      _trace('aucun jeton web : $error');
      return null;
    }
  }

  void _trace(String message) => debugPrint('[push] $message');
}
