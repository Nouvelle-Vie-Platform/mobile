/// **Quand on s'enregistre, et qui retient la cible.**
///
/// Deux moments, et deux seulement :
///
/// 1. **à l'ouverture de l'application**, une fois qu'il y a un porteur. C'est
///    `app.dart` qui appelle [start], juste après `awaitToken()` et juste avant le
///    premier cycle de synchronisation : avant le porteur, `POST /devices/tokens`
///    partirait nu pour se faire refuser ;
/// 2. **à chaque rotation de cible** (`PushTransport.targetChanges`). FCM fait
///    tourner ses jetons, et un jeton périmé ne produit aucune erreur visible — le
///    téléphone devient simplement injoignable, en silence. C'est la panne la plus
///    difficile à constater de cette tranche, d'où un abonnement et non un
///    réenregistrement périodique.
///
/// **Et aucun troisième moment, en particulier pas la connexion.** Le serveur
/// rattache lui-même l'enregistrement au compte qui vient de se connecter
/// (`ClaimDevicePushRegistrations`, branchée sur `verify-code`, Google et Apple) et
/// le rend à l'appareil à la déconnexion (`UnregisterDeviceToken`). Rappeler la
/// route à la connexion ferait un aller-retour pour un travail déjà fait, et
/// l'oublier ne casse rien : la cible, elle, ne change pas — c'est le même
/// téléphone.
///
/// ## Pourquoi la cible est retenue ici
///
/// `POST /auth/sign-out` prend un `deviceToken` **optionnel**, et l'omettre laisse
/// l'appareil abonné aux notifications du compte qui vient de partir. Sur un
/// téléphone prêté — le cas réel dans une église —, le membre suivant verrait
/// passer les notifications du précédent. La déconnexion a donc besoin de la
/// cible, et c'est ce champ-ci qu'elle lit ([target]), jamais un second appel à
/// `getToken()` : rien ne garantit que le transport répondrait encore (avion,
/// permission retirée entre-temps), et la cible à désabonner est celle qu'on a
/// **effectivement** enregistrée.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'push_registrar.dart';
import 'push_transport.dart';

class PushEnrolment {
  PushEnrolment({
    required PushTransport transport,
    required PushRegistrar registrar,
    required String? platform,
  })  : _transport = transport,
        _registrar = registrar,
        _platform = platform;

  final PushTransport _transport;
  final PushRegistrar _registrar;

  /// `ios` | `android` | `web`, ou `null` quand la plateforme n'est pas du jeu
  /// fermé du serveur (macOS, Linux, Windows). `null` ⇒ on n'enregistre rien : le
  /// serveur rendrait 422, et une plateforme hors contrat n'a de toute façon aucun
  /// transport.
  final String? _platform;

  StreamSubscription<String>? _rotations;

  /// **La cible enregistrée**, ou `null` tant qu'il n'y en a pas.
  ///
  /// Lue par la déconnexion (`HttpAuthRepository.signOut`). Elle n'est posée
  /// qu'après un enregistrement **accepté** : annoncer au serveur une cible qu'il
  /// n'a jamais rangée ferait désabonner une ligne qui n'existe pas — inoffensif,
  /// mais ce serait dire quelque chose de faux.
  String? get target => _target;
  String? _target;

  /// Obtient une cible, l'enregistre, et s'abonne aux rotations.
  ///
  /// **Ne lève jamais** et n'attend rien de personne : appelée sans être attendue,
  /// comme l'ouverture de session d'appareil. Rejouable — un second appel
  /// réenregistre la même cible, ce que le serveur traite comme un rafraîchissement
  /// de `last_seen_at`.
  Future<void> start() async {
    final platform = _platform;
    if (platform == null) return;

    // L'abonnement d'abord : une rotation qui tomberait pendant l'attente de la
    // première cible ne doit pas se perdre. Il est posé une seule fois, même si
    // `start()` est rejoué — deux abonnements enregistreraient deux fois.
    _rotations ??= _transport.targetChanges.listen(
      (rotated) => _publish(rotated, platform),
      // Un transport dont le flux de rotation tombe en erreur ne doit pas remonter
      // en « unhandled async error » : il n'y a personne pour l'attendre.
      onError: (Object error) => _trace('rotation ignorée : $error'),
    );

    try {
      final fresh = await _transport.target();
      if (fresh == null) {
        // Permission refusée, pas de Play Services, pas de distributeur, réseau
        // absent : tous normaux (PRD D4). L'application continue sans push.
        _trace('aucune cible de réveil — l\'application tourne sans push');
        return;
      }
      await _publish(fresh, platform);
    } on Object catch (error) {
      // Un transport qui lèverait malgré son contrat ne doit pas emporter le
      // démarrage : le push est un accélérateur, pas une dépendance.
      _trace('démarrage impossible : $error');
    }
  }

  Future<void> _publish(String token, String platform) async {
    final accepted = await _registrar.register(
      token: token,
      platform: platform,
      transport: _transport.transport,
    );
    if (accepted) _target = token;
  }

  /// Ferme l'abonnement aux rotations. La cible retenue, elle, ne s'efface pas :
  /// une déconnexion arrivant après la fermeture du conteneur doit encore savoir
  /// quoi désabonner.
  Future<void> dispose() async {
    await _rotations?.cancel();
    _rotations = null;
  }

  void _trace(String message) {
    assert(() {
      debugPrint('[push] $message');
      return true;
    }());
  }
}
