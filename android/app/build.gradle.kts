// android/app/build.gradle.kts
import java.util.Properties
import com.android.build.gradle.internal.dsl.SigningConfig
import com.android.build.gradle.internal.dsl.BuildType
import com.android.build.api.dsl.ApplicationBuildType

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    
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

    signingConfigs {
        create("release") {
            // ✅ CORRECCIÓN: Sintaxis actualizada para la configuración de la firma
            storeFile = file("my-upload-key.jks")
            storePassword = "49228080"
            keyAlias = "my-key-alias"
            keyPassword = "49228080"
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            // ✅ CORRECCIÓN: Asigna la configuración de la firma de lanzamiento
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
}

kotlin {
    jvmToolchain(17)
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}