import 'package:dio/dio.dart';

import '../../data/app_platform.dart';
import '../../data/app_version.dart';
import '../../data/devices/device_identity.dart';

/// **L'application dit son nom** : la version et le build du binaire installé.
///
/// Forme exacte, relevée du plan serveur (`server-portal`,
/// `docs/presentation-menus-vocabulaire-plan.md` §9) :
///
/// ```
/// X-App-Version: 1.4.0+12
/// ```
const String kAppVersionHeader = 'X-App-Version';

/// **La plateforme et son système**, dans la même forme :
///
/// ```
/// X-App-Platform: android 14
/// ```
const String kAppPlatformHeader = 'X-App-Platform';

/// **Quel appareil parle** — la valeur opaque du coffre (`device_id`,
/// `lib/data/devices/device_identity.dart`), celle-là même qui ouvre une session
/// d'appareil :
///
/// ```
/// X-Device-Id: 7c9e6679-7425-40de-944b-e07fc1f90ae7
/// ```
///
/// Sans elle, un membre qui n'est jamais passé par le mode invité n'a côté
/// serveur qu'une fiche **synthétique** dérivée de son compte : ses deux
/// téléphones n'en font qu'un, avec la version du dernier qui s'est synchronisé.
/// Le nom est fixé (2026-10-01) et la jumelle `server-portal#470` porte la même
/// décision.
///
/// ⚠️ **Il mesure, il n'autorise rien** (ADR-0040). Il est fabriqué et rangé par
/// le téléphone, donc falsifiable : il sert à **compter** les appareils, jamais
/// à décider d'une permission. Le porteur (`Authorization`) reste la seule
/// preuve d'identité — cet en-tête ne le remplace sur aucune requête, pas même
/// sur celles qui partent nues. Il n'est pas non plus un secret : rien ici ne
/// doit se mettre à le traiter comme tel.
const String kDeviceIdHeader = 'X-Device-Id';

/// **Les en-têtes de présentation, posés sur toutes les requêtes du client.**
///
/// Trois, et exactement trois : la version du binaire, la plateforme et son
/// système, et **l'identifiant d'appareil**. Les deux premiers disent *quelle
/// application* parle, le troisième *quel appareil* — sans lui, un membre à deux
/// téléphones ne compte que pour un côté serveur. Rien d'autre ne part : ni
/// identifiant publicitaire, ni empreinte dérivée du matériel.
///
/// ## Un intercepteur, jamais un appelant
///
/// Il part sur **toutes** les requêtes d'`ApiClient.instance`, synchronisation
/// comprise, sans qu'aucun dépôt ait à y penser. C'est le point entier : un
/// dépôt qui poserait l'en-tête lui-même créerait une seconde vérité, qui
/// divergerait au premier dépôt écrit après lui — et un en-tête ne renseigne que
/// sur les requêtes qui le portent.
///
/// ## Purement additif — il ne peut pas faire échouer une requête
///
/// Toute la lecture est enfermée dans un `try` qui n'a **rien** à dire en cas
/// d'échec, et `handler.next` est appelé dans tous les cas. Une version
/// illisible (canal de plugin absent sous `flutter test`, hôte exotique) se
/// traduit par un **en-tête absent**, jamais par une exception : côté serveur,
/// un en-tête absent donne « version inconnue », jamais un refus.
///
/// Corollaire : il est posé **en tête de chaîne**, avant l'injection du Bearer,
/// le déballage de l'enveloppe et le traitement du 401. Non parce que l'ordre
/// changerait l'en-tête — il ne dépend d'aucun des trois —, mais parce que
/// l'ordre décide de ce qui reste vrai quand un intercepteur suivant résout ou
/// rejette la requête : rien de ce qui part ne doit pouvoir partir sans nom. Il
/// voyage ainsi même sur l'ouverture de session d'appareil
/// (`POST /devices/anonymous`), que `_AuthInterceptor` laisse délibérément nue
/// de porteur — c'est pourtant la requête par laquelle le serveur découvre
/// l'appareil, donc celle qui a le plus besoin de dire sa version.
///
/// Les trois en-têtes sont **indépendants** : chacun manque seul. L'identifiant
/// a son propre `try` pour cette raison — un coffre illisible ne doit pas
/// emporter la version avec lui, et une version illisible ne doit pas emporter
/// l'identifiant.
///
/// ## Et **y compris connecté**
///
/// L'identifiant part sur les requêtes porteuses d'un jeton de membre comme sur
/// celles d'un invité : c'est tout l'objet de la tranche. Il ne remplace jamais
/// le porteur, il ne s'y substitue sur aucune requête, et il n'autorise rien
/// (ADR-0040) — il dit seulement *quel téléphone* parle.
///
/// ## Les lecteurs sont **relus** à chaque fois, et le résultat est retenu
///
/// Relus, parce que `ApiClient.instance` naît avant que quoi que ce soit ait pu
/// le câbler — même raison que `DeviceSessionGuard`. Retenu, parce qu'un binaire
/// ne change pas de version pendant qu'il tourne : la lecture passe par un canal
/// de plugin, et la refaire à chaque requête coûterait un aller-retour par appel
/// pour une valeur constante.
///
/// Le cache est attaché à **l'identité des lecteurs** qui l'ont produit : poser
/// d'autres lecteurs (ce que font les tests sur le singleton) le périme de
/// lui-même. Et un échec ne se met **pas** en cache — il n'y a rien à retenir
/// d'une absence, et la requête suivante retentera.
///
/// L'identifiant d'appareil, lui, n'est **pas** remis en cache ici : c'est déjà
/// la règle de `DeviceIdentity.current()`, qui retient un succès et jamais un
/// échec. Le redire ici ferait un second cache à périmer.
class AppVersionHeaderInterceptor extends Interceptor {
  AppVersionHeaderInterceptor({
    required AppVersionReader Function() version,
    required AppPlatformReader Function() platform,
    required DeviceIdentity Function() identity,
  })  : _version = version,
        _platform = platform,
        _identity = identity;

