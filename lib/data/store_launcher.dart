import 'package:flutter/foundation.dart';

/// **Renvoyer au magasin d'applications**, derrière une abstraction.
///
/// Même motif que `DiskSpace`, `AppVersionReader` et `StatusImagePicker` : le
/// bandeau ne connaît que ce contrat, et un test prouve que le bouton l'appelle
/// sans qu'aucune application tierce s'ouvre sur la machine de test.
///
/// [open] rend `true` si le magasin s'est ouvert. Il **ne lève jamais** : le
/// bandeau est informatif de bout en bout, et un écran rouge posé par son seul
/// bouton d'action serait la pire façon de rater une invitation à mettre à jour.
abstract interface class StoreLauncher {
  Future<bool> open();
}

/// L'implémentation en service aujourd'hui — **elle n'ouvre rien**, et c'est
/// assumé.
///
/// **Il manque l'adresse de la fiche** : l'application n'a jamais été
/// soumise, donc elle n'a ni
/// fiche App Store ni fiche Play Store, et une URL inventée mènerait à une page
/// d'erreur — ce qui est pire que rien. `url_launcher`, lui, est là depuis les
/// médias de la messagerie (M4, #143), avec les `<queries>` `https` du
/// manifeste Android : seule l'adresse manque, pour un bouton qu'aucun fidèle ne
/// peut atteindre (sans seuil réglé, le bandeau ne s'affiche pour personne —
/// voir `appUpdateThresholdProvider`).
///
/// Il se câble donc **à la première soumission au magasin**, qui est
/// aussi le moment où le seuil commence à vouloir dire quelque chose. D'ici là,
/// le chemin complet est écrit et testé ; seule la dernière ligne est en
/// attente, exactement comme `BestEffortDiskSpace` attend sa mesure.
class UnavailableStoreLauncher implements StoreLauncher {
  const UnavailableStoreLauncher();

  @override
  Future<bool> open() async => false;
}

/// Lanceur **qui compte ses appels** : le double des tests.
///
/// Exposé en production plutôt que défini dans `test/`, pour la raison
/// d'`InMemoryLegalNoticeStore` et de `FixedAppVersionReader` — un double qui
/// vit à côté de son contrat se met à jour avec lui.
@visibleForTesting
class RecordingStoreLauncher implements StoreLauncher {
  RecordingStoreLauncher({this.succeeds = true});

  /// Ce que [open] rend — le bandeau ne s'en sert pas aujourd'hui, mais le
  /// contrat le promet et un double qui mentirait sur ce point ne vaudrait rien.
  final bool succeeds;

  /// Nombre d'ouvertures demandées.
  int opened = 0;

  @override
  Future<bool> open() async {
    opened++;
    return succeeds;
  }
}
