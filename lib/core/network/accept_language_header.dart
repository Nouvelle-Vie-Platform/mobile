import 'package:dio/dio.dart';

/// **L'application dit sa langue** — celle que l'interface affiche réellement.
///
/// ```
/// Accept-Language: en
/// ```
///
/// Une sous-étiquette nue (`fr`, `en`, `ee`), jamais une liste pondérée ni une
/// région : c'est ce que l'application sait, et rien de plus. Le serveur s'en
/// sert pour ce qu'il rédige lui-même — le mail du code de connexion, les
/// messages d'erreur — et retombe sur le français quand l'en-tête manque.
const String kAcceptLanguageHeader = 'Accept-Language';

/// **Pose `Accept-Language` sur toutes les requêtes du client** (#131).
///
/// ## Un intercepteur, jamais un appelant
///
/// Même règle qu'`AppVersionHeaderInterceptor` : un dépôt qui poserait
/// l'en-tête lui-même créerait une seconde vérité, et un en-tête ne renseigne
/// que sur les requêtes qui le portent. Celle qui compte le plus est
/// `POST /auth/request-code` — un membre en anglais doit recevoir son code en
/// anglais —, mais rien ne la distingue ici des autres.
///
/// ## Relu à **chaque** requête, et jamais retenu
///
/// C'est la différence avec la version du binaire, qui ne change pas tant qu'il
/// tourne : la langue, elle, peut changer en cours de session (réglage du
/// système, demain un sélecteur), et la requête suivante doit la suivre sans
/// redémarrage. La lecture est un appel de fonction synchrone, sans canal de
/// plugin : il n'y a rien à économiser en la retenant.
///
/// Relu aussi pour la raison de tous les lecteurs d'`ApiClient` : le singleton
/// naît avant que quoi que ce soit l'ait câblé.
///
/// ## D'où vient la langue — et pourquoi pas d'ici
///
/// La couche réseau ignore Riverpod et l'arbre de widgets ; elle ne **résout**
/// donc rien. Le lecteur est fourni par l'application (`app.dart`), qui lit
/// `contentLocaleProvider` — la copie de la locale que `MaterialApp` a
/// réellement résolue, tenue par `_ContentLocaleSync`. Re-dériver une langue
/// ici depuis `PlatformDispatcher` serait une seconde résolution, libre de
/// diverger de celle qui peint l'écran.
///
/// ## Purement additif
///
/// Pas de lecteur, lecteur qui lève, valeur vide ⇒ **en-tête absent**, et la
/// requête part quand même : côté serveur, l'absence vaut le français, jamais
/// un refus. `handler.next` est appelé dans tous les cas.
class AcceptLanguageInterceptor extends Interceptor {
  AcceptLanguageInterceptor({required String? Function() language})
      : _language = language;

  final String? Function() _language;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final language = _language()?.trim();
      if (language != null && language.isNotEmpty) {
        options.headers[kAcceptLanguageHeader] = language;
      }
    } on Object catch (_) {
      // Lecteur cassé (conteneur détruit, double mal écrit) : la requête part
      // sans dire sa langue, et le serveur répond en français.
    }
    handler.next(options);
  }
}
