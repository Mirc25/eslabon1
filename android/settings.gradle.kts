import java.io.FileInputStream
import java.util.Properties

// Carga el tooling de Flutter desde el SDK indicado en local.properties
pluginManagement {
  val flutterSdkPath = {
    val props = Properties()
    val flutterPropertiesFile = file("local.properties")
    if (flutterPropertiesFile.exists()) {
      FileInputStream(flutterPropertiesFile).use { props.load(it) }
    }
    val path = props.getProperty("flutter.sdk")
    require(path != null) { "flutter.sdk not set in local.properties" }
    path
  }()

  includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}

dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
  repositories {
    google()
    mavenCentral()
  }
}

plugins {
  id("dev.flutter.flutter-plugin-loader") version "1.0.0"
  id("com.android.application") version "8.6.0" apply false
  id("org.jetbrains.kotlin.android") version "1.9.24" apply false
  id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
rootProject.name = "eslabon_flutter"