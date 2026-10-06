/// **La dégradation d'une image avant envoi** (M4, #143 — reprend #98) :
/// « le téléphone dégrade, le serveur borne ».
///
/// | cible | valeur |
/// |---|---|
/// | format | JPEG |
/// | qualité | **80** |
/// | côté long | **≤ 1600 px**, jamais agrandi |
/// | EXIF | **retiré** |
///
/// ## Le retrait de l'EXIF n'est pas une coquetterie
///
/// L'EXIF d'une photo de téléphone porte la **position GPS** de la prise de
/// vue. Un membre qui photographie un document chez lui ne publie pas son
/// adresse à son groupe. Le serveur ne peut pas le vérifier (lire l'image ferait
/// passer les octets par l'API, ADR-0005) : c'est ici, et seulement ici, que
/// cette garantie existe — d'où le test explicite sur un fichier qui en porte
/// (`test/data/messaging/media/image_degrade_test.dart`).
///
/// ## Pur Dart, et c'est pour le test autant que pour le web
///
/// `package:image` décode et réencode sans plugin : la fonction se teste sous
/// `flutter test` sur de vrais octets JPEG, EXIF compris. Le prix est le temps
/// de calcul (une photo de 12 Mpx ≈ 1 à 2 s) : l'appelant la fait tourner hors
/// du fil de l'interface (`compute`, `DeviceMediaPreparer`).
///
/// L'orientation EXIF est **appliquée aux pixels** avant d'être retirée : sans
/// cela, une photo prise en portrait arriverait couchée chez tout le groupe.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Le côté long maximal d'une image envoyée (règle d'Échanges).
const int kImageMaxLongSide = 1600;

/// La qualité JPEG d'une image envoyée (règle d'Échanges).
const int kImageJpegQuality = 80;

/// Une image prête à monter.
class DegradedImage {
  const DegradedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  /// Le JPEG, **sans EXIF**.
  final Uint8List bytes;
  final int width;
  final int height;
}

/// **Dégrade [source] à la cible** : orientation appliquée, côté long ramené à
/// [maxLongSide] s'il le dépasse (jamais agrandi), EXIF retiré, JPEG
/// [quality].
///
/// Lève [FormatException] si les octets ne sont pas une image lisible.
DegradedImage degradeImageBytes(
  Uint8List source, {
  int maxLongSide = kImageMaxLongSide,
  int quality = kImageJpegQuality,
}) {
  final decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('image illisible');
  }

  // 1) L'orientation EXIF est cuite dans les pixels — elle va disparaître avec
  //    le reste de l'EXIF.
  var image = img.bakeOrientation(decoded);

  // 2) Le côté long, ramené — **jamais agrandi** : agrandir n'ajoute aucun
  //    détail, seulement des octets.
  final longSide = image.width >= image.height ? image.width : image.height;
  if (longSide > maxLongSide) {
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: maxLongSide,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: maxLongSide,
            interpolation: img.Interpolation.average,
          );
  }

  // 3) **L'EXIF part en entier** — position GPS, modèle de l'appareil, date.
  //    Un `ExifData` vide n'écrit aucun segment APP1 (`JpegEncoder`).
  image.exif = img.ExifData();

  final bytes = img.encodeJpg(image, quality: quality);
  return DegradedImage(bytes: bytes, width: image.width, height: image.height);
}
