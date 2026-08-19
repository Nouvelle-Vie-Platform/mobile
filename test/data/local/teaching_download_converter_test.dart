// Tests du convertisseur de `teachings.download` (ADR-0038).
//
// On stocke ce que le serveur envoie ; la lecture est tolérante — un JSON
// corrompu se lit « pas téléchargeable », jamais une exception qui coûterait la
// requête d'un écran entier.

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/converters/teaching_download_converter.dart';
import 'package:maison_du_miracle/models/teaching_download.dart';

void main() {
  const converter = TeachingDownloadConverter();

  test('aller-retour SQL préserve version, durée et renditions', () {
    const value = TeachingDownload(
      version: 'v-42',
      durationSeconds: 1800,
      renditions: {
        'low': DownloadRendition(url: 'https://x/low.aac', bytes: 100),
        'mid': DownloadRendition(url: 'https://x/mid.aac', bytes: 200),
      },
    );

    final restored = converter.fromSql(converter.toSql(value));
    expect(restored.version, 'v-42');
    expect(restored.durationSeconds, 1800);
    expect(restored.renditions['mid']!.url, 'https://x/mid.aac');
    expect(restored.renditions['mid']!.bytes, 200);
  });

  test('decodeMap lit le contrat servi par la sync', () {
    final decoded = TeachingDownloadConverter.decodeMap({
      'version': 'abc',
      'duration': 3600,
      'renditions': {
        'high': {'url': 'https://x/high.aac', 'bytes': 300},
      },
    });
    expect(decoded.version, 'abc');
    expect(decoded.durationSeconds, 3600);
    expect(decoded.renditions['high']!.bytes, 300);
  });

  test('tolérance : JSON corrompu ⇒ contrat vide, jamais d\'exception', () {
    final decoded = converter.fromSql('{ pas du json');
    expect(decoded.version, '');
    expect(decoded.renditions, isEmpty);
  });

  test('tolérance : une rendition sans url/bytes est sautée', () {
    final decoded = TeachingDownloadConverter.decodeMap({
      'version': 'v',
      'duration': 10,
      'renditions': {
        'low': {'url': 'https://x/low.aac', 'bytes': 100},
        'mid': {'url': 'https://x/mid.aac'}, // pas de bytes
        'high': {'bytes': 300}, // pas d'url
      },
    });
    expect(decoded.renditions.keys, ['low']);
  });

  test('durée servie en num non entier est arrondie', () {
    final decoded = TeachingDownloadConverter.decodeMap({
      'version': 'v',
      'duration': 3599.6,
      'renditions': const {},
    });
    expect(decoded.durationSeconds, 3600);
  });
}
