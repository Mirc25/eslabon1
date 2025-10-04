import 'package:flutter/foundation.dart';

/// IDs de prueba oficiales de Google (no dependen de tu cuenta)
class _TestIds {
  static const appIdAndroid = 'ca-app-pub-3940256099942544~3347511713';
  static const banner = 'ca-app-pub-3940256099942544/6300978111';
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const rewarded = 'ca-app-pub-3940256099942544/5224354917';
}

/// IDs de producción (pertenecen a TU app en AdMob con package correcto)
class _ProdIds {
  // App ID (Android) — coincide con el del AndroidManifest
  static const appIdAndroid = 'ca-app-pub-5954736095854364~4049272593';

  // Unidades de anuncio de producción
  static const banner = 'ca-app-pub-5954736099942544/7481251141';
  static const interstitial = 'ca-app-pub-5954736099942544/8184761052';
  static const rewarded = 'ca-app-pub-5954736099942544/2964239873';
}

class AdsIds {
  static bool forceTest = false;
  static String get appIdAndroid =>
      forceTest ? _TestIds.appIdAndroid : (kReleaseMode ? _ProdIds.appIdAndroid : _TestIds.appIdAndroid);
  static String get banner =>
      forceTest ? _TestIds.banner : (kReleaseMode ? _ProdIds.banner : _TestIds.banner);
  static String get interstitial =>
      forceTest ? _TestIds.interstitial : (kReleaseMode ? _ProdIds.interstitial : _TestIds.interstitial);
  static String get rewarded =>
      forceTest ? _TestIds.rewarded : (kReleaseMode ? _ProdIds.rewarded : _TestIds.rewarded);
}