class AppConstants {
  AppConstants._();

  static const String naverMapClientId = 'REDACTED_NAVER_CLIENT_ID';

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://daeddong-client-backend-production.up.railway.app',
  );

  static const double defaultLat = 37.5665;
  static const double defaultLng = 126.9780;

  // ── AdMob ──────────────────────────────────────────────────────────
  // dart.vm.product = true in release (AOT) mode, false in debug/profile
  static const bool _isRelease = bool.fromEnvironment('dart.vm.product');
  static const String _flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'daeddong',
  );

  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _daeddongBannerAdUnitId =
      'REDACTED_ADMOB_DAEDDONG';
  static const String _babytoiletBannerAdUnitId =
      'REDACTED_ADMOB_BABYTOILET';

  static String get bannerAdUnitId {
    if (!_isRelease) return _testBannerAdUnitId;
    return _flavor == 'babytoilet'
        ? _babytoiletBannerAdUnitId
        : _daeddongBannerAdUnitId;
  }
}
