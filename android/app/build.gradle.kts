// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // requiere google-services.json en app/
}

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

val flutterVersionCode = (localProps.getProperty("flutter.versionCode") ?: "1").toInt()
val flutterVersionName = localProps.getProperty("flutter.versionName") ?: "1.0.0"

android {
    namespace = "com.example.eslabon_flutter"
    // Si no tenés instalado android-35, instalalo o cambiá a 36
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.eslabon_flutter"
        minSdk = 23
        targetSdk = 34
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        multiDexEnabled = true
        vectorDrawables.useSupportLibrary = true

        // Inyecta la API key de Maps desde local.properties
        manifestPlaceholders["MAPS_API_KEY"] = localProps.getProperty("MAPS_API_KEY") ?: ""
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Config por defecto
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        jvmToolchain(17)
    }

    packaging {
        resources {
            excludes += setOf("META-INF/AL2.0", "META-INF/LGPL2.1")
        }
    }
}

// Conecta el módulo app con el proyecto Flutter
flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
