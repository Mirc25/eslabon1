import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ads_service.dart';

class AdBannerWidget extends StatefulWidget {
  final String adUnitId;
  final AdSize size;

  const AdBannerWidget({
    super.key,
    required this.adUnitId,
    this.size = AdSize.banner,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _loaded = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _createAndLoad();
  }

  void _createAndLoad() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.size,
      request: AdsService.request(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _loaded = true);
          debugPrint('[ADS] Banner loaded: ${ad.adUnitId} size: ${widget.size.width}x${widget.size.height}');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() => _loaded = false);
          AdsService.logLoadError(error, where: 'AdBannerWidget');
          _scheduleRetry();
        },
      ),
    );
    _bannerAd!.load();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      _createAndLoad();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size.width.toDouble();
    final h = widget.size.height.toDouble();

    return SizedBox(
      width: w,
      height: h,
      child: _loaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : const SizedBox.shrink(),
    );
  }
}