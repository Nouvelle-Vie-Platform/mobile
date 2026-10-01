/// **`POST /devices/tokens`** — déclarer au serveur par où le réveiller.
///
/// Contrat relevé dans le code du serveur (`app/devices/controllers/
/// register_device_token_controller.ts`, `app/devices/routes.ts`) :
///
/// ```
/// POST /devices/tokens        guards ['api', 'device']
/// token      string, 1..2048
/// platform   'ios' | 'android' | 'web'
/// transport  'fcm' | 'unifiedpush'   (optionnel, défaut 'fcm')
/// ```
///
/// Pas de préfixe `/api` (ADR-0004), CSRF exclu, corps en **camelCase** comme tous
/// les corps REST de ce serveur.
///
/// Quatre choses à savoir avant d'y toucher :
///
/// 1. **Les deux gardes.** Un appareil **sans compte** peut s'enregistrer, et
///    c'est le point de la tranche 2b serveur (#408) : un invité qu'on ne peut pas
///    prévenir d'un direct est un invité qui ne revient pas. L'application
///    enregistre donc dès qu'elle a un porteur — jeton d'appareil compris —, sans
///    attendre une connexion.
/// 2. **Aucun `deviceId` dans le corps.** L'identité d'appareil est lue sur le
///    jeton d'authentification. Une chaîne fournie par le client est
///    **falsifiable**, et l'accepter permettrait d'accrocher une cible de réveil à
///    l'appareil de quelqu'un d'autre. Ne pas « compléter » ce corps.
/// 3. **L'unicité porte sur la cible seule**, jamais sur `(utilisateur, cible)` :
///    réenregistrer **transfère la ligne** au porteur courant. C'est voulu — le
///    téléphone revendu, le mobile familial — et c'est pourquoi l'appel est
///    rejouable sans précaution.
/// 4. **L'enregistrement suit le porteur sans geste client** : la connexion le
///    rattache au compte (`ClaimDevicePushRegistrations`, appelée par
///    `verify-code`, Google et Apple), la déconnexion le rend à l'appareil. Il n'y
///    a donc **rien** à rappeler ici au moment de se connecter, et ajouter un appel
///    de plus ferait un aller-retour pour un travail déjà fait.
///
/// ## Muet, comme le rapport de progression
///
/// Un enregistrement qui échoue — avion, 401, 5xx — ne s'affiche pas, ne bloque
/// rien, et se rejoue au prochain démarrage (l'appel est idempotent par
/// conception). Une cible non enregistrée coûte un réveil, pas une fonctionnalité :
/// les trois déclencheurs de synchronisation d'ADR-0017 continuent de remplir le
/// magasin. Afficher une erreur de push à quelqu'un qui n'a rien demandé serait la
/// transformer en panne.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';

/// Déclarer une cible de réveil. **Ne lève jamais.**
abstract interface class PushRegistrar {
  /// Rend `true` si le serveur a accusé l'enregistrement. Un `false` n'est pas une
  /// erreur à montrer : c'est un appel à rejouer plus tard.
  Future<bool> register({
    required String token,
    required String platform,
    required String transport,
  });
}

/// L'implémentation réelle, sur le `Dio` d'[ApiClient] : la requête traverse les
/// intercepteurs de production — en-têtes de présentation, porteur, déballage
/// d'enveloppe, 401 (donc renouvellement silencieux d'un jeton d'appareil).
class HttpPushRegistrar implements PushRegistrar {
  HttpPushRegistrar({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  @override
  Future<bool> register({
    required String token,
    required String platform,
    required String transport,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/devices/tokens',
        data: {
          'token': token,
          'platform': platform,
          'transport': transport,
        },
      );
      return true;
    } on Object catch (error) {
      // Muet. La trace n'existe qu'en debug — en production, un réveil manquant
      // n'est pas un évènement dont l'utilisateur a quelque chose à faire.
      assert(() {
        debugPrint('[push] enregistrement impossible : $error');
        return true;
      }());
      return false;
    }
  }
}

/// Le double **inerte** : n'enregistre rien et le dit.
///
/// Vit à côté de son contrat et non dans `test/`, pour la raison de
/// `FixedAppVersionReader` et d'`InertStatusImagePicker` — un double rangé près du
/// contrat se met à jour avec lui. C'est aussi le repli de production hors backend.
class InertPushRegistrar implements PushRegistrar {
  const InertPushRegistrar();

  @override
  Future<bool> register({
    required String token,
    required String platform,
    required String transport,
  }) async =>
      false;
}
