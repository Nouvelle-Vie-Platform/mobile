import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';
import '../data/network/network_transport.dart';
import '../models/media_preferences.dart';

/// Pas de réessai automatique, pour la raison des autres lectures de magasin :
/// une lecture locale qui échoue ne réussira pas mieux à la seconde tentative.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

// `settingsDaoProvider` vit dans `theme_provider.dart` : les deux familles de
// réglages partagent la même table, et donc le même DAO.
/// **Le type de transport courant.** À surcharger par un
/// [FixedNetworkTransport] dans les tests : l'implémentation réelle ouvre un
/// canal de plugin, absent du harnais.
final networkTransportProvider = Provider<NetworkTransport>(
  (ref) => ConnectivityNetworkTransport(),
);

/// `true` quand l'appareil passe par des **données mobiles**.
///
/// Part à `false` — donc « pas de bridage » — et se corrige à la première
/// émission. Le doute penche du côté de la qualité : brider à tort une écoute
/// en wifi dégraderait le son sans rien économiser.
/// **Surtout pas un `async*` avec `yield*`.** La forme évidente —
/// `yield await isOnCellular(); yield* onCellular;` — casse : le flux de
/// transport est **diffusé et ne se ferme jamais**, donc le `yield*` ne rend
/// jamais la main, et la moindre reconstruction du provider relance le
/// générateur pendant que l'ancien alimente encore le même contrôleur. Riverpod
/// lève alors `Bad state: Cannot add event while adding stream` — et le test
/// qui montait l'écran de lecture restait bloqué **dix minutes** avant
/// d'expirer. Mesuré, pas supposé.
///
/// On câble donc à la main, avec les deux désabonnements que le générateur ne
/// faisait pas.
final onCellularProvider = StreamProvider<bool>((ref) {
  final transport = ref.watch(networkTransportProvider);
  final controller = StreamController<bool>();

  // L'état courant d'abord, pour que le premier plafond soit posé sans attendre
  // un changement de réseau qui peut ne jamais venir.
  transport.isOnCellular().then((value) {
    if (!controller.isClosed) controller.add(value);
  });
  final subscription = transport.onCellular.listen((value) {
    if (!controller.isClosed) controller.add(value);
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

/// Les trois réglages, tels que le panneau les affiche.
final mediaPreferencesProvider = StreamProvider<MediaPreferences>(
  (ref) => ref.watch(settingsDaoProvider).watchMediaPreferences(),
  retry: _noAutomaticRetry,
);

/// **Le palier d'écoute choisi**, sans le réseau.
///
/// Distinct de [streamingBitrateTargetProvider] : celui-ci dit ce que le fidèle
/// a **choisi**, celui-là ce que le choix et le réseau **imposent**. Le premier
/// se traduit en URL de rendu (le seul levier qui morde sur Android), le second
/// en plafond de débit (iOS et web).
final streamingQualityProvider = Provider<MediaQuality>((ref) {
  return ref.watch(mediaPreferencesProvider).value?.of(MediaUsage.streaming) ??
      MediaQuality.auto;
});

/// **Le plafond que le réglage et le réseau appellent**, en bits par seconde.
/// `null` = aucun plafond.
///
/// **Une dérivation pure, et rien d'autre.** La version précédente était un
/// `Notifier` qui portait le cliquet et **mutait un champ depuis son `build`** ;
/// couplé au `ref.listen` du widget de lecture, cela faisait tourner le montage
/// de l'écran jusqu'à l'expiration du test, dix minutes plus tard. Un `build` de
/// provider ne doit rien changer d'autre que sa valeur de retour.
///
/// Le cliquet — le plafond descend en cours d'écoute, ne remonte pas — vit
/// désormais dans le `State` de `ContentPlayerView`, ce qui est sa vraie nature :
/// il ne vaut que pour la session d'écoute en cours, et `CLAUDE.md` réserve
/// Riverpod à l'état **partagé**.
///
/// C'est le seul des trois usages qui aboutisse à quelque chose : le direct n'a
/// pas de lecteur et le téléchargement n'existe pas.
final streamingBitrateTargetProvider = Provider<int?>((ref) {
  final quality =
      ref.watch(mediaPreferencesProvider).value?.of(MediaUsage.streaming) ??
          MediaQuality.auto;
  final onCellular = ref.watch(onCellularProvider).value ?? false;
  return effectiveBitrateCap(quality, onCellular: onCellular);
});
