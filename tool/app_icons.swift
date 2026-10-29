// Génère **l'icône de l'application et son écran de démarrage natif**, pour les
// deux plateformes, depuis les deux seuls fichiers source du dépôt :
// `assets/images/brand_logo.webp` et `assets/images/live_bg.png` — Android, iOS
// **et le web** (les quatre icônes du manifeste PWA, plus la favicon).
//
// `swift tool/app_icons.swift` (ou `make icons`), depuis la racine du dépôt.
// Les fichiers produits sont **versionnés** : ce script ne tourne ni au build
// ni en CI, il ne tourne que le jour où le logo change.
//
// ## Pourquoi un script et pas `flutter_launcher_icons`
//
// Le générateur de pub n'aurait rien mis dans le binaire — il ne produit que
// des fichiers — et c'eût été acceptable au regard de la règle du dépôt. Mais
// il ne sait pas faire les deux choses que cette icône-ci exige :
//
// - **l'icône iOS sans canal alpha** : un PNG transparent fait rejeter la
//   soumission, et le logo est transparent hors de l'écusson. Ici chaque
//   icône iOS est peinte sur un fond blanc opaque, dans un contexte
//   `noneSkipLast` — le PNG écrit n'a donc pas de canal alpha du tout ;
// - **la couche monochrome d'Android 13+** : le système ne garde que l'alpha
//   et la teinte lui-même. Réutiliser le premier plan tel quel donnerait un
//   disque plein — l'écusson est opaque de bord à bord. On dérive donc l'alpha
//   de la *luminance* : l'encre bleue devient la matière, le blanc du fond et
//   des lettres devient le vide.
//
// Rien non plus n'est arrondi : iOS applique son propre masque, et les dessiner
// les doublerait.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Entrées / sorties

let root = FileManager.default.currentDirectoryPath
let brandLogo = "\(root)/assets/images/brand_logo.webp"
/// ⚠️ **Le PNG, et non le `.webp` embarqué.** Le bundle Flutter porte
/// `live_bg.webp` (102 k) ; ce script lit la source non compressée pour
/// fabriquer les ressources natives, qui ne passent pas par les assets de
/// Flutter. Les deux fichiers sont la même image, et le PNG ne part pas dans
/// l'application.
let liveBackground = "\(root)/assets/images/live_bg.png"
let androidRes = "\(root)/android/app/src/main/res"
let iosIcons = "\(root)/ios/Runner/Assets.xcassets/AppIcon.appiconset"
let iosLaunch = "\(root)/ios/Runner/Assets.xcassets/LaunchImage.imageset"
let webIcons = "\(root)/web/icons"

func fail(_ message: String) -> Never {
  FileHandle.standardError.write("✗ \(message)\n".data(using: .utf8)!)
  exit(1)
}

func load(_ path: String) -> CGImage {
  guard
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else {
    fail("illisible : \(path)")
  }
  return image
}

