import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/players/bitrate_cap_controller.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';

/// Aucun magasin, aucun widget, aucune horloge factice : c'est tout l'intérêt
/// d'avoir sorti cette politique de l'écran de lecture.
void main() {
  late InertContentPlayer player;
  late StreamController<int?> targets;
  late StreamController<MediaQuality> qualities;
  late StreamController<bool> cellular;
  late BitrateCapController controller;

  setUp(() {
    player = InertContentPlayer();
    targets = StreamController<int?>();
    qualities = StreamController<MediaQuality>();
    cellular = StreamController<bool>();
    controller = BitrateCapController(
      player: player,
      qualities: qualities.stream,
      onCellular: cellular.stream,
      targets: targets.stream,
    );
    addTearDown(() async {
      controller.dispose();
      await targets.close();
      await qualities.close();
      await cellular.close();
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

  Future<void> choose(MediaQuality quality) async {
    qualities.add(quality);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> network({required bool onCellular}) async {
    cellular.add(onCellular);
    await Future<void>.delayed(Duration.zero);
  }

  group('Le palier par l\'URL — le seul levier qui morde sur Android', () {
    test('un palier explicite devient un nom de rendu', () async {
      await choose(MediaQuality.low);
      expect(player.preferredVariant, 'low');

      await choose(MediaQuality.high);
      expect(player.preferredVariant, 'high');
    });

    test('« Automatique » garde le master en wifi', () async {
      await choose(MediaQuality.high);
      await choose(MediaQuality.auto);
      await network(onCellular: false);

      // Brider l'URL en mode automatique interdirait toute adaptation, alors
      // que c'est précisément ce que ce mode promet en wifi.
      expect(player.preferredVariant, isNull);
    });

    test('« Automatique » prend le rendu `low` en données mobiles', () async {
      await choose(MediaQuality.auto);
      await network(onCellular: true);

      // **C'est ce qui ferme le trou Android** : le plafond de débit y est
      // ignoré, l'URL non. Sur iOS et le web le plafond fait déjà le travail,
      // et ce rendu ne le contredit pas.
      expect(player.preferredVariant, 'low');

      await network(onCellular: false);
      expect(player.preferredVariant, isNull);
    });

    test('un palier explicite ignore le réseau', () async {
      await choose(MediaQuality.high);
      await network(onCellular: true);

      // L'avoir choisi est une décision qu'on ne corrige pas dans le dos de
      // qui l'a prise.
      expect(player.preferredVariant, 'high');
    });

    test('l\'URL dérivée pointe la liste de lecture du rendu', () {
      expect(
        variantPlaylistUrl('https://x.test/hls/abc/master.m3u8', 'low'),
        'https://x.test/hls/abc/low/index.m3u8',
      );
    });

    test('une URL d\'une autre forme est rendue intacte', () {
      // **La panne va dans le sens sûr** : pire cas « pas de bridage », jamais
      // « plus de lecture ». C'est ce qui rend acceptable de dériver une URL à
      // partir d'une hypothèse sur le serveur.
      const foreign = 'https://ailleurs.test/flux.m3u8';
      expect(variantPlaylistUrl(foreign, 'low'), foreign);
      expect(
        variantPlaylistUrl('https://x.test/hls/abc/master.m3u8', null),
        'https://x.test/hls/abc/master.m3u8',
      );
    });
  });

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
