/// **Le service qui garde l'inscription push à jour** — le nœud entre le
/// [PushTransport] (qui *obtient* une cible de réveil) et le [DeviceRegistrar]
/// (qui l'*envoie* au serveur).
///
/// Maillon mobile des décisions **D1/D3/D4** du PRD `notifications-push.md`. Il
/// est **découplé** : il ne connaît ni Riverpod, ni le cycle de vie de l'app, ni
/// l'authentification. On lui **injecte** un transport et un registrar, et c'est
/// le démarrage de l'application (hors de ce maillon) qui décide *quand*
/// l'allumer, *quand* le purger et *avec quelles* implémentations réelles.
///
/// Trois moments, trois gestes :
///
/// 1. **Au démarrage / à la connexion** — [start] : demande l'inscription du
///    moment au transport ; si elle existe (elle vaut `null` sur l'Android
///    dé-googlé sans distributeur, décision **D4** — dégradé propre), la POSTe.
///    Rappelable sans dommage : le serveur est idempotent et l'abonnement aux
///    rotations n'est armé qu'une fois.
/// 2. **Sur rotation** — l'abonnement à [PushTransport.onRefresh] : FCM fait
///    tourner ses jetons, un distributeur peut ré-émettre un endpoint. Chaque
///    émission est une inscription **complète** ; on réenregistre la nouvelle et
///    on oublie l'ancienne. Une rotation qui rend la **même** cible ne repost
///    pas (l'égalité de [PushRegistration] le décide).
/// 3. **À la déconnexion** — [signOut] : purge la **dernière** inscription
///    enregistrée. Sur ce serveur, purger = sign-out + `deviceToken` (voir
///    `device_registrar.dart`) ; on ne purge donc que ce qu'on a réellement
///    posté, et rien si l'appareil n'avait pas de push.
///
/// **Rien ici ne lève et rien n'affiche.** Le push est un confort qui double le
/// SSE : ni un jeton qu'on n'obtient pas, ni un POST qui échoue (le registrar est
/// best-effort) ne doivent troubler démarrage, connexion ou déconnexion.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'device_registrar.dart';
import 'push_transport.dart';

/// Tient l'inscription push de l'appareil alignée sur le serveur. Voir l'en-tête
/// du fichier pour le cycle complet.
class PushRegistrationService {
  PushRegistrationService({
    required PushTransport transport,
    required DeviceRegistrar registrar,
  })  : _transport = transport,
        _registrar = registrar;

  final PushTransport _transport;
  final DeviceRegistrar _registrar;

  /// Abonnement aux rotations, armé **une seule fois** par [start].
  StreamSubscription<PushRegistration>? _refreshSub;

  /// La **dernière inscription réellement enregistrée** — ce qu'il faudra purger
  /// à la déconnexion. `null` tant qu'aucune n'a été posée (pas de push, ou pas
  /// encore démarré).
  PushRegistration? _current;

  /// Ce que le service a en mémoire comme cible courante — exposé pour les tests.
  @visibleForTesting
  PushRegistration? get current => _current;

  /// Démarrage / connexion : obtient l'inscription du moment et l'enregistre, et
  /// s'abonne aux rotations. Idempotent — l'abonnement n'est armé qu'à la
  /// première fois, et un ré-appel se contente de réenregistrer (idempotent
  /// serveur). Ne lève jamais.
  Future<void> start() async {
    _refreshSub ??= _transport.onRefresh.listen(
      _onRotated,
      // Un flux de rotation qui tombe en erreur ne doit pas remonter : on le
      // journalise et on continue. `InertPushTransport` rend un flux vide qui
      // n'émettra jamais rien de tel.
      onError: (Object error) =>
          debugPrint('[push] flux de rotation en erreur — $error'),
    );

    PushRegistration? registration;
    try {
      registration = await _transport.obtainRegistration();
    } catch (error) {
      // Obtenir un jeton FCM / négocier un endpoint peut échouer : c'est un
      // non-événement (le SSE couvre l'app ouverte). On n'enregistre rien.
      debugPrint('[push] obtention de l\'inscription impossible — $error');
      return;
    }

    if (registration == null) return; // pas de push sur cet appareil (D4).
    _current = registration;
    await _registrar.register(registration);
  }

  /// Une rotation de jeton/endpoint : réenregistrer la nouvelle cible, oublier
  /// l'ancienne. On saute la rotation qui rend la **même** cible — reposter pour
  /// rien réveillerait le serveur sans raison.
  Future<void> _onRotated(PushRegistration registration) async {
    if (registration == _current) return;
    _current = registration;
    await _registrar.register(registration);
  }

  /// Déconnexion : purge la dernière inscription enregistrée, s'il y en a une.
  /// Après quoi il n'y a plus rien à purger (on oublie la cible). Ne lève jamais.
  Future<void> signOut() async {
    final registration = _current;
    if (registration == null) return;
    _current = null;
    await _registrar.unregister(registration);
  }

  /// Relâche l'abonnement aux rotations et le transport natif. **Ne purge pas**
  /// l'inscription serveur — la purge est [signOut], une action explicite, pas un
  /// effet de bord d'un cycle de vie (même règle que `PushTransport.dispose`).
  Future<void> dispose() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    await _transport.dispose();
  }
}
