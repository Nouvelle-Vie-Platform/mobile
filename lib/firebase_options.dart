// Fichier **écrit à la main**, et non produit par `flutterfire configure`.
//
// `flutterfire` n'est pas installé sur la machine, et l'installer n'aurait pas
// suffi : la commande se connecte à Firebase avec `firebase-tools`, c'est-à-dire
// par une authentification Google interactive — un geste humain, que la liste des
// prérequis d'exploitation du PRD (§6) range déjà à la charge du porteur du
// projet. Les deux configurations natives déposées avec l'issue #97 portent en
// revanche **tout** ce dont ce fichier a besoin :
//
// | valeur              | source                                |
// |---------------------|---------------------------------------|
// | `apiKey` Android    | `android/app/google-services.json`    |
// | `appId` Android     | idem (`mobilesdk_app_id`)             |
// | `apiKey` iOS        | `ios/Runner/GoogleService-Info.plist`  |
// | `appId` iOS         | idem (`GOOGLE_APP_ID`)                |
// | `messagingSenderId` | `project_number` / `GCM_SENDER_ID`    |
// | `projectId`         | `project_id` / `PROJECT_ID`           |
// | `storageBucket`     | `storage_bucket` / `STORAGE_BUCKET`   |
// | **web**             | console Firebase, fiche de l'application web (#283) |
//
// La forme est **celle que `flutterfire` produit** (classe `DefaultFirebaseOptions`,
// sélection par `defaultTargetPlatform`, `UnsupportedError` pour les plateformes
// non déclarées) : le jour où quelqu'un lance la commande, le diff portera sur des
// valeurs et pas sur une structure.
//
// ⚠️ **Deux applications Firebase, pas une** : l'`applicationId` Android
// (`com.maisondumiracle.maison_du_miracle`) et le `PRODUCT_BUNDLE_IDENTIFIER` iOS
// (`com.maisondumiracle.maisonDuMiracle`) diffèrent de casse *et* de séparateur,
// et chacun a sa clé d'API. Les intervertir donnerait un jeton qu'aucun push
// n'atteindrait, sans qu'aucune erreur ne le dise.
//
// Rien ici n'est un secret : une clé d'API Firebase est publique par conception
// (elle part dans chaque binaire distribué), et c'est l'autorisation côté projet
// qui protège les services. Elle vit donc dans le dépôt, comme les deux fichiers
// natifs dont elle est recopiée.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Les options Firebase du projet `nouvelle-vie-25eb5`.
///
/// **Trois plateformes déclarées, et trois seulement.** macOS, Windows et Linux
/// n'ont aucune application dans le projet Firebase : y demander des options
/// lève, exactement comme le fichier généré le ferait. Personne ne doit
/// rattraper cette exception pour « dégrader » — c'est à l'appelant de ne pas
/// appeler (voir `_startPush()` dans `main.dart`, qui écarte ces plateformes
/// avant d'arriver ici).
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'a pas d\'options pour '
          '$defaultTargetPlatform : seules les applications Android et iOS sont '
          'déclarées dans le projet Firebase.',
        );
    }
  }

  /// Recopiées de `android/app/google-services.json`.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUbqXF9KbeZQwfPW80bkw9_Yzq_5N6Wlo',
    appId: '1:994804124857:android:500c2569d65850113a1f68',
    messagingSenderId: '994804124857',
    projectId: 'nouvelle-vie-25eb5',
    storageBucket: 'nouvelle-vie-25eb5.firebasestorage.app',
  );

  /// Recopiées de `ios/Runner/GoogleService-Info.plist`.
  ///
  /// ⚠️ Ces options sont justes et **aucun push n'arrivera pourtant sur iPhone** :
  /// FCM y passe obligatoirement par APNs, et la clé d'authentification APNs
  /// exige un compte Apple Developer Program qui n'est pas pris (PRD §6, D8).
  /// Ce n'est pas un défaut de ce fichier, et il n'y a rien à y corriger.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCivR31RwsPY8c7yzCjuWL2-IP-wCLYGbU',
    appId: '1:994804124857:ios:2fcc8feff8d0fbd23a1f68',
    messagingSenderId: '994804124857',
    projectId: 'nouvelle-vie-25eb5',
    storageBucket: 'nouvelle-vie-25eb5.firebasestorage.app',
    iosBundleId: 'com.maisondumiracle.maisonDuMiracle',
  );

  /// **L'application web** (#283), relevée de sa fiche dans la console Firebase.
  ///
  /// `authDomain` et `measurementId` n'existent que de ce côté — la première
  /// n'est lue que par l'authentification Firebase (que nous n'employons pas),
  /// la seconde par Analytics (idem). Elles sont recopiées quand même : le
  /// jour où `flutterfire configure` sera lancé, le diff doit porter sur des
  /// valeurs et pas sur des clés absentes.
  ///
  /// ⚠️ **Ces options ne suffisent pas à obtenir un jeton** : il faut en plus
  /// la **clé VAPID**, qui vit dans `lib/data/push/web_push_transport.dart`.
  /// Tant qu'elle est vide, `Firebase.initializeApp()` réussit, aucun jeton
  /// n'est demandé, et l'app web tourne sans push — exactement comme avant.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAP7fZYmqF5zlG_p4WmXXOemnwiqNYChYg',
    appId: '1:994804124857:web:5155903d7431300b3a1f68',
    messagingSenderId: '994804124857',
    projectId: 'nouvelle-vie-25eb5',
    authDomain: 'nouvelle-vie-25eb5.firebaseapp.com',
    storageBucket: 'nouvelle-vie-25eb5.firebasestorage.app',
    measurementId: 'G-1ZHZYRNBZH',
  );
}
