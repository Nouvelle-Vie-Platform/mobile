import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/settings_dao.dart';
import '../data/network/network_transport.dart';
import '../models/media_preferences.dart';
import 'sync_providers.dart';

/// Pas de réessai automatique, pour la raison des autres lectures de magasin :
/// une lecture locale qui échoue ne réussira pas mieux à la seconde tentative.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Le DAO des réglages locaux.
final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao,
);

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

/// **Le plafond effectif de l'écoute**, en bits par seconde. `null` = aucun.
///
/// C'est le seul des trois usages qui aboutisse à quelque chose : le direct n'a
/// pas de lecteur et le téléchargement n'existe pas.
///
/// **Asymétrique, et c'est le cœur du réglage.** Le plafond descend dès que le
/// téléphone bascule en données mobiles — c'est la facture qu'on voulait
/// éviter, et l'effet arrive au segment suivant, sans coupure. Il **ne remonte
/// pas** en revanche au retour du wifi tant que le contenu courant joue :
/// remonter coûterait une remise en tampon au milieu d'un prêche, et une
/// interruption vaut plus cher qu'un peu d'aigu. La remontée se fait donc au
/// contenu suivant, quand `ContentPlayerView` repose le plafond après `load`.
///
/// Le cliquet vit ici, dans un `Notifier`, et non dans le lecteur : c'est une
/// règle de préférence, pas une propriété du média, et les trois
/// implémentations de `ContentPlayer` n'ont pas à la connaître chacune de leur
/// côté.
final streamingBitrateCapProvider =
    NotifierProvider<StreamingBitrateCap, int?>(StreamingBitrateCap.new);

class StreamingBitrateCap extends Notifier<int?> {
  /// Le plafond le plus bas vu depuis le dernier [release] — le cliquet.
  int? _floor;

  /// Le plafond que le réglage et le réseau **appellent** en ce moment, cliquet
  /// mis à part. Retenu pour que [release] puisse y revenir sans relancer
  /// `build`.
  int? _target;

  @override
  int? build() {
    final quality =
        ref.watch(mediaPreferencesProvider).value?.of(MediaUsage.streaming) ??
            MediaQuality.auto;
    final onCellular = ref.watch(onCellularProvider).value ?? false;

    _target = effectiveBitrateCap(quality, onCellular: onCellular);
    // `null` (aucun plafond) est le plus **haut** de tous : il ne peut jamais
    // gagner contre un plancher déjà posé.
    if (_floor == null) return _floor = _target;
    if (_target == null) return _floor;
    return _floor = _target! < _floor! ? _target : _floor;
  }

  /// Relâche le cliquet — à l'ouverture d'un contenu, jamais pendant.
  ///
  /// Sans cela, un fidèle qui a écouté une fois en données mobiles resterait
  /// bridé chez lui, sur son wifi, jusqu'au redémarrage de l'application.
  ///
  /// **Écrit `state` directement, sans `invalidateSelf()`.** L'invalidation
  /// reconstruisait le notifier depuis un appel venu du widget, qui l'écoute :
  /// le rebond entre les deux faisait tourner le montage de l'écran de lecture
  /// jusqu'à l'expiration du test, dix minutes plus tard.
  void release() {
    _floor = _target;
    if (state != _target) state = _target;
  }
}
