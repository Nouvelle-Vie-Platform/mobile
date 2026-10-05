import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/app_platform.dart';
import '../../data/app_version.dart';
import '../../data/devices/device_identity.dart';
import 'accept_language_header.dart';
import 'app_version_header.dart';

/// URL du backend, injectée au build.
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3333
/// flutter build ipa --dart-define=API_BASE_URL=https://api.example.org
/// ```
///
/// La valeur par défaut ne vaut **que pour le développement** : `localhost`
/// désigne la machine hôte depuis le simulateur iOS, mais l'appareil lui-même
/// depuis un téléphone physique. Tester sur un vrai appareil se fait donc en
/// passant `--dart-define`, jamais en éditant ce fichier — une URL de dev codée
/// en dur finit par partir en production.
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://eenv.brainsial.com',
);

/// Clé de stockage sécurisé du token d'authentification.
const String _kTokenKey = 'auth_token';

/// Clé de stockage sécurisé de la **nature** du porteur rangé à côté.
///
/// **Un seul emplacement de jeton, un marqueur à côté** — et non deux clés de
/// jeton (« membre » / « appareil ») : le coffre ne peut alors pas contenir deux
/// jetons à la fois, donc aucun code ne peut choisir le mauvais, ni « retomber »
/// sur un jeton d'appareil resté là pendant qu'une personne est connectée. Le
/// jeton, lui, reste rangé **tel quel** : le contrat le dit opaque, et y coudre
/// un préfixe (`device:oat_…`) ferait du coffre un format à décoder.
///
/// Ce que ça rend impossible, au prix d'une seconde lecture du coffre par
/// requête : deux porteurs simultanés, et un jeton qui change de nature sans
/// que le marqueur bouge.
const String _kTokenKindKey = 'auth_token_kind';

/// Qui parle au serveur : une personne connectée, ou un appareil anonyme.
///
/// Le marqueur du coffre et l'estampille d'`extra` portent cette valeur ; toute
/// la réaction au **401** en découle (voir [UnauthorizedInterceptor]).
enum AuthTokenKind {
  /// Jeton émis par `POST /auth/verify-code` — une personne s'est connectée.
  member,

  /// Jeton émis par `POST /devices/anonymous` — personne ne s'est connecté.
  device;

  /// Lecture **prudente** d'un marqueur : tout ce qui n'est pas explicitement
  /// `device` vaut `member`.
  ///
  /// Le défaut n'est pas arbitraire. Les deux désaccords possibles entre le
  /// marqueur et le jeton n'ont pas le même coût : un jeton d'appareil pris pour
  /// un jeton de membre éjecte vers `/auth` — visible, et l'on peut se
  /// reconnecter ; un jeton de **membre** pris pour un jeton d'appareil se
  /// ferait **écraser en silence** par un jeton d'appareil, déconnectant
  /// quelqu'un sans le lui dire. On se trompe donc toujours du premier côté.
  ///
  /// Corollaire pour les écritures ([ApiClient.saveToken]) : la valeur prudente
  /// (`member`) s'écrit **avant** le jeton, la valeur permissive (`device`)
  /// **après** — une panne entre les deux écritures laisse alors toujours l'état
  /// prudent. Corollaire pour les installations existantes : un coffre qui ne
  /// porte que `auth_token` (avant cette version) décrit un membre, ce qui est
  /// exactement ce qu'il est.
  static AuthTokenKind parse(String? raw) =>
      raw == device.name ? device : member;
}

/// Clé d'`extra` : la nature du porteur **réellement posé sur cette requête**,
/// estampillée par `_AuthInterceptor`.
///
/// L'estampille voyage avec la requête au lieu d'être relue au retour du 401, et
/// c'est le cœur du mécanisme : entre l'envoi et la réponse, le coffre peut
/// avoir changé de main — une connexion aboutie pendant qu'une requête d'invité
/// était en vol. Relire le coffre à ce moment-là ferait juger la requête sur un
/// état qui n'est plus le sien.
const String kAuthTokenKindExtra = 'authTokenKind';

/// Clé d'`extra` : cette requête **est déjà un rejeu**. Elle ne peut plus
/// déclencher de renouvellement — c'est la borne de la boucle.
const String kDeviceSessionReplayExtra = 'deviceSessionReplay';

