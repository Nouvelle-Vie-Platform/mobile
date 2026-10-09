import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';

/// La route publique d'antenne n'existe pas encore (`server-portal#493`), et ce
/// lecteur porte **l'hypothèse** de cette tranche. Ces tests ne prouvent donc pas
/// que le serveur répond comme ça : ils prouvent qu'une réponse qu'on ne sait pas
/// lire **ne devient jamais « hors antenne »**, ce qui est la seule chose qui
/// pourrait mentir à l'auditeur sans que rien ne plante.
void main() {
  group('RadioAntenna.fromJson', () {
    test('lit la forme attendue', () {
      final antenna = RadioAntenna.fromJson(const {
        'streamUrl': 'https://stream.example/antenne/index.m3u8',
        'onAir': true,
      });
      expect(antenna.streamUrl, 'https://stream.example/antenne/index.m3u8');
      expect(antenna.onAir, isTrue);
      expect(antenna.isSilent, isFalse);
    });

    test('accepte les synonymes nommés de la table', () {
      // Le mot exact n'est pas tranché côté serveur. Un seul deviné de travers
      // rendrait la radio muette **sans qu'aucun test rougisse**, et la panne se
      // lirait comme une antenne éteinte.
      final antenna = RadioAntenna.fromJson(const {
        'url': 'https://stream.example/antenne/index.m3u8',
        'isOnAir': false,
      });
      expect(antenna.streamUrl, 'https://stream.example/antenne/index.m3u8');
      expect(antenna.isSilent, isTrue);
    });

    test('une URL blanche vaut une URL absente', () {
      final antenna = RadioAntenna.fromJson(const {'streamUrl': '   '});
      expect(antenna.streamUrl, isNull);
    });

    test('un corps illisible ne dit PAS « hors antenne »', () {
      // La distinction qui compte : `onAir` nul veut dire « je ne sais pas ».
      // Rendu `false`, il éteindrait le bouton et annoncerait à l'auditeur que
      // l'église ne diffuse pas — ce dont l'application n'a aucune idée.
      for (final body in <Map<String, dynamic>?>[
        null,
        const {},
        const {'onAir': 'oui'},
        const {'streamUrl': 42},
      ]) {
        final antenna = RadioAntenna.fromJson(body);
        expect(antenna.onAir, isNull, reason: 'corps : $body');
        expect(antenna.isSilent, isFalse, reason: 'corps : $body');
      }
    });

    test('une antenne muette garde son adresse', () {
      // C'est ce qui rend vrai « le bouton éteint reste appuyable, et marche » :
      // l'adresse est connue, seul l'état annoncé est faux.
      final antenna = RadioAntenna.fromJson(const {
        'streamUrl': 'https://stream.example/antenne/index.m3u8',
        'onAir': false,
      });
      expect(antenna.isSilent, isTrue);
      expect(antenna.streamUrl, isNotNull);
    });
  });

  test('RadioAntenna.unknown ne sait rien, et ne prétend pas le contraire', () {
    expect(RadioAntenna.unknown.streamUrl, isNull);
    expect(RadioAntenna.unknown.onAir, isNull);
    expect(RadioAntenna.unknown.isSilent, isFalse);
  });

  group('Le compteur et le direct (#135)', () {
    test('lit la forme du contrat fusionné', () {
      final antenna = RadioAntenna.fromJson(const {
        'streamUrl': 'https://stream.example/antenne/index.m3u8',
        'onAir': true,
        'listeners': 128,
        'live': {'startedAt': '2026-10-05T18:00:00.000Z'},
      });
      expect(antenna.listeners, 128);
      expect(antenna.live, isNotNull);
      expect(antenna.live!.startedAt, DateTime.utc(2026, 10, 5, 18));
      // Le direct n'éteint ni n'allume l'antenne : `onAir` reste le sien.
      expect(antenna.onAir, isTrue);
    });

    test('compteur nul : rien à afficher, et jamais zéro', () {
      final antenna = RadioAntenna.fromJson(const {
        'streamUrl': 'https://stream.example/antenne/index.m3u8',
        'onAir': true,
        'listeners': null,
        'live': null,
      });
      expect(antenna.listeners, isNull);
      expect(antenna.live, isNull);
    });

    test('un compteur ou un direct illisible ne s\'affiche pas', () {
      for (final body in <Map<String, dynamic>>[
        const {'listeners': 'beaucoup'},
        const {'listeners': -3},
        const {'live': true},
        const {
          'live': {'startedAt': 42},
        },
      ]) {
        final antenna = RadioAntenna.fromJson(body);
        expect(antenna.listeners, isNull, reason: 'corps : $body');
        expect(antenna.live, isNull, reason: 'corps : $body');
      }
    });

    test('« live » n\'est plus un synonyme d\'« onAir »', () {
      // Une fin de direct (`live: null`) ne doit jamais se lire comme une
      // antenne éteinte, et un direct comme une antenne allumée.
      final antenna = RadioAntenna.fromJson(const {
        'streamUrl': 'https://stream.example/antenne/index.m3u8',
        'live': {'startedAt': '2026-10-05T18:00:00.000Z'},
      });
      expect(antenna.onAir, isNull);
      expect(antenna.isSilent, isFalse);
    });
  });

  group('L\'URL économie (M2 du plan radio adaptative)', () {
    const adaptive = 'https://stream.example/antenne-hls/master.m3u8';
    const eco = 'https://stream.example/antenne-hls/a32/index.m3u8';

    test('ecoStreamUrl présent : lu', () {
      final antenna = RadioAntenna.fromJson(
          const {'streamUrl': adaptive, 'ecoStreamUrl': eco});
      expect(antenna.ecoStreamUrl, eco);
    });

    test('ecoStreamUrl nul, blanc ou absent : null', () {
      for (final body in <Map<String, dynamic>>[
        const {'streamUrl': adaptive, 'ecoStreamUrl': null},
        const {'streamUrl': adaptive, 'ecoStreamUrl': '  '},
        // Une réponse d'avant la tranche A2 n'a pas le champ.
        const {'streamUrl': adaptive},
      ]) {
        expect(RadioAntenna.fromJson(body).ecoStreamUrl, isNull,
            reason: 'corps : $body');
      }
    });

    test('Économie et URL économie : l\'URL économie', () {
      const antenna = RadioAntenna(streamUrl: adaptive, ecoStreamUrl: eco);
      expect(antenna.streamUrlFor(RadioQuality.economy), eco);
    });

    test('Automatique : toujours l\'adaptative, même avec une URL économie',
        () {
      const antenna = RadioAntenna(streamUrl: adaptive, ecoStreamUrl: eco);
      expect(antenna.streamUrlFor(RadioQuality.auto), adaptive);
    });

    test('Économie sans URL économie : a32 dérivé du master', () {
      const antenna = RadioAntenna(streamUrl: adaptive);
      expect(
        antenna.streamUrlFor(RadioQuality.economy),
        'https://stream.example/antenne-hls/a32.m3u8',
      );
    });
  });

  group('streamUrlFor, les quatre choix (#184)', () {
    const master = 'https://stream.example/antenne-hls/master.m3u8';
    const eco = 'https://stream.example/eco/a32.m3u8';
    const other = 'https://stream.example/antenne/live.m3u8';

    test('derrière un master : chaque palier a sa liste de lecture', () {
      const antenna = RadioAntenna(streamUrl: master);
      expect(antenna.streamUrlFor(RadioQuality.auto), master);
      expect(
        antenna.streamUrlFor(RadioQuality.minimum),
        'https://stream.example/antenne-hls/a16.m3u8',
      );
      expect(
        antenna.streamUrlFor(RadioQuality.economy),
        'https://stream.example/antenne-hls/a32.m3u8',
      );
      expect(
        antenna.streamUrlFor(RadioQuality.high),
        'https://stream.example/antenne-hls/a128.m3u8',
      );
    });

    test('Économie : l\'URL servie l\'emporte sur la dérivation', () {
      const antenna = RadioAntenna(streamUrl: master, ecoStreamUrl: eco);
      expect(antenna.streamUrlFor(RadioQuality.economy), eco);
      // Les autres paliers dérivent toujours du master.
      expect(
        antenna.streamUrlFor(RadioQuality.minimum),
        'https://stream.example/antenne-hls/a16.m3u8',
      );
    });

    test('sans master : l\'adresse intacte, jamais le silence', () {
      const antenna = RadioAntenna(streamUrl: other);
      for (final quality in RadioQuality.values) {
        expect(antenna.streamUrlFor(quality), other, reason: '$quality');
      }
    });

    test('sans master mais URL économie servie : l\'économie', () {
      const antenna = RadioAntenna(streamUrl: other, ecoStreamUrl: eco);
      expect(antenna.streamUrlFor(RadioQuality.economy), eco);
      expect(antenna.streamUrlFor(RadioQuality.high), other);
    });

    test('sans adresse : null pour tous', () {
      for (final quality in RadioQuality.values) {
        expect(RadioAntenna.unknown.streamUrlFor(quality), isNull);
      }
    });

    test('le compteur poussé en temps réel garde l\'URL économie', () {
      const antenna = RadioAntenna(streamUrl: master, ecoStreamUrl: eco);
      expect(
        antenna.withAudience(listeners: 12, live: null).ecoStreamUrl,
        eco,
      );
    });
  });
}
