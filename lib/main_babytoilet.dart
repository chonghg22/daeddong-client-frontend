import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:daeddong/core/constants/app_constants.dart';
import 'package:daeddong/core/router/app_router.dart';
import 'package:daeddong/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterNaverMap().init(clientId: AppConstants.naverMapClientId);
  await MobileAds.instance.initialize();
  runApp(const ProviderScope(child: BabyToiletApp()));
}

class BabyToiletApp extends StatelessWidget {
  const BabyToiletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '기저귀갈이대',
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