/// Clé d'`extra` : cette requête **est** l'ouverture d'une session d'appareil
/// (`POST /devices/anonymous`).
///
/// Deux effets, tous deux nécessaires : `_AuthInterceptor` ne lui pose **aucun**
/// porteur — un jeton mort ne doit pas pouvoir empêcher d'en obtenir un vivant,
/// et la route est publique, le porteur n'y apporterait rien — et un 401 sur
/// elle n'éjecte personne et ne relance rien.
const String kDeviceSessionRequestExtra = 'deviceSessionRequest';

/// Clé d'`extra` : cette requête **portait un porteur** (`Authorization`) au
/// moment où elle est partie.
///
/// Posée par `_AuthInterceptor` sur **chaque** requête (valeur `true` ou
/// `false`), elle répond à une question qu'aucune autre estampille ne porte :
/// non pas *quelle nature* de porteur, mais *s'il y en avait un*. Le 401 en a
/// besoin, car il ne dit pas la même chose selon la réponse :
///
/// - **un porteur** a été envoyé puis refusé → l'éjecter vers `/auth` (membre)
///   ou le renouveler (appareil) ;
/// - **aucun porteur** n'est parti → le serveur n'a rien eu à refuser, et son
///   « non » ne dit **rien du coffre**. Un 401 sur une requête nue — le tout
///   premier `/events` d'un invité, avant que `POST /devices/anonymous` ne soit
///   revenu — ne doit donc **jamais purger le coffre** : la session d'appareil
///   peut s'y être rangée pendant que la requête était en vol, et la purger la
///   transformerait en panne durable. Sur l'**émulateur Android**, plus lent à
///   écrire son coffre, cette course est systématique — d'où ces trois lignes.
const String kAuthTokenAttachedExtra = 'authTokenAttached';

/// Ce que l'intercepteur 401 attend du **mode invité**, et rien de plus.
///
/// Le contrat vit ici — dans la couche réseau — et son implémentation dans
/// `lib/data/devices/` : la couche basse déclare ce dont elle a besoin, elle
/// n'importe pas la couche haute (même raison que [ApiClient.onUnauthorized]).
abstract interface class DeviceSessionGuard {
  /// Obtient un jeton d'appareil frais et le range dans le coffre.
  ///
  /// Rend `true` si le coffre porte un jeton d'appareil utilisable au retour.
  /// **Ne lève jamais** : un échec de renouvellement n'est pas une erreur à
  /// montrer, c'est une requête qui échoue.
  ///
  /// L'implémentation doit **sérialiser** les appels concurrents : plusieurs
  /// requêtes peuvent recevoir un 401 dans la même milliseconde au démarrage, et
  /// il ne doit en partir qu'**un** renouvellement.
  Future<bool> renew();

  /// Rejoue une requête avec le jeton frais.
  Future<Response<dynamic>> replay(RequestOptions options);
}

