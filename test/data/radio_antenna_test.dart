import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';

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
        'live': false,
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
}
