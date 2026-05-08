import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:daeddong/core/constants/app_constants.dart';

/// 고정 높이(50px) AdMob 배너 위젯.
/// 광고 로드 전에도 높이를 유지해 레이아웃이 흔들리지 않습니다.
class AdmobBannerWidget extends StatefulWidget {
  const AdmobBannerWidget({super.key});

  @override
  State<AdmobBannerWidget> createState() => _AdmobBannerWidgetState();
}

class _AdmobBannerWidgetState extends State<AdmobBannerWidget> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AppConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '[AdmobBannerWidget] onAdFailedToLoad code=${error.code} message=${error.message}',
          );
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: _loaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : const SizedBox.shrink(),
    );
  }
}
