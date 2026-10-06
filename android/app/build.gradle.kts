import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Le réveil push (#97). **Après** le greffon Android : il enrichit la variante,
    // qui n'existe pas encore avant. Sa version est déclarée dans
    // `settings.gradle.kts`, qui dit aussi pourquoi il est obligatoire.
    id("com.google.gms.google-services")
}

// La clé de release (#159) — **jamais dans le dépôt**.
//
// Deux sources, lues dans cet ordre pour chaque valeur :
// 1. les variables d'environnement `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`,
//    `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` — ce que pose `android-release.yml`, après avoir
//    reconstitué le keystore depuis un secret GitHub dans un fichier temporaire ;
// 2. `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`), pour une
//    construction à la main sur le Mac. Ignoré par Git, comme `*.jks` et `*.keystore`.
//
// Une valeur manque, ou le fichier du keystore n'existe pas : la release est signée avec la clé de
// **debug**, comme avant #159, et Gradle le dit. Ne jamais faire échouer la construction pour ça :
// c'est le workflow qui décide si l'absence de clé mérite un avertissement.
//
// ⚠️ Une fois des APK publiés avec cette clé, la perdre interdit toute mise à jour par-dessus :
// chaque téléphone devrait désinstaller. Elle se sauvegarde hors du Mac.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}

fun signingValue(env: String, property: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() }
        ?: keyProperties.getProperty(property)?.takeIf { it.isNotBlank() }

val releaseStorePath = signingValue("ANDROID_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")

// Un chemin relatif se lit depuis `android/app/`, la convention de la doc Flutter.
val releaseStoreFile = releaseStorePath?.let { file(it) }
val hasReleaseKey = releaseStoreFile?.isFile == true &&
    releaseStorePassword != null && releaseKeyAlias != null && releaseKeyPassword != null

if (!hasReleaseKey) {
    logger.warn("Pas de clé de release (#159) : la release est signée avec la clé de debug.")
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

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
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