func write(_ image: CGImage, to path: String) {
  let directory = (path as NSString).deletingLastPathComponent
  try? FileManager.default.createDirectory(
    atPath: directory, withIntermediateDirectories: true)
  guard
    let destination = CGImageDestinationCreateWithURL(
      URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
  else {
    fail("écriture impossible : \(path)")
  }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { fail("écriture échouée : \(path)") }
  print("  \(path.replacingOccurrences(of: root + "/", with: ""))  \(image.width)×\(image.height)")
}

// MARK: - Dessin

/// Le logo, posé au centre d'un carré de [size] pixels.
///
/// [coverage] est la part de la largeur que le logo occupe : 0,92 pour une
/// icône classique, 0,62 pour le premier plan adaptatif — dont seuls les 66 dp
/// centraux d'un canevas de 108 dp sont garantis visibles, quel que soit le
/// masque du lanceur.
///
/// [background] nil ⇒ fond transparent (Android). Une couleur ⇒ fond **opaque**
/// et PNG **sans canal alpha** (iOS).
func square(
  _ logo: CGImage,
  size: Int,
  coverage: Double,
  background: (r: Double, g: Double, b: Double)?
) -> CGImage {
  let space = CGColorSpaceCreateDeviceRGB()
  let info: UInt32 = background == nil
    ? CGImageAlphaInfo.premultipliedLast.rawValue
    : CGImageAlphaInfo.noneSkipLast.rawValue
  guard
    let context = CGContext(
      data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
      space: space, bitmapInfo: info)
  else {
    fail("contexte \(size)×\(size) impossible")
  }
  context.interpolationQuality = .high
  if let background {
    context.setFillColor(red: background.r, green: background.g, blue: background.b, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
  }

  let box = Double(size) * coverage
  let scale = min(box / Double(logo.width), box / Double(logo.height))
  let width = Double(logo.width) * scale
  let height = Double(logo.height) * scale
  context.draw(
    logo,
    in: CGRect(
      x: (Double(size) - width) / 2, y: (Double(size) - height) / 2,
      width: width, height: height))

  guard let image = context.makeImage() else { fail("rendu \(size)×\(size) impossible") }
  return image
}

/// La couche monochrome : la **luminance inversée** devient l'alpha.
///
/// Le système ne lit que l'alpha de cette couche et la teinte lui-même ; la
/// couleur posée ici n'a donc aucune importance (noir, par convention).
func monochrome(_ image: CGImage) -> CGImage {
  let size = image.width
  guard
    let context = CGContext(
      data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
    let pixels = context.data
  else {
    fail("contexte monochrome impossible")
  }
  context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

  let bytes = pixels.bindMemory(to: UInt8.self, capacity: size * size * 4)
  for index in stride(from: 0, to: size * size * 4, by: 4) {
    let alpha = Double(bytes[index + 3]) / 255
    guard alpha > 0 else { continue }
    // Démultiplication, puis luminance perçue.
    let r = Double(bytes[index]) / 255 / alpha
    let g = Double(bytes[index + 1]) / 255 / alpha
    let b = Double(bytes[index + 2]) / 255 / alpha
    let luminance = min(1, 0.2126 * r + 0.7152 * g + 0.0722 * b)
    let ink = UInt8((alpha * (1 - luminance) * 255).rounded())
    bytes[index] = 0
    bytes[index + 1] = 0
    bytes[index + 2] = 0
    bytes[index + 3] = ink
  }

  guard let result = context.makeImage() else { fail("rendu monochrome impossible") }
  return result
}

/// Une image redimensionnée, sans fond et sans marge — pour le décor de
/// démarrage, qui est déjà cadré.
func resized(_ image: CGImage, width: Int, height: Int) -> CGImage {
  guard
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else {
    fail("contexte \(width)×\(height) impossible")
  }
  context.interpolationQuality = .high
  context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
  guard let result = context.makeImage() else { fail("rendu \(width)×\(height) impossible") }
  return result
}

// MARK: - Android

let logo = load(brandLogo)
print("logo source : \(logo.width)×\(logo.height)")

/// Les cinq compartiments de densité, et le facteur qui les sépare.
let densities: [(bucket: String, scale: Double)] = [
  ("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4),
]

print("\nAndroid — icônes classiques (48 dp) :")
for (bucket, scale) in densities {
  let size = Int((48 * scale).rounded())
  write(
    square(logo, size: size, coverage: 0.92, background: nil),
    to: "\(androidRes)/mipmap-\(bucket)/ic_launcher.png")
}

print("\nAndroid — premier plan adaptatif (108 dp, zone sûre 66 dp) :")
for (bucket, scale) in densities {
  let size = Int((108 * scale).rounded())
  let foreground = square(logo, size: size, coverage: 0.62, background: nil)
  write(foreground, to: "\(androidRes)/mipmap-\(bucket)/ic_launcher_foreground.png")
  write(monochrome(foreground), to: "\(androidRes)/mipmap-\(bucket)/ic_launcher_monochrome.png")
}

print("\nAndroid — décor du démarrage :")
let background = load(liveBackground)
/// La définition native du décor, ni plus ni moins : `nodpi` pour qu'Android ne
/// la rééchelonne pas en la décodant — c'est `android:gravity="fill"` qui
/// l'étire à l'écran, au moment de peindre. L'agrandir ferait un fichier plus
/// lourd sans un pixel de plus, la réduire ferait un saut de netteté au
/// premier frame de Flutter, qui pose la **même** image.
write(
  resized(background, width: background.width, height: background.height),
  to: "\(androidRes)/drawable-nodpi/launch_image.png")

// MARK: - iOS

/// Le jeu complet, exactement celui que décrit `Contents.json`.
let appleIcons: [(name: String, size: Int)] = [
  ("Icon-App-20x20@1x", 20), ("Icon-App-20x20@2x", 40), ("Icon-App-20x20@3x", 60),
  ("Icon-App-29x29@1x", 29), ("Icon-App-29x29@2x", 58), ("Icon-App-29x29@3x", 87),
  ("Icon-App-40x40@1x", 40), ("Icon-App-40x40@2x", 80), ("Icon-App-40x40@3x", 120),
  ("Icon-App-60x60@2x", 120), ("Icon-App-60x60@3x", 180),
  ("Icon-App-76x76@1x", 76), ("Icon-App-76x76@2x", 152),
  ("Icon-App-83.5x83.5@2x", 167),
  ("Icon-App-1024x1024@1x", 1024),
]

print("\niOS — icônes, fond blanc opaque, aucun coin arrondi :")
for (name, size) in appleIcons {
  write(
    square(logo, size: size, coverage: 0.86, background: (r: 1, g: 1, b: 1)),
    to: "\(iosIcons)/\(name).png")
}

print("\niOS — décor du démarrage :")
/// Le 3× garde la définition native du décor ; les deux autres en descendent,
/// pour qu'un appareil 1× ne décode pas une image de 1,6 Mpx.
let launchScales = [("LaunchImage", 1.0 / 3), ("LaunchImage@2x", 2.0 / 3), ("LaunchImage@3x", 1.0)]
for (name, scale) in launchScales {
  write(
    resized(
      background,
      width: Int((Double(background.width) * scale).rounded()),
      height: Int((Double(background.height) * scale).rounded())),
    to: "\(iosLaunch)/\(name).png")
}

// MARK: - Web

/// Les quatre icônes du manifeste PWA, plus la favicon.
///
/// **Fond blanc opaque, comme l'icône iOS et comme le lanceur Android**
/// (`ic_launcher_background` vaut `#FFFFFF`) : une application installée depuis
/// le navigateur doit porter la même icône que celle du magasin — c'est la même
/// église, et un fidèle qui a les deux ne doit pas se demander laquelle ouvrir.
///
/// ⚠️ **`maskable` prend la couverture du premier plan adaptatif (0,62), jamais
/// celle de l'icône classique.** Le système y découpe la forme qu'il veut et ne
/// garantit que le disque central de 80 % : à 0,92, un lanceur rond rognerait
/// l'emblème. C'est la même règle qu'Android, pour la même raison.
///
/// Jusqu'au 29/10/2026, ces quatre fichiers étaient **ceux de Flutter** — le
/// « F » bleu du gabarit —, parce que ce script ne connaissait pas `web/`.
print("\nWeb — icônes du manifeste :")
for size in [192, 512] {
  write(
    square(logo, size: size, coverage: 0.92, background: (r: 1, g: 1, b: 1)),
    to: "\(webIcons)/Icon-\(size).png")
  write(
    square(logo, size: size, coverage: 0.62, background: (r: 1, g: 1, b: 1)),
    to: "\(webIcons)/Icon-maskable-\(size).png")
}

/// La favicon : l'onglet du navigateur, et l'icône d'un raccourci iOS d'avant
/// iOS 15. 32 px plutôt que 16 : les écrans sont à 2×, et le fichier est minuscule.
write(
  square(logo, size: 32, coverage: 0.92, background: (r: 1, g: 1, b: 1)),
  to: "\(root)/web/favicon.png")

print("\n✓ terminé")
