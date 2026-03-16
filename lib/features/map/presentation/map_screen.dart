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

// 필터 칩 바 높이 (포지셔닝 계산에 사용)
const double _kFilterBarHeight = 52.0;

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
        content: const Text('위치 권한이 영구적으로 거부되었어요.\n설정에서 권한을 허용해 주세요.'),
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
        (_currentCameraPosition.latitude - _lastSearchedPosition.latitude).abs();
    final lngDiff =
        (_currentCameraPosition.longitude - _lastSearchedPosition.longitude).abs();

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

  // ─────────────────────── 필터 바텀시트 ────────────────────────────

  void _showFilterBottomSheet(FilterState currentFilter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterBottomSheet(
        initialFilter: currentFilter,
        onApply: (filter) =>
            ref.read(mapProvider.notifier).applyFilter(filter),
      ),
    );
  }

  // ─────────────────────── 필터 칩 바 ──────────────────────────────

  Widget _buildFilterChipBar(FilterState filterState) {
    void toggle(FilterState updated) =>
        ref.read(mapProvider.notifier).applyFilter(updated);

    return Container(
      color: Colors.white,
      height: _kFilterBarHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _MapFilterChip(
              label: '필터',
              icon: Icons.tune,
              selected: filterState.hasAnyFilter,
              onTap: () => _showFilterBottomSheet(filterState),
            ),
            const SizedBox(width: 8),
            _MapFilterChip(
              label: '24시간',
              selected: filterState.isAlwaysOpen,
              onTap: () => toggle(
                  filterState.copyWith(isAlwaysOpen: !filterState.isAlwaysOpen)),
            ),
            const SizedBox(width: 8),
            _MapFilterChip(
              label: '운영중',
              selected: filterState.isOperatingNow,
              onTap: () => toggle(filterState.copyWith(
                  isOperatingNow: !filterState.isOperatingNow)),
            ),
            const SizedBox(width: 8),
            _MapFilterChip(
              label: '기저귀',
              selected: filterState.hasBaby,
              onTap: () =>
                  toggle(filterState.copyWith(hasBaby: !filterState.hasBaby)),
            ),
            const SizedBox(width: 8),
            _MapFilterChip(
              label: '장애인',
              selected: filterState.hasDisabled,
              onTap: () => toggle(
                  filterState.copyWith(hasDisabled: !filterState.hasDisabled)),
            ),
            const SizedBox(width: 8),
            _MapFilterChip(
              label: 'CCTV',
              selected: filterState.hasCctv,
              onTap: () =>
                  toggle(filterState.copyWith(hasCctv: !filterState.hasCctv)),
            ),
            const SizedBox(width: 8),
            _MapFilterChip(
              label: '비상벨',
              selected: filterState.hasAlarm,
              onTap: () =>
                  toggle(filterState.copyWith(hasAlarm: !filterState.hasAlarm)),
            ),
            const SizedBox(width: 8),
            _MapFilterChip(
              label: '공중화장실',
              selected: filterState.toiletType == '공중화장실',
              onTap: () => toggle(
                filterState.toiletType == '공중화장실'
                    ? filterState.copyWith(clearToiletType: true)
                    : filterState.copyWith(toiletType: '공중화장실'),
              ),
            ),
            const SizedBox(width: 8),
            _MapFilterChip(
              label: '개방화장실',
              selected: filterState.toiletType == '개방화장실',
              onTap: () => toggle(
                filterState.toiletType == '개방화장실'
                    ? filterState.copyWith(clearToiletType: true)
                    : filterState.copyWith(toiletType: '개방화장실'),
              ),
            ),
          ],
        ),
      ),
    );
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

    // filteredToiletList 변경 → 마커 갱신 + 빈 결과 토스트
    ref.listen(mapProvider.select((s) => s.filteredToiletList),
        (prev, filtered) {
      _updateMarkers(filtered);
      if (filtered.isEmpty &&
          prev != null &&
          prev.isNotEmpty &&
          ref.read(mapProvider).filterState.hasAnyFilter) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('조건에 맞는 화장실이 없어요'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    ref.listen(mapProvider.select((s) => s.error), (_, error) {
      if (error != null && error.contains('network')) {
        _showNetworkErrorSnackBar();
      }
    });

    final bannerHeight =
        _bannerAdLoaded ? (_bannerAd?.size.height ?? 50).toDouble() : 0.0;
    final topOffset = topPadding + (_locationDenied ? 44.0 : 0.0);

    return Scaffold(
      body: Stack(
        children: [
          // ── 네이버 지도 ──
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target:
                    NLatLng(AppConstants.defaultLat, AppConstants.defaultLng),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: const Text(
                    '위치 권한을 허용하면 내 주변 화장실을 찾을 수 있어요  ›',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // ── 필터 칩 바 ──
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: _buildFilterChipBar(mapState.filterState),
          ),

          // ── 이 지역 검색 버튼 ──
          if (_showSearchHereButton)
            Positioned(
              top: topOffset + _kFilterBarHeight + 8,
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
              top: topOffset + _kFilterBarHeight + 8,
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
                        onPressed: () =>
                            _loadToilets(_currentCameraPosition, _currentZoom),
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

// ─────────────────────── 필터 칩 위젯 ────────────────────────────────

class _MapFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _MapFilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14,
                  color: selected ? Colors.white : Colors.grey.shade700),
              const SizedBox(width: 4),
            ] else if (selected) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── 필터 바텀시트 ───────────────────────────────

class _FilterBottomSheet extends StatefulWidget {
  final FilterState initialFilter;
  final void Function(FilterState) onApply;

  const _FilterBottomSheet({
    required this.initialFilter,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late FilterState _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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

            // 타이틀 + 초기화
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('필터',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () =>
                      setState(() => _filter = const FilterState()),
                  child: const Text('초기화'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // 토글 스위치 항목들
            _FilterSwitchRow(
              label: '24시간 운영',
              value: _filter.isAlwaysOpen,
              onChanged: (v) =>
                  setState(() => _filter = _filter.copyWith(isAlwaysOpen: v)),
            ),
            _FilterSwitchRow(
              label: '현재 운영중인 곳만',
              value: _filter.isOperatingNow,
              onChanged: (v) =>
                  setState(() => _filter = _filter.copyWith(isOperatingNow: v)),
            ),
            _FilterSwitchRow(
              label: '기저귀교환대 있음',
              value: _filter.hasBaby,
              onChanged: (v) =>
                  setState(() => _filter = _filter.copyWith(hasBaby: v)),
            ),
            _FilterSwitchRow(
              label: '장애인 화장실 있음',
              value: _filter.hasDisabled,
              onChanged: (v) =>
                  setState(() => _filter = _filter.copyWith(hasDisabled: v)),
            ),
            _FilterSwitchRow(
              label: 'CCTV 있음',
              value: _filter.hasCctv,
              onChanged: (v) =>
                  setState(() => _filter = _filter.copyWith(hasCctv: v)),
            ),
            _FilterSwitchRow(
              label: '비상벨 있음',
              value: _filter.hasAlarm,
              onChanged: (v) =>
                  setState(() => _filter = _filter.copyWith(hasAlarm: v)),
            ),

            const SizedBox(height: 12),

            // 화장실 종류
            const Text('화장실 종류',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _ToiletTypeChip(
                  label: '전체',
                  selected: _filter.toiletType == null,
                  onTap: () => setState(
                      () => _filter = _filter.copyWith(clearToiletType: true)),
                ),
                _ToiletTypeChip(
                  label: '공중화장실',
                  selected: _filter.toiletType == '공중화장실',
                  onTap: () => setState(() => _filter =
                      _filter.copyWith(toiletType: '공중화장실')),
                ),
                _ToiletTypeChip(
                  label: '개방화장실',
                  selected: _filter.toiletType == '개방화장실',
                  onTap: () => setState(() => _filter =
                      _filter.copyWith(toiletType: '개방화장실')),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 적용 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onApply(_filter);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('적용', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }
}

class _ToiletTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToiletTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          border: Border.all(color: selected ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
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
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
