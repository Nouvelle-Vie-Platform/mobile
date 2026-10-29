/// **Recharger l'application** — ce que fait le bouton du bandeau de mise à
/// jour là où il n'y a pas de magasin.
///
/// Dans un navigateur, `StoreLauncher` n'a rien à ouvrir : il n'existe aucune
/// fiche d'application, et le seuil réglé au portail
/// (`update_banner_min_version`) n'aurait donc **aucun effet** sur l'app web —
/// un correctif urgent n'y arriverait jamais. La version servie change sans que
/// l'onglet déjà ouvert le sache : la seule action qui ait un sens est de
/// recharger la page.
///
/// Même motif que `StoreLauncher`, `AppVersionReader` et `InstallPrompt` : une
/// porte unique, un double qui compte ses appels, et l'interop du navigateur
/// enfermée dans un seul fichier (`browser_app_reloader.dart`).
library;

import 'package:flutter/foundation.dart';

/// Ce qui sait recharger l'application depuis sa source.
///
/// [reload] **ne lève jamais** : le bandeau est informatif de bout en bout, et
/// un écran rouge posé par son seul bouton d'action serait la pire façon de
/// rater une invitation à mettre à jour.
abstract interface class AppReloader {
  Future<void> reload();
}

/// Rechargeur **qui compte ses appels** : le double des tests.
///
/// Exposé en production plutôt que défini dans `test/`, pour la raison de
/// `RecordingStoreLauncher` — un double qui vit à côté de son contrat se met à
/// jour avec lui.
@visibleForTesting
class RecordingAppReloader implements AppReloader {
  /// Nombre de rechargements demandés.
  int reloaded = 0;

  @override
  Future<void> reload() async => reloaded++;
}
