class AppConstants {
  AppConstants._();

  static const String naverMapClientId = 'f2lsyu7q3s';

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:16060',
  );

  static const double defaultLat = 37.5665;
  static const double defaultLng = 126.9780;
}