/// Client HTTP global, pré-configuré avec :
/// - l'URL de base du backend ([kBaseUrl], injectée par `--dart-define`)
/// - Headers JSON par défaut
/// - Intercepteur de **présentation** : annonce la version du binaire, la
///   plateforme et l'identifiant d'appareil sur toutes les requêtes
///   ([AppVersionHeaderInterceptor])
/// - Intercepteur de **langue** : `Accept-Language`, la langue que l'interface
///   affiche, relue à chaque requête ([AcceptLanguageInterceptor])
/// - Intercepteur d'auth : injecte automatiquement le token Bearer si présent
/// - Déballage de l'enveloppe `data` posée par le serveur
/// - Traitement global du 401 (purge du token + [onUnauthorized])
/// - Logs en mode debug
class ApiClient {
  ApiClient._() {
    ensureSecureBaseUrl();

    _dio = Dio(
      BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      // **En tête de chaîne, et purement additif.** Il ne lit rien de ce que
      // les trois suivants posent, et aucun d'eux ne lit ce qu'il pose ; sa
      // place dit seulement que rien ne doit pouvoir partir sans nom. Les
      // lecteurs sont relus à chaque requête, comme le garde du 401 :
      // `ApiClient.instance` naît avant que quoi que ce soit ait pu le câbler.
      AppVersionHeaderInterceptor(
        version: () => appVersion,
        platform: () => appPlatform,
        identity: () => deviceIdentity,
      ),
      // **La langue de l'interface**, relue à chaque requête et jamais retenue :
      // elle peut changer en cours de session. Même motif de lecteur que
      // ci-dessus, et même place : rien ne dépend de lui dans la chaîne.
      AcceptLanguageInterceptor(language: () => interfaceLanguage?.call()),
      _AuthInterceptor(_storage),
      unwrapEnvelopeInterceptor,
      // Le garde est lu **à chaque 401**, jamais capturé à la construction :
      // `ApiClient.instance` naît avant que quoi que ce soit ait pu le câbler.
      UnauthorizedInterceptor(
        _handleUnauthorized,
        deviceSession: () => deviceSession,
      ),
      // Uniquement en debug : ces logs contiennent les corps de requête et le
      // header `Authorization`, qui n'ont rien à faire dans les journaux d'un
      // appareil de production.
      if (kDebugMode)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => debugPrint('[API] $o'),
        ),
    ]);
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  /// Appelé quand le serveur répond **401** sur n'importe quelle requête. Le
  /// token vient d'être purgé ; il reste à ramener l'utilisateur à `/auth`.
  ///
  /// Ce point d'accroche existe pour que la couche réseau **ignore** Riverpod
  /// et go_router : c'est la couche application qui le câble au démarrage
  /// (`MaisonDuMiracleApp`), là où le routeur et les providers existent. Les
  /// couches basses ne connaissent pas les couches hautes.
  void Function()? onUnauthorized;

  /// Le **mode invité**, s'il est câblé : ce qui sait renouveler un jeton
  /// d'appareil en silence (`HttpDeviceRepository.wire`, appelé au démarrage).
  ///
  /// Tant qu'il vaut `null`, un 401 se comporte **exactement** comme avant cette
  /// version, y compris sur une requête estampillée « appareil » : sans personne
  /// pour renouveler, se taire rendrait l'application muette pour toujours,
  /// alors que l'éjection vers `/auth` mène au moins quelque part.
  DeviceSessionGuard? deviceSession;

  /// **Ce que l'en-tête de version annonce**, et d'où il le tient.
  ///
  /// Deux champs mutables plutôt que deux paramètres de construction, pour la
  /// raison d'[onUnauthorized] et de [deviceSession] : le singleton naît au
  /// premier accès, avant tout câblage. Les valeurs par défaut sont celles de
  /// production ; seuls les tests les remplacent, pour poser une version fixe
  /// sans toucher au canal de plugin.
  ///
  /// Ce n'est **pas** une seconde vérité à côté d'`appVersionReaderProvider`
  /// (`lib/state/app_version_providers.dart`) : les deux servent le même
  /// `PackageInfoAppVersionReader`, qui lit le même binaire. Ils sont séparés
  /// parce que la couche réseau ignore Riverpod — elle ne connaît pas les
  /// couches hautes, et un conteneur de providers n'existe pas forcément quand
  /// la première requête part.
  AppVersionReader appVersion = const PackageInfoAppVersionReader();

  /// La plateforme et son système — voir [appVersion] pour le pourquoi du champ.
  AppPlatformReader appPlatform = const RuntimeAppPlatformReader();

  /// **L'identité de l'appareil — un seul exemplaire pour toute l'application.**
  ///
  /// L'en-tête `X-Device-Id` la lit à chaque requête, et
  /// `HttpDeviceRepository` l'utilise par défaut pour ouvrir une session : les
  /// deux doivent lire **le même** objet, sinon deux instances pourraient, à la
  /// toute première ouverture, fabriquer deux identifiants dont un seul serait
  /// rangé — et le corps de `POST /devices/anonymous` ne dirait pas la même
  /// chose que son en-tête.
  ///
  /// Champ mutable pour la raison d'[appVersion] : le singleton naît avant tout
  /// câblage, et seuls les tests le remplacent (le remplacer périme aussi la
  /// valeur retenue par l'instance précédente).
  ///
  /// ⚠️ Elle **mesure**, elle n'autorise rien (ADR-0040) : le jeton rangé dans
  /// le coffre reste la seule preuve d'identité.
  DeviceIdentity deviceIdentity = DeviceIdentity();

  /// **La langue que l'interface affiche**, telle que l'en-tête
  /// `Accept-Language` l'annonce (#131) — `fr`, `en` ou `ee`.
  ///
  /// Un **lecteur**, et non une valeur : il est appelé à chaque requête, pour
  /// qu'un changement de langue en cours de session soit suivi dès la requête
  /// suivante. Câblé au montage de l'application (`MaisonDuMiracleApp`), comme
  /// [onUnauthorized] et pour la même raison : la couche réseau ignore Riverpod,
  /// et le singleton naît avant tout câblage.
  ///
  /// Ce n'est **pas** une seconde vérité : l'application y branche
  /// `contentLocaleProvider`, la copie de la locale que `MaterialApp` a
  /// réellement résolue. Rien ici ne résout de langue.
  ///
  /// Tant qu'il vaut `null` (avant le montage, ou dans un test qui ne le pose
  /// pas), l'en-tête est **absent** et le serveur répond en français.
  String? Function()? interfaceLanguage;

  /// Refuse une URL de base en HTTP clair dans un build **release**.
  ///
  /// Un `assert` ne suffirait pas : il est retiré à la compilation en release,
  /// c'est-à-dire exactement dans le build qu'il faut protéger. D'où un vrai
  /// contrôle, qui lève. Le token Bearer ouvre le compte pendant 90 jours
  /// glissants : il ne doit jamais transiter en clair.
  ///
  /// Appelé au démarrage (`main`) pour échouer tout de suite, et à la création
  /// du client pour qu'aucun chemin ne puisse le contourner.
  ///
  /// [url] et [releaseMode] ne sont paramétrables que pour les tests : en
  /// production les deux valeurs par défaut sont les bonnes.
  static void ensureSecureBaseUrl({
    String url = kBaseUrl,
    bool releaseMode = kReleaseMode,
  }) {
    if (!releaseMode || url.startsWith('https://')) return;
    throw StateError(
      'API_BASE_URL doit être en HTTPS dans un build release (reçu : "$url"). '
      'Le token Bearer y transiterait en clair, or il ouvre le compte pendant '
      '90 jours. Relancer le build avec '
      '--dart-define=API_BASE_URL=https://mon-domaine.example',
    );
  }

  /// Réaction au 401, dans l'ordre : purger le token (personne d'autre ne le
  /// fera — l'appel en cours, lui, échoue), puis prévenir la couche
  /// application.
  Future<void> _handleUnauthorized() async {
    await deleteToken();
    onUnauthorized?.call();
  }

  // ── Token helpers ────────────────────────────────────────────────────────

  /// Persiste le token — **un seul emplacement**, quelle que soit sa nature :
  /// ranger un jeton d'appareil remplace le jeton de membre, et l'inverse.
  ///
  /// L'ordre des deux écritures suit la règle d'[AuthTokenKind.parse] : la valeur
  /// prudente (`member`) d'abord, la permissive (`device`) en dernier. Le coffre
  /// n'a pas de transaction ; c'est ce qui fait qu'une interruption entre les
  /// deux écritures ne peut pas donner « jeton de membre marqué appareil ».
  Future<void> saveToken(
    String token, {
    AuthTokenKind kind = AuthTokenKind.member,
  }) async {
    if (kind == AuthTokenKind.member) {
      await _storage.write(key: _kTokenKindKey, value: kind.name);
      await _storage.write(key: _kTokenKey, value: token);
      return;
    }
    await _storage.write(key: _kTokenKey, value: token);
    await _storage.write(key: _kTokenKindKey, value: kind.name);
  }

  /// Supprime le token **et son marqueur** : un marqueur orphelin décrirait la
  /// nature d'un porteur qui n'existe plus.
  Future<void> deleteToken() async {
    await _storage.delete(key: _kTokenKey);
    await _storage.delete(key: _kTokenKindKey);
  }

  /// Lit le token courant (null si absent).
  Future<String?> readToken() => _storage.read(key: _kTokenKey);

  /// Lit la nature du porteur courant. Marqueur absent → [AuthTokenKind.member]
  /// (le défaut prudent, cf. [AuthTokenKind.parse]).
  Future<AuthTokenKind> readTokenKind() async =>
      AuthTokenKind.parse(await _storage.read(key: _kTokenKindKey));

  /// Marque le coffre comme **attendant** une session d'appareil, sans jeton.
  ///
  /// C'est l'état d'après une déconnexion dont la reprise de jeton a échoué
  /// (avion, serveur injoignable). Sans lui, la requête suivante partirait sans
  /// porteur, son 401 serait jugé « membre », et un invité se retrouverait devant
  /// l'écran de connexion — précisément ce que le mode invité supprime. Avec lui,
  /// ce 401 déclenche un renouvellement silencieux : l'échec réseau se rattrape
  /// de lui-même au prochain appel, sans rester sans jeton pour toujours.
  Future<void> expectDeviceSession() =>
      _storage.write(key: _kTokenKindKey, value: AuthTokenKind.device.name);
}

