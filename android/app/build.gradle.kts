import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.eslabon_flutter" // Asegúrate que este sea el namespace correcto
    compileSdk = 35 // <--- ¡ACTUALIZADO A 35!

    // >>>>>>>>>>> INICIO DE LAS MODIFICACIONES NECESARIAS <<<<<<<<<<<

    // 1. Sobreescribir la versión de Android NDK con la requerida por tus plugins
    ndkVersion = "27.0.12077973" // Valor específico requerido

    // ************ ¡CRUCIAL!
    // AÑADIDO PARA SOPORTE DE JAVA 8 Y DESUGARING ************
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true // <--- ¡ESTA ES LA LÍNEA QUE FALTABA Y ES CLAVE!
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
    // ***********************************************************************************

    defaultConfig {
        applicationId = "com.example.eslabon_flutter" // ¡CRUCIAL!
        // Debe coincidir con google-services.json
        minSdk = 23 // Mínimo 23 para Firebase
        targetSdk = 35 // <--- ¡ACTUALIZADO A 35 para coincidir con compileSdk!
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true // Asegura que MultiDex esté habilitado
    }

    // >>>>>>>>>>> FIN DE LAS MODIFICACIONES NECESARIAS <<<<<<<<<<<

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true // Habilitar reducción de código para release
            isShrinkResources = true // Habilitar reducción de recursos para release
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug { // Configuración para compilaciones de depuración
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Si usas ViewBinding, descomenta este bloque
    // buildFeatures {
    //     viewBinding = true
    // }
}

configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "org.jetbrains.kotlin") {
            useVersion("2.1.0")
        }
    }
}

dependencies {
    // ************ ¡CRUCIAL! AÑADIDO PARA CORE LIBRARY DESUGARING ************
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // ***********************************************************************************

    // Asegúrate de tener tus dependencias de Firebase aquí, usando la BOM
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    implementation("com.google.firebase:firebase-appcheck-ktx")
    implementation("com.google.firebase:firebase-functions-ktx")

    // Otras dependencias de AndroidX y UI
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1") // Asegura multidex
}

flutter {
    source = "../.."
}