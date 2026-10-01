pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Le greffon Google Services (#97) : il lit `app/google-services.json` et en
    // produit les ressources Android (`google_app_id`, `gcm_defaultSenderId`…) que
    // `FirebaseInitProvider` lit au démarrage du **processus**.
    //
    // ⚠️ Il n'est pas facultatif, même si `Firebase.initializeApp(options: …)` donne
    // déjà les options côté Dart : le service natif de FCM
    // (`FirebaseMessagingService`) démarre **avant** tout code Dart quand un réveil
    // arrive sur une application fermée, et sans ces ressources il n'a pas d'app
    // Firebase par défaut — le réveil en arrière-plan, c'est-à-dire tout l'objet de
    // cette tranche, ne se produirait jamais. Et il échouerait en silence : le push
    // partirait, le téléphone ne ferait rien.
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
