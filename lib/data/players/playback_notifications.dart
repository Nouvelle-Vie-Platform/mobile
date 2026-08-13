/// **La permission de notification de lecture** — la seule chose
/// qu'`audio_service` ne fait pas à notre place.
///
/// Depuis Android 13, `POST_NOTIFICATIONS` est une permission **d'exécution** :
/// la déclarer au manifeste ne suffit pas. `audio_service` ne la demande pas et
/// son manifeste est vide ; sans cette demande, la notification de lecture
/// n'apparaît **jamais** — et rien ne le signale, ni journal ni exception.
///
/// Aucune dépendance ajoutée pour si peu : un canal de méthode vers
/// `MainActivity` suffit, et il ne coûte rien aux autres plateformes.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel(
  'com.maisondumiracle.maison_du_miracle/notifications',
);

/// Demande la permission d'afficher la notification de lecture.
///
/// Sans effet ailleurs que sur Android. **Ne bloque rien** : la lecture ne
/// dépend pas de la réponse, seule la notification en dépend — refuser une
/// notification ne doit pas priver de son.
///
/// Appelée depuis le démarrage de l'application, chemin que les tests ne
/// prennent jamais. Le `MissingPluginException` est tout de même rattrapé : il
/// arrive sur une plateforme sans canal (le web, un harnais de test) et ne
/// mérite pas d'arrêter le démarrage.
Future<void> requestPlaybackNotificationPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _channel.invokeMethod<bool>('requestPostNotifications');
  } on MissingPluginException {
    // Pas de canal : rien à demander, rien à signaler.
  } on PlatformException catch (error) {
    debugPrint('Permission de notification refusée par la plateforme: $error');
  }
}