  final AppVersionReader Function() _version;
  final AppPlatformReader Function() _platform;

  /// L'identité de l'appareil, relue à chaque requête pour la raison des deux
  /// autres lecteurs — et **la même instance que celle du dépôt d'appareils**
  /// (`ApiClient.deviceIdentity`), pour qu'une première ouverture ne puisse pas
  /// fabriquer deux identifiants dont un seul serait rangé.
  final DeviceIdentity Function() _identity;

  AppVersionReader? _cachedFromVersion;
  AppPlatformReader? _cachedFromPlatform;
  Map<String, String> _cached = const {};

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      options.headers.addAll(await _headers());
    } on Object catch (_) {
      // Rien à dire à personne, et surtout pas à l'appelant : voir l'en-tête.
      // La requête part sans nom plutôt que de ne pas partir.
    }
    // **Son propre `try`, et c'est le point** : un coffre illisible fait
    // disparaître cet en-tête **seul**, la version et la plateforme restent.
    // Les trois sont indépendants, aucun ne tombe avec un autre.
    try {
      final id = await _identity().current();
      if (id.trim().isNotEmpty) options.headers[kDeviceIdHeader] = id;
    } on Object catch (_) {
      // Coffre illisible (canal de plugin absent sous `flutter test`, keychain
      // verrouillé) : l'appareil part sans se nommer, et la requête part.
    }
    handler.next(options);
  }

  Future<Map<String, String>> _headers() async {
    final version = _version();
    final platform = _platform();
    if (identical(version, _cachedFromVersion) &&
        identical(platform, _cachedFromPlatform)) {
      return _cached;
    }

    final headers = <String, String>{};
    final info = await version.read();
    if (info != null) {
      headers[kAppVersionHeader] = '${info.version}+${info.build}';
    }
    final host = platform.read();
    if (host != null) {
      headers[kAppPlatformHeader] = host.label;
    }

    _cachedFromVersion = version;
    _cachedFromPlatform = platform;
    return _cached = Map.unmodifiable(headers);
  }
}