/// Intercepteur Dio : ajoute automatiquement `Authorization: Bearer <token>`
/// à chaque requête si un token est disponible en stockage sécurisé.
///
/// Il **estampille** aussi la requête avec la nature du porteur
/// ([kAuthTokenKindExtra]) — y compris quand il n'y a **pas** de jeton à poser :
/// un coffre marqué « appareil » sans jeton est un renouvellement en attente, et
/// c'est le 401 de cette requête-là qui le déclenchera.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // L'ouverture d'une session d'appareil part **nue** : voir
    // [kDeviceSessionRequestExtra].
    if (options.extra[kDeviceSessionRequestExtra] == true) {
      options.headers.remove('Authorization');
      handler.next(options);
      return;
    }

    options.extra[kAuthTokenKindExtra] = AuthTokenKind.parse(
      await _storage.read(key: _kTokenKindKey),
    );

    final token = await _storage.read(key: _kTokenKey);
    // **Le porteur a-t-il réellement été posé ?** Note sur la requête, pour que
    // le 401 sache distinguer « jeton refusé » de « requête partie nue » — voir
    // [kAuthTokenAttachedExtra]. Sans cela, le 401 du tout premier `/events`
    // d'un invité purgerait le jeton d'appareil rangé entre-temps.
    options.extra[kAuthTokenAttachedExtra] = token != null;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      // Un rejeu réutilise les mêmes `RequestOptions` : l'en-tête d'un jeton
      // disparu du coffre y traînerait encore.
      options.headers.remove('Authorization');
    }
    handler.next(options);
  }
}

