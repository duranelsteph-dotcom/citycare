import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé Google Maps : JAMAIS versionnée, jamais écrite en dur.
// Ordre de recherche : android/secrets.properties (ignoré par git), puis la
// variable d'environnement CITYCARE_MAPS_API_KEY, sinon chaîne vide.
// Une valeur vide n'empêche pas la compilation : l'application bascule alors
// sur la carte OpenStreetMap (voir lib/core/config/maps_config.dart).
val citycareMapsApiKey: String = run {
    val properties = Properties()
    val secretsFile = rootProject.file("secrets.properties")
    if (secretsFile.exists()) {
        secretsFile.inputStream().use { properties.load(it) }
    }
    properties.getProperty("CITYCARE_MAPS_API_KEY")
        ?: System.getenv("CITYCARE_MAPS_API_KEY")
        ?: ""
}

android {
    namespace = "com.citycare.citycare"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.citycare.citycare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // google_maps_flutter exige au minimum l'API 21.
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        // Injecté dans AndroidManifest.xml, jamais lu depuis le code Dart.
        manifestPlaceholders["citycareMapsApiKey"] = citycareMapsApiKey
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
