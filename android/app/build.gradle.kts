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
        // CORRECTION : Déplacé ici pour activer le support sur l'API 28
        isCoreLibraryDesugaringEnabled = true 
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.maisondumiracle.maison_du_miracle"
        multiDexEnabled = true
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
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

// CORRECTION : Ajout du bloc des dépendances requis pour le desugaring
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
