/// **La dégradation d'une image avant envoi** (M4, #143 — reprend #98) :
/// JPEG q80, côté long ≤ 1600 px, **EXIF retiré**.
///
/// Le test qui compte est le premier : une photo qui porte des coordonnées GPS
/// n'en porte plus après la dégradation. Le serveur ne peut pas le vérifier
/// (ADR-0005) ; c'est ici, et seulement ici, que la garantie existe.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:maison_du_miracle/data/messaging/media/image_degrade.dart';

/// Un JPEG **porteur d'EXIF** : position GPS (Lomé), appareil, et — au
/// besoin — une orientation.
Uint8List _photo({
  required int width,
  required int height,
  int? orientation,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  image.exif.gpsIfd.setGpsLocation(latitude: 6.1319, longitude: 1.2228);
  image.exif.imageIfd.make = 'Téléphone de test';
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(image, quality: 95);
}

void main() {
  test('la photo d’origine porte bien ses coordonnées (contrôle du témoin)',
      () {
    final exif = img.decodeJpgExif(_photo(width: 64, height: 48));
    expect(exif, isNotNull);
    expect(exif!.gpsIfd.gpsLatitude, closeTo(6.1319, 0.001));
  });

  test('l’EXIF est retiré : plus de position GPS, plus d’appareil', () {
    final source = _photo(width: 64, height: 48);
    // Le témoin d'abord, sur les MÊMES octets : la position et l'appareil y
    // sont bien écrits. Sans cela, l'absence plus bas ne prouverait rien.
    final before = img.decodeJpgExif(source);
    expect(before, isNotNull);
    expect(before!.gpsIfd.gpsLatitude, closeTo(6.1319, 0.001));
    expect(before.gpsIfd.gpsLongitude, closeTo(1.2228, 0.001));
    expect(before.imageIfd.make, isNotNull);

    final degraded = degradeImageBytes(source);

    final exif = img.decodeJpgExif(degraded.bytes);
    // Aucun segment EXIF du tout — ou, si un décodeur en voit un, vide.
    expect(exif == null || exif.isEmpty, isTrue);
    expect(exif?.gpsIfd.gpsLatitude, isNull);
    expect(exif?.imageIfd.make, isNull);
  });

  test('un côté long au-dessus de 1600 px est ramené à 1600', () {
    final degraded = degradeImageBytes(_photo(width: 3200, height: 2400));

    expect(degraded.width, kImageMaxLongSide);
    expect(degraded.height, 1200);
    final decoded = img.decodeJpg(degraded.bytes)!;
    expect(decoded.width, 1600);
  });

  test('un portrait est ramené par sa hauteur', () {
    final degraded = degradeImageBytes(_photo(width: 1000, height: 2000));

    expect(degraded.height, 1600);
    expect(degraded.width, 800);
  });

  test('une image plus petite n’est PAS agrandie', () {
    final degraded = degradeImageBytes(_photo(width: 800, height: 600));

    expect(degraded.width, 800);
    expect(degraded.height, 600);
  });

  test('l’orientation EXIF est cuite dans les pixels avant d’être retirée', () {
    // Orientation 6 : l'appareil était tourné de 90° — la photo « couchée »
    // 400×200 doit arriver debout, 200×400.
    final degraded =
        degradeImageBytes(_photo(width: 400, height: 200, orientation: 6));

    expect(degraded.width, 200);
    expect(degraded.height, 400);
    final exif = img.decodeJpgExif(degraded.bytes);
    expect(exif?.imageIfd.orientation, isNull);
  });

  test('le résultat est un JPEG', () {
    final degraded = degradeImageBytes(_photo(width: 100, height: 100));
    // SOI d'un JPEG : FF D8.
    expect(degraded.bytes.sublist(0, 2), [0xFF, 0xD8]);
  });

  test('des octets qui ne sont pas une image lèvent FormatException', () {
    expect(
      () => degradeImageBytes(Uint8List.fromList([1, 2, 3, 4])),
      throwsFormatException,
    );
  });
}
