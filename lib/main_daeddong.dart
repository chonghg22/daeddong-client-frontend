import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daeddong/core/constants/app_constants.dart';
import 'package:daeddong/core/router/app_router.dart';
import 'package:daeddong/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(clientId: AppConstants.naverMapClientId);
  runApp(const ProviderScope(child: DaeddongApp()));
}

class DaeddongApp extends StatelessWidget {
  const DaeddongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '대똥여지도',
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
