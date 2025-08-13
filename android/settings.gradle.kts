pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
    plugins {
        id("com.android.application") version "8.5.2" apply false
        id("org.jetbrains.kotlin.android") version "1.9.24" apply false
        id("com.google.gms.google-services") version "4.4.2" apply false
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google(); mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}
include(":app")
