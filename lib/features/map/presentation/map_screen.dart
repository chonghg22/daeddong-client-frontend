import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:daeddong/core/constants/app_constants.dart';
import 'package:daeddong/data/models/toilet_model.dart';
import 'package:daeddong/features/map/providers/map_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NaverMapController? _mapController;

  BannerAd? _bannerAd;
  bool _bannerAdLoaded = false;

  bool _locationDenied = false;
  bool _showSearchHereButton = false;

  NLatLng _lastSearchedPosition =
      const NLatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  NLatLng _currentCameraPosition =
      const NLatLng(AppConstants.defaultLat, AppConstants.defaultLng);
  double _currentZoom = 15;

  // 지도가 첫 번째 idle 이벤트를 받았는지 추적
  bool _mapReady = false;

  static const double _searchButtonThresholdDeg = 0.005;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleLocationPermission();
    });
  }

  // ───────────────────────────── AdMob ─────────────────────────────

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerAdLoaded = true),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  // ───────────────────────── 위치 권한 처리 ──────────────────────────

  Future<void> _handleLocationPermission() async {
    final confirmed = await _showLocationGuideDialog();
    if (!confirmed || !mounted) return;

    final status = await Permission.location.request();

    if (status.isGranted) {
      await _moveToCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() => _locationDenied = true);
        _showOpenSettingsDialog();
      }
    } else {
      if (mounted) setState(() => _locationDenied = true);
    }
  }

  Future<bool> _showLocationGuideDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text('근처 화장실을 찾으려면 위치 권한이 필요해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text(
            '위치 권한이 영구적으로 거부되었어요.\n설정에서 권한을 허용해 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = NLatLng(position.latitude, position.longitude);
      _currentCameraPosition = latLng;
      _lastSearchedPosition = latLng;
      await _mapController?.updateCamera(
        NCameraUpdate.withParams(target: latLng, zoom: 15),
      );
    } catch (_) {
      // 위치 오류 시 기본 위치 유지
    }
  }

  // ─────────────────────── 화장실 데이터 로드 ────────────────────────

  double _getDistanceByZoom(double zoom) {
    if (zoom >= 15) return 500;
    if (zoom >= 13) return 1000;
    return 2000;
  }

  void _loadToilets(NLatLng position, double zoom) {
    final distance = _getDistanceByZoom(zoom);
    ref.read(mapProvider.notifier).loadToilets(
          position.latitude,
          position.longitude,
          distance,
        );
    _lastSearchedPosition = position;
    if (mounted) setState(() => _showSearchHereButton = false);
  }

  // ──────────────────────── 카메라 이벤트 ───────────────────────────

  void _onCameraChange(NCameraUpdateReason reason, bool isAnimated) {
    // 사용자가 직접 지도를 움직인 경우에만 검색 버튼 표시
    if (!isAnimated && _mapReady && !_showSearchHereButton) {
      if (mounted) setState(() => _showSearchHereButton = true);
    }
  }

  Future<void> _onCameraIdle() async {
    final cameraPosition = await _mapController?.getCameraPosition();
    if (cameraPosition == null) return;

    _currentCameraPosition = cameraPosition.target;
    _currentZoom = cameraPosition.zoom;

    if (!_mapReady) {
      _mapReady = true;
      _loadToilets(_currentCameraPosition, _currentZoom);
      return;
    }

    final latDiff =
        (_currentCameraPosition.latitude - _lastSearchedPosition.latitude)
            .abs();
    final lngDiff =
        (_currentCameraPosition.longitude - _lastSearchedPosition.longitude)
            .abs();

    if (latDiff > _searchButtonThresholdDeg ||
        lngDiff > _searchButtonThresholdDeg) {
      if (mounted) setState(() => _showSearchHereButton = true);
    } else {
      _loadToilets(_currentCameraPosition, _currentZoom);
    }
  }

  // ────────────────────────── 마커 처리 ────────────────────────────

  Future<void> _updateMarkers(List<ToiletModel> toilets) async {
    if (_mapController == null) return;

    final markers = toilets
        .where((t) => t.latitude != null && t.longitude != null)
        .map((t) {
          final marker = NClusterableMarker(
            id: 'toilet_${t.seq ?? math.Random().nextInt(999999)}',
            position: NLatLng(t.latitude!, t.longitude!),
          );
          marker.setOnTapListener((_) => _showToiletBottomSheet(t));
          return marker;
        })
        .toSet();

    await _mapController!.clearOverlays(type: NOverlayType.clusterableMarker);
    if (markers.isNotEmpty) {
      await _mapController!.addOverlayAll(markers);
    }
  }

  // ─────────────────────── 바텀시트 / 다이얼로그 ────────────────────

  void _showToiletBottomSheet(ToiletModel toilet) {
    ref.read(mapProvider.notifier).selectToilet(toilet);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ToiletBottomSheet(
        toilet: toilet,
        onDetailTap: () {
          Navigator.pop(ctx);
          context.push('/detail/${toilet.seq}');
        },
        onNavigateTap: () {
          Navigator.pop(ctx);
          _showNavigationDialog(toilet);
        },
      ),
    ).whenComplete(() => ref.read(mapProvider.notifier).clearSelection());
  }

  void _showNavigationDialog(ToiletModel toilet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('길 안내'),
        content: const Text('사용할 지도 앱을 선택하세요.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchNaverMap(toilet);
            },
            child: const Text('네이버맵'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchKakaoMap(toilet);
            },
            child: const Text('카카오맵'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchNaverMap(ToiletModel toilet) async {
    final name = Uri.encodeComponent(toilet.name ?? '화장실');
    final appUrl = Uri.parse(
      'nmap://route/public?dlat=${toilet.latitude}&dlng=${toilet.longitude}&dname=$name&appname=kr.co.daeddong',
    );
    final webUrl = Uri.parse(
      'https://map.naver.com/v5/directions/-/-/-/transit?c=${toilet.longitude},${toilet.latitude},15,0,0,0,dh',
    );
    if (!await launchUrl(appUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchKakaoMap(ToiletModel toilet) async {
    final appUrl = Uri.parse(
      'kakaomap://look?p=${toilet.latitude},${toilet.longitude}',
    );
    final webUrl = Uri.parse(
      'https://map.kakao.com/link/to/${Uri.encodeComponent(toilet.name ?? '화장실')},${toilet.latitude},${toilet.longitude}',
    );
    if (!await launchUrl(appUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ────────────────────────── 네트워크 에러 ─────────────────────────

  void _showNetworkErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('네트워크 연결을 확인해 주세요.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ─────────────────────────── dispose ─────────────────────────────

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  // ────────────────────────────── UI ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final mapState = ref.watch(mapProvider);

    ref.listen(mapProvider.select((s) => s.toiletList), (_, toilets) {
      _updateMarkers(toilets);
    });

    ref.listen(mapProvider.select((s) => s.error), (_, error) {
      if (error != null && error.contains('network')) {
        _showNetworkErrorSnackBar();
      }
    });

    final bannerHeight = _bannerAdLoaded ? (_bannerAd?.size.height ?? 50).toDouble() : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          // ── 네이버 지도 ──
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(AppConstants.defaultLat, AppConstants.defaultLng),
                zoom: 15,
              ),
              locationButtonEnable: true,
            ),
            clusterOptions: const NaverMapClusteringOptions(),
            onMapReady: (controller) {
              _mapController = controller;
            },
            onCameraChange: _onCameraChange,
            onCameraIdle: _onCameraIdle,
          ),

          // ── 위치 권한 거부 배너 ──
          if (_locationDenied)
            Positioned(
              top: topPadding,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: openAppSettings,
                child: Container(
                  color: Colors.orange.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Text(
                    '위치 권한을 허용하면 내 주변 화장실을 찾을 수 있어요  ›',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // ── 이 지역 검색 버튼 ──
          if (_showSearchHereButton)
            Positioned(
              top: topPadding + (_locationDenied ? 44 : 0) + 12,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _loadToilets(_currentCameraPosition, _currentZoom),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('이 지역 검색'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),

          // ── 로딩 인디케이터 ──
          if (mapState.isLoading)
            Positioned(
              top: topPadding + (_locationDenied ? 44 : 0) + 12,
              left: 0,
              right: 0,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),

          // ── API 에러 카드 ──
          if (mapState.error != null)
            Positioned(
              bottom: bannerHeight + 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '데이터를 불러오지 못했어요.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _loadToilets(
                            _currentCameraPosition, _currentZoom),
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── AdMob 배너 ──
          if (_bannerAdLoaded && _bannerAd != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                width: double.infinity,
                height: bannerHeight,
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────── 바텀시트 위젯 ──────────────────────────────

class _ToiletBottomSheet extends StatelessWidget {
  final ToiletModel toilet;
  final VoidCallback onDetailTap;
  final VoidCallback onNavigateTap;

  const _ToiletBottomSheet({
    required this.toilet,
    required this.onDetailTap,
    required this.onNavigateTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 이름
            Text(
              toilet.name ?? '화장실',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // 주소
            if (toilet.address != null)
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: toilet.address!,
              ),

            // 개방시간
            if (toilet.openTime != null)
              _InfoRow(
                icon: Icons.access_time,
                text: '${toilet.openTime} ~ ${toilet.closeTime ?? ''}',
              ),

            const SizedBox(height: 10),

            // 태그
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (toilet.babyYn == 'Y')
                  _Tag(label: '기저귀 교환대', color: Colors.blue.shade100),
                if (toilet.unusualYn == 'Y')
                  _Tag(label: '장애인 화장실', color: Colors.green.shade100),
                if (toilet.cctvYn == 'Y')
                  _Tag(label: 'CCTV', color: Colors.orange.shade100),
                if (toilet.alarmYn == 'Y')
                  _Tag(label: '비상벨', color: Colors.purple.shade100),
              ],
            ),

            const SizedBox(height: 16),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNavigateTap,
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('길 안내'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDetailTap,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('상세보기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
