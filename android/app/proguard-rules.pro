# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play Services / Firebase / Ads / UMP / Maps
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class com.google.maps.** { *; }

# Componentes Android
-keep class ** extends android.app.Application { *; }
-keep class ** extends android.app.Service { *; }
-keep class ** extends android.content.BroadcastReceiver { *; }
-keep class ** extends android.content.ContentProvider { *; }
-keep class ** extends android.app.Activity { *; }

# Anotaciones / reflexión
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# OkHttp/Okio/Gson/Proto
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# JetBrains annotations
-keep class org.jetbrains.annotations.** { *; }
-dontwarn org.jetbrains.annotations.**

# Evitar warnings ruidosos
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn sun.misc.Unsafe
