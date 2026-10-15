import Flutter
import UIKit

/// Le délégué de l'application — et, depuis #236, le seul canal natif d'iOS :
/// la place libre sur le disque. `dart:io` ne l'expose pas, et un canal de
/// méthode coûte moins qu'une dépendance pour une seule mesure. C'est le
/// pendant du canal que `MainActivity.kt` tient côté Android.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.maisondumiracle.maison_du_miracle/disk_space",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "freeBytes" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(AppDelegate.freeBytes())
    }
  }

  /// Les octets libres **là où l'application écrit** : le conteneur de
  /// l'application, celui qui porte les enseignements téléchargés comme les
  /// médias de la messagerie.
  ///
  /// ⚠️ `volumeAvailableCapacityForImportantUsage` et **surtout pas**
  /// `systemFreeSize` : sur APFS, ce dernier compte l'espace « purgeable »
  /// — des caches que le système promet de libérer et que l'application
  /// n'obtiendra pas forcément. Il annonce couramment plusieurs gigaoctets sur
  /// un appareil plein, et on aurait alors un pré-check qui laisse passer en
  /// croyant mesurer : pire que pas de pré-check du tout.
  ///
  /// Rend `nil` — jamais `0` — quand la mesure échoue : côté Dart `nil` veut
  /// dire « inconnu » et le pré-check laisse passer, là où `0` dirait « disque
  /// plein » et bloquerait tout.
  private static func freeBytes() -> NSNumber? {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    guard
      let values = try? home.resourceValues(
        forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
      let available = values.volumeAvailableCapacityForImportantUsage
    else {
      return nil
    }
    return NSNumber(value: available)
  }
}
