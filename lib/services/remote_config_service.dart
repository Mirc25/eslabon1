import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late FirebaseRemoteConfig _rc;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _rc = FirebaseRemoteConfig.instance;
    // Defaults sensatos
    await _rc.setDefaults({
      'page_size': 20,
      'prefetch_enabled': true,
      'realtime_enabled': true,
      'thumbnail_size': 192, // px
      'cache_limit': 50, // elementos en memoria por lista
    });

    // Intervalos de fetch agresivos en debug, más largos en release
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 5),
      minimumFetchInterval: kReleaseMode ? const Duration(hours: 1) : const Duration(minutes: 1),
    ));

    try {
      await _rc.fetchAndActivate();
    } catch (_) {
      // Silencioso: usar defaults si falla
    }
    _initialized = true;
  }

  int getPageSize({int fallback = 20}) => _rc.getInt('page_size') > 0 ? _rc.getInt('page_size') : fallback;
  bool getPrefetchEnabled({bool fallback = true}) => _rc.getBool('prefetch_enabled');
  bool getRealtimeEnabled({bool fallback = true}) => _rc.getBool('realtime_enabled');
  int getThumbnailSize({int fallback = 192}) => _rc.getInt('thumbnail_size') > 0 ? _rc.getInt('thumbnail_size') : fallback;
  int getCacheLimit({int fallback = 50}) => _rc.getInt('cache_limit') > 0 ? _rc.getInt('cache_limit') : fallback;
}