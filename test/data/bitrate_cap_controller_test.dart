import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/bitrate_cap_controller.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';

/// Aucun magasin, aucun widget, aucune horloge factice : c'est tout l'intérêt
/// d'avoir sorti cette politique de l'écran de lecture.
void main() {
  late InertContentPlayer player;
  late StreamController<int?> targets;
  late BitrateCapController controller;

  setUp(() {
    player = InertContentPlayer();
    targets = StreamController<int?>();
    controller = BitrateCapController(player: player, targets: targets.stream);
    addTearDown(() async {
      controller.dispose();
      await targets.close();
      player.dispose();
    });
  });

  Future<void> emit(int? target) async {
    targets.add(target);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> open(String id) async {
    await player.load(contentId: id, url: 'https://x/$id.m3u8', title: id);
    await Future<void>.delayed(Duration.zero);
  }

  test('un plafond visé descend jusqu\'au lecteur', () async {
    await emit(64000);
    expect(player.bitrateCap, 64000);
  });

  test('le plafond descend en cours d\'écoute', () async {
    await open('t-1');
    await emit(null);
    expect(player.bitrateCap, isNull);

    // Le fidèle sort de l'église : le téléphone bascule en données mobiles au
    // milieu d'un prêche d'une heure.
    await emit(64000);
    expect(player.bitrateCap, 64000);
  });

  test('il ne remonte PAS au retour du wifi, contenu inchangé', () async {
    await open('t-1');
    await emit(64000);
    await emit(null);

    // Remonter coûterait une remise en tampon au milieu d'un prêche.
    expect(
      player.bitrateCap,
      64000,
      reason: 'le cliquet ne se relâche qu\'au contenu suivant',
    );
  });

  test('le contenu suivant relâche le cliquet', () async {
    await open('t-1');
    await emit(64000);
    await emit(null);
    expect(player.bitrateCap, 64000);

    await open('t-2');

    // Sans ce relâchement, une seule écoute en données mobiles briderait le
    // fidèle chez lui, sur son wifi, jusqu'au redémarrage de l'application.
    expect(player.bitrateCap, isNull);
  });

  test('un palier choisi plus bas gagne, un plus haut ne remonte pas',
      () async {
    await open('t-1');
    await emit(192000);
    expect(player.bitrateCap, 192000);

    await emit(64000);
    expect(player.bitrateCap, 64000);

    await emit(128000);
    expect(player.bitrateCap, 64000);
  });

  test('dispose coupe tout : plus rien n\'atteint le lecteur', () async {
    await open('t-1');
    controller.dispose();

    await emit(64000);
    expect(player.bitrateCap, isNull);
  });
}
