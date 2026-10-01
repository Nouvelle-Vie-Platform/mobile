plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Le réveil push (#97). **Après** le greffon Android : il enrichit la variante,
    // qui n'existe pas encore avant. Sa version est déclarée dans
    // `settings.gradle.kts`, qui dit aussi pourquoi il est obligatoire.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.maisondumiracle.maison_du_miracle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.maisondumiracle.maison_du_miracle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 7.0 (API 24) — le défaut de Flutter 3.44
        // (`FlutterExtension.minSdkVersion = 24`), et non plus 23.
        //
        // Le 23 précédent était une portée **nominale** : Flutter 3.35 a relevé
        // son propre minimum à 24, ce qui rend API 23 invérifiable sous toute
        // version de Flutter supportée — on annonçait un support qu'aucune
        // chaîne d'outils ne pouvait éprouver. `flutter_secure_storage` v11
        // l'exige par ailleurs (son chemin AES-CBC pour API 21-22 a disparu).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
