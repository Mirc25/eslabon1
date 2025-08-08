import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Lee versionCode / versionName que Flutter escribe en local.properties
val localProperties = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val flutterVersionCode = (localProperties.getProperty("flutter.versionCode") ?: "1").toInt()
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    // ⚠️ Cambiá si tu paquete es otro
    namespace = "com.example.eslabon_flutter"
    compileSdk = 35

    defaultConfig {
        // ⚠️ Cambiá si tu paquete es otro
        applicationId = "com.example.eslabon_flutter"
        minSdk = 23
        targetSdk = 35

        // ✅ FIX: versión para que Flutter pueda leer el manifest
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    // ✅ Firma de RELEASE con el debug keystore (para instalar YA en el celu)
    signingConfigs {
        create("release") {
            storeFile = file(System.getProperty("user.home") + "/.android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            // Por ahora sin minify/shrink (después lo activamos si querés reducir tamaño)
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
            // Cuando quieras optimizar:
            // isMinifyEnabled = true
            // isShrinkResources = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Necesario en tu stack (flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
    }
}

kotlin {
    jvmToolchain(17)
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}

dependencies {
    // AndroidX mínimo
    implementation("androidx.core:core-ktx:1.13.1")

    // Desugaring requerido
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
