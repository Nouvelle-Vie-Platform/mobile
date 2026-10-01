import 'package:dio/dio.dart';

import '../../data/app_platform.dart';
import '../../data/app_version.dart';

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

/// **L'en-tête de version, posé sur toutes les requêtes du client.**
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
class AppVersionHeaderInterceptor extends Interceptor {
  AppVersionHeaderInterceptor({
    required AppVersionReader Function() version,
    required AppPlatformReader Function() platform,
  })  : _version = version,
        _platform = platform;

  final AppVersionReader Function() _version;
  final AppPlatformReader Function() _platform;

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