/// Déballe l'enveloppe `data` que le serveur pose sur **toutes** ses réponses
/// (sérialiseur global monté sur `HttpContext`, partagé par ses modules).
///
/// Le déballage a lieu **une seule fois, ici** : les repositories — auth
/// aujourd'hui, feed / médiathèque / synchro demain — reçoivent le contenu à
/// plat et n'ont rien à savoir de l'enveloppe.
///
/// La condition est volontairement étroite — **une seule clé, nommée `data`** :
/// - `{data: {...}}` → déballé ;
/// - `{data: [...], meta: {...}}` (réponse paginée) → **intact** : `meta` porte
///   une information qu'on perdrait en déballant ;
/// - `{id: ..., name: ...}` (corps déjà à plat) → **intact**.
///
/// Exposé (plutôt que privé) pour être testable sans réseau.
@visibleForTesting
final Interceptor unwrapEnvelopeInterceptor = InterceptorsWrapper(
  onResponse: (res, handler) {
    final body = res.data;
    if (body is Map && body.length == 1 && body.containsKey('data')) {
      res.data = body['data'];
    }
    handler.next(res);
  },
);

/// Intercepteur Dio : traite le **401** une fois pour toutes.
///
/// Un 401 n'est pas une erreur métier : il dit que le token n'est plus valide
/// (révoqué, ou 90 jours d'inactivité). On le purge et on prévient la couche
/// application via [ApiClient.onUnauthorized], au lieu de laisser chaque
/// repository — auth, feed, médiathèque, synchro — remonter une `DioException`
/// brute jusqu'à l'UI.
///
/// L'erreur poursuit malgré tout sa route (`handler.next`) : l'appel en cours
/// doit échouer, il n'a simplement plus à décider du sort du token.
///
/// [_onUnauthorized] est injecté (et non lu sur [ApiClient]) pour rendre
/// l'intercepteur testable sans réseau ni stockage sécurisé.
///
/// ## Deux natures de porteur, deux réactions
///
/// Le comportement ci-dessus est celui d'un jeton de **membre**, et il ne change
/// pas d'un octet : quand la personne s'est connectée, un 401 veut dire que sa
/// session est finie, et la voir revenir à `/auth` est la bonne réponse.
///
/// Un jeton d'**appareil** n'a personne à qui demander de se reconnecter : son
/// 401 se **renouvelle en silence** — nouveau jeton pour le même `deviceId`,
/// requête rejouée, rien à l'écran. Un invité dont le jeton a expiré ne doit
/// jamais tomber sur l'écran de connexion.
///
/// La nature se lit sur l'**estampille de la requête** ([kAuthTokenKindExtra]),
/// posée par `_AuthInterceptor` au moment où il posait le porteur — pas sur le
/// coffre au retour du 401, qui peut avoir changé entre-temps.
///
/// ## Requête partie **nue** : jamais « membre »
///
/// Quand aucun porteur n'a été posé ([kAuthTokenAttachedExtra]), la requête
/// est celle d'un **invité**, quelle que soit l'estampille de nature : on ne
/// purge pas le coffre — un 401 sans porteur ne dit rien de ce qu'il contient —
/// et, si un mode invité est câblé, on renouvelle puis on rejoue. Voir la
/// première branche d'[onError].
///
/// ## Les deux bornes
///
/// 1. **La boucle.** Un renouvellement qui échoue, ou un rejeu qui échoue à son
///    tour, ne relance rien : [kDeviceSessionReplayExtra] marque le rejeu et
///    [kDeviceSessionRequestExtra] marque le renouvellement lui-même. Chaque
///    requête d'origine vaut donc **au plus un** renouvellement et **au plus un**
///    rejeu, et l'échec du rejeu remonte tel quel à l'appelant.
/// 2. **Les requêtes concurrentes.** La sérialisation appartient au garde
///    ([DeviceSessionGuard.renew]) : cinq 401 simultanés au démarrage doivent
///    donner **un** jeton, pas cinq appareils dans le compteur du serveur.
///
/// Rejouer une écriture est sans danger : un 401 est refusé **avant** tout
/// traitement, la première tentative n'a donc rien produit côté serveur.
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor(
    this._onUnauthorized, {
    DeviceSessionGuard? Function()? deviceSession,
  }) : _deviceSession = deviceSession ?? _noDeviceSession;

  final Future<void> Function() _onUnauthorized;

  /// Lu à chaque 401 : le garde se câble **après** la naissance du client.
  final DeviceSessionGuard? Function() _deviceSession;

  static DeviceSessionGuard? _noDeviceSession() => null;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    final guard = _deviceSession();
    // **Une requête partie sans porteur est une requête d'invité**, même quand
    // aucune estampille « appareil » ne la marque. C'est le cas d'un tout
    // premier lancement : au moment où l'accueil demande `/events`, le coffre
    // est encore vide et la session d'appareil n'est pas revenue. La juger
    // « membre » purgerait le coffre au retour de son 401, c'est-à-dire
    // **détruirait le jeton d'appareil rangé entre-temps** — et cette course,
    // systématique sur un émulateur Android (coffre plus lent à écrire),
    // éteindrait ensuite `/sync`, le push et l'agenda. Sans porteur, il n'y a
    // donc rien à purger ni personne à renvoyer se connecter : si un mode
    // invité est câblé, on renouvelle et on rejoue ; sinon seulement, on
    // retombe sur le comportement d'avant.
    final carriedToken = options.extra[kAuthTokenAttachedExtra] == true;
    final carriedByDevice =
        options.extra[kAuthTokenKindExtra] == AuthTokenKind.device ||
            options.extra[kDeviceSessionRequestExtra] == true ||
            !carriedToken;

    // Jeton de membre, ou pas de mode invité câblé : purge + retour à `/auth`.
    if (!carriedByDevice || guard == null) {
      await _onUnauthorized();
      handler.next(err);
      return;
    }

    final alreadyTried = options.extra[kDeviceSessionReplayExtra] == true ||
        options.extra[kDeviceSessionRequestExtra] == true;

    if (!alreadyTried && await guard.renew()) {
      options.extra[kDeviceSessionReplayExtra] = true;
      try {
        handler.resolve(await guard.replay(options));
        return;
      } on DioException catch (replayed) {
        handler.next(replayed);
        return;
      }
    }

    // Renouvellement impossible : la requête échoue, et **rien d'autre**. Ni
    // purge (le prochain renouvellement remplacera le jeton mort), ni éjection —
    // l'invité reste devant son catalogue, la synchronisation retentera à son
    // prochain déclencheur.
    handler.next(err);
  }
}
