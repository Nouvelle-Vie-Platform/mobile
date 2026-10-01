/// **Le réglage d'exploitation du parc**, du magasin jusqu'à la coquille (#91).
///
/// Il n'en porte qu'un aujourd'hui : le **seuil du bandeau de mise à jour**. Le
/// bandeau lui-même, sa comparaison de versions et sa mémoire de fermeture
/// vivent dans `app_update_providers.dart` — ce fichier-ci n'est que la source.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_providers.dart';

/// Le seuil tel que le **magasin** le connaît, **observé** : un seuil posé,
/// déplacé ou retiré au portail est suivi au cycle de synchronisation suivant,
/// sans qu'on rouvre l'application.
///
/// `null` veut dire « pas de seuil », et il recouvre **deux** états du serveur
/// que le client n'a aucune raison de distinguer — table jamais remplie, et
/// ligne dont la colonne est nulle. Voir `DeviceSettingsDao`, qui est le seul
/// endroit à en décider.
///
/// **Pas de réessai automatique** — même parti pris que les autres lectures du
/// magasin : il n'y a rien à retenter en boucle sur une base locale.
final updateBannerMinVersionProvider = StreamProvider<String?>(
  (ref) => ref.watch(deviceSettingsDaoProvider).watchUpdateBannerMinVersion(),
  retry: _noAutomaticRetry,
);

Duration? _noAutomaticRetry(int retryCount, Object error) => null;
