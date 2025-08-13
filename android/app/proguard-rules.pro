# android/app/proguard-rules.pro

# Reglas mínimas seguras para Flutter embedding v2
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Si usás Firebase/Play Services, es seguro mantener anotaciones
-keepattributes *Annotation*

# (Agregá keep rules específicas si alguna lib lo requiere)
