import 'dart:async';

import 'content_player.dart';

/// **Applique le plafond de débit au lecteur**, en tenant le cliquet.
///
/// Un objet de politique, pas un widget, et c'est la décision centrale de ce
/// fichier.
///
/// **Pourquoi pas dans `ContentPlayerView`.** C'est ce qui a été essayé
/// d'abord, et c'est ce qui a coûté le plus cher : dès que l'écran de lecture
/// touchait la chaîne des réglages, son montage sous `flutter test` se bloquait
/// — processus à **0 % de CPU pendant dix minutes**, donc une attente de
/// ressource et non une boucle, avant expiration. La cause tient au flux Drift
/// de `app_settings` ouvert sous l'horloge factice du harnais ; peu importe le
/// détail, la leçon est qu'un écran n'a pas à ouvrir un flux de magasin pour
/// **contraindre** le lecteur.
///
/// Cela déroge en apparence à « `ContentPlayerView` est le seul endroit qui
/// pilote le lecteur » (`CLAUDE.md`). La règle vise le **transport** — jouer,
/// mettre en pause, se déplacer, arrêter — pour que deux endroits ne se
/// disputent pas la lecture. Le plafond ne fait rien de tout cela : il n'a
/// aucun effet audible immédiat, il interdit seulement à l'adaptation HLS de
/// monter au-dessus d'un débit. Aucun conflit possible avec l'écran.
///
/// Câblé une fois dans `main.dart`, donc **jamais instancié par un test
/// d'écran**. Il se teste seul, avec un lecteur inerte et un `StreamController`
/// nu : ni magasin, ni widget, ni horloge factice.
class BitrateCapController {
  BitrateCapController({
    required ContentPlayer player,
    required Stream<int?> targets,
  })  : _player = player,
        _targets = targets {
    _subscription = _targets.listen(_onTarget);
    _player.addListener(_onPlayback);
    _contentId = _player.value.contentId;
  }

  final ContentPlayer _player;
  final Stream<int?> _targets;
  late final StreamSubscription<int?> _subscription;

  /// Le plafond le plus bas vu depuis l'ouverture du contenu courant.
  ///
  /// **Le cliquet.** Il descend quand le téléphone bascule en données
  /// mobiles — c'est la facture qu'on veut éviter, et l'effet arrive au segment
  /// suivant, sans coupure. Il **ne remonte pas** au retour du wifi tant que ce
  /// contenu joue : remonter coûterait une remise en tampon au milieu d'un
  /// prêche, et une interruption vaut plus cher qu'un peu d'aigu.
  int? _floor;

  /// Dernier plafond visé par le réglage et le réseau, cliquet mis à part.
  int? _target;

  /// Le contenu sur lequel le cliquet courant porte.
  String? _contentId;

  void _onTarget(int? target) {
    _target = target;
    if (target != null && (_floor == null || target < _floor!)) {
      _floor = target;
    }
    _player.setBitrateCap(_floor);
  }

  /// **Le changement de contenu relâche le cliquet**, et c'est le seul moment
  /// qui le relâche.
  ///
  /// Sans cela, un fidèle qui a écouté une fois en données mobiles resterait
  /// bridé chez lui, sur son wifi, jusqu'au redémarrage de l'application.
  ///
  /// On repose aussi le plafond parce que les implémentations qui **rouvrent
  /// une source** l'oublient en même temps qu'elles la remplacent.
  void _onPlayback() {
    final id = _player.value.contentId;
    if (id == _contentId) return;
    _contentId = id;
    _floor = _target;
    _player.setBitrateCap(_floor);
  }

  void dispose() {
    unawaited(_subscription.cancel());
    _player.removeListener(_onPlayback);
  }
}
