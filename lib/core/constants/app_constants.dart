import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static String get naverMapClientId => dotenv.env['NAVER_MAP_CLIENT_ID']!;

  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;

  static const double defaultLat = 37.5665;
  static const double defaultLng = 126.9780;

  // ── AdMob ──────────────────────────────────────────────────────────
  static const bool _isRelease = bool.fromEnvironment('dart.vm.product');
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'daeddong',
  );

  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  static String get bannerAdUnitId {
    if (!_isRelease) return _testBannerAdUnitId;
    return flavor == 'babytoilet'
        ? dotenv.env['ADMOB_BABYTOILET_BANNER_ID']!
        : dotenv.env['ADMOB_DAEDDONG_BANNER_ID']!;
  }
}
