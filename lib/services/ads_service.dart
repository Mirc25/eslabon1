import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads_ids.dart';

class AdsService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    if (!kReleaseMode) {
      debugPrint('[ADS] SDK inicializado. AppId=${AdsIds.appIdAndroid} (TEST MODE=${!kReleaseMode})');
    }
  }

  static AdRequest request() => const AdRequest();

  static void logLoadError(LoadAdError error, {String where = ''}) {
    debugPrint('[ADS][LOAD-ERROR] $where code=${error.code} domain=${error.domain} message=${error.message} '
        'respId=${error.responseInfo?.responseId} adapter=${error.responseInfo?.mediationAdapterClassName}');
  }

  static void enableTestAdsForQA({List<String> testDeviceIds = const []}) {
    AdsIds.forceTest = true;
    if (testDeviceIds.isNotEmpty) {
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDeviceIds),
      );
    }
    debugPrint('[ADS] QA Test Ads FORCED: usando unidades de prueba en toda la app');
  }
}