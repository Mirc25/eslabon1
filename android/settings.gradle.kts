// android/settings.gradle.kts

pluginManagement {
  val props = java.util.Properties()
  val lp = java.io.File(rootDir, "local.properties")
  if (lp.exists()) {
    lp.inputStream().use { props.load(it) }
  }
  val flutterSdkPath = props.getProperty("flutter.sdk")
    ?: throw org.gradle.api.GradleException("flutter.sdk not set in local.properties")

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

    val props = java.util.Properties()
    val lp = java.io.File(rootDir, "local.properties")
    if (lp.exists()) {
      lp.inputStream().use { props.load(it) }
    }
    val flutterSdkPath = props.getProperty("flutter.sdk")
      ?: throw org.gradle.api.GradleException("flutter.sdk not set in local.properties")

    maven { url = uri("$flutterSdkPath/bin/cache/artifacts/engine") }
    maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
  }
}

plugins {
  id("dev.flutter.flutter-plugin-loader") version "1.0.0" apply false
  id("com.android.application") version "8.6.0" apply false
  id("org.jetbrains.kotlin.android") version "2.2.0" apply false
  id("com.google.gms.google-services") version "4.4.2" apply false
}

rootProject.name = "eslabon_flutter"
include(":app")