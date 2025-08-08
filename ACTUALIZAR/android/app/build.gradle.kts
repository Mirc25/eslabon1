plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.eslabon_flutter" // Puedes cambiarlo a "com.example.eslabon_flutter_fixed" si es tu namespace original
    compileSdk = flutter.compileSdkVersion

    // >>>>>>>>>>> INICIO DE LAS MODIFICACIONES NECESARIAS <<<<<<<<<<<

    // 1. Sobreescribir la versión de Android NDK con la requerida por tus plugins
    ndkVersion = "27.0.12077973" // <-- MODIFICACIÓN: Cambiado de flutter.ndkVersion al valor específico

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // MUY IMPORTANTE: Asegúrate de que este Application ID sea el que usas para Firebase, etc.
        // Si tu proyecto original usaba "com.example.eslabon_flutter_fixed", úsalo aquí.
        applicationId = "com.example.eslabon_flutter" // <--- **VERIFICA Y CAMBIA SI ES NECESARIO**

        // 2. Sobreescribir el minSdkVersion con el valor requerido por tus plugins de Firebase
        minSdk = 23 // <-- MODIFICACIÓN: Cambiado de flutter.minSdkVersion al valor específico

        targetSdk = flutter.targetSdkVersion // Mantener el targetSdk de Flutter
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // >>>>>>>>>>> FIN DE LAS MODIFICACIONES NECESARIAS <<<<<<<<<<<

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}