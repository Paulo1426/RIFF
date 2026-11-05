import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.song_guess_game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Lo pide flutter_local_notifications para programar notificaciones.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.song_guess_game"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // H-06: la llave de release vive en android/key.properties (ignorado por Git).
    val claves = Properties().apply {
        rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
    }
    signingConfigs {
        create("release") {
            if (!claves.isEmpty) {
                keyAlias = claves.getProperty("keyAlias")
                keyPassword = claves.getProperty("keyPassword")
                storeFile = file(claves.getProperty("storeFile"))
                storePassword = claves.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // H-01: R8 ofusca y reduce el código; quita clases y recursos sin uso.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // shortcut: sin key.properties cae a la llave debug para compilar localmente; no publicar así.
            signingConfig = if (claves.isEmpty) signingConfigs.getByName("debug") else signingConfigs.getByName("release")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
