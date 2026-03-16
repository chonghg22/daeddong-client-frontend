import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import 'package:daeddong/data/models/toilet_model.dart';
import 'package:daeddong/features/detail/providers/detail_provider.dart';
import 'package:daeddong/features/favorites/providers/favorites_provider.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final int seq;

  const DetailScreen({super.key, required this.seq});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(detailProvider.notifier).loadToiletDetail(widget.seq);
    });
  }

  // ─────────────────────── 운영 여부 계산 ───────────────────────────

  bool _isOperating(String? openTime, String? closeTime) {
    if (openTime == null || closeTime == null) return false;
    final open = _parseTime(openTime);
    final close = _parseTime(closeTime);
    if (open == null || close == null) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    if (openMinutes == 0 && closeMinutes == 0) return true;

    if (closeMinutes > openMinutes) {
      return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
    } else {
      return nowMinutes >= openMinutes || nowMinutes < closeMinutes;
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour == 24) return const TimeOfDay(hour: 0, minute: 0);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────── 즐겨찾기 토글 ───────────────────────────

  void _toggleFavorite(ToiletModel toilet) {
    final notifier = ref.read(favoritesProvider.notifier);
    if (notifier.isFavorite(toilet.seq)) {
      notifier.removeFavorite(toilet.seq!);
    } else {
      notifier.addFavorite(toilet);
    }
  }

  // ─────────────────────── 길 안내 다이얼로그 ──────────────────────

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
              _launchKakaoMap(toilet);
            },
            child: const Text('카카오맵'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchNaverMap(toilet);
            },
            child: const Text('네이버맵'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchKakaoMap(ToiletModel toilet) async {
    final appUrl = Uri.parse(
      'kakaomap://route?ep=${toilet.latitude},${toilet.longitude}&by=FOOT',
    );
    if (!await launchUrl(appUrl)) {
      final storeUrl = Platform.isIOS
          ? Uri.parse('https://apps.apple.com/app/id304608425')
          : Uri.parse(
              'https://play.google.com/store/apps/details?id=net.daum.android.map');
      await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchNaverMap(ToiletModel toilet) async {
    final name = Uri.encodeComponent(toilet.name ?? '화장실');
    final appUrl = Uri.parse(
      'nmap://navigation?dlat=${toilet.latitude}&dlng=${toilet.longitude}&dname=$name&appname=kr.co.daeddong',
    );
    if (!await launchUrl(appUrl)) {
      final storeUrl = Platform.isIOS
          ? Uri.parse('https://apps.apple.com/app/id311867728')
          : Uri.parse(
              'https://play.google.com/store/apps/details?id=com.nhn.android.nmap');
      await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    }
  }

  // ────────────────────────────── UI ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailProvider);
    final isFavorite = ref.watch(
      favoritesProvider.select((list) => list.any((t) => t.seq == widget.seq)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.toilet?.name ?? '화장실 상세',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (state.toilet != null)
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : null,
              ),
              onPressed: () => _toggleFavorite(state.toilet!),
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(DetailState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('데이터를 불러오지 못했어요.', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(detailProvider.notifier).loadToiletDetail(widget.seq),
              icon: const Icon(Icons.refresh),
              label: const Text('재시도'),
            ),
          ],
        ),
      );
    }

    final toilet = state.toilet;
    if (toilet == null) return const SizedBox.shrink();

    final operating = _isOperating(toilet.openTime, toilet.closeTime);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 운영 상태 뱃지 ──
          Row(
            children: [
              _OperatingBadge(isOperating: operating),
              if (toilet.toiletType != null) ...[
                const SizedBox(width: 8),
                _TypeBadge(type: toilet.toiletType!),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ── 기본 정보 ──
          const _SectionTitle(title: '기본 정보'),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              if (toilet.address != null)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: '주소',
                  value: toilet.address!,
                ),
              if (toilet.openTime != null)
                _InfoRow(
                  icon: Icons.access_time,
                  label: '운영시간',
                  value: '${toilet.openTime} ~ ${toilet.closeTime ?? ''}',
                ),
              if (toilet.countMan != null || toilet.countWomen != null)
                _InfoRow(
                  icon: Icons.wc,
                  label: '대변기 수',
                  value:
                      '남성 ${toilet.countMan ?? 0}개 / 여성 ${toilet.countWomen ?? 0}개',
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ── 편의 시설 ──
          const _SectionTitle(title: '편의 시설'),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              _FacilityRow(
                icon: Icons.child_care,
                label: '기저귀 교환대',
                available: toilet.babyYn == 'Y',
              ),
              _FacilityRow(
                icon: Icons.accessible,
                label: '장애인 화장실',
                available: toilet.unusualYn == 'Y',
              ),
              _FacilityRow(
                icon: Icons.videocam_outlined,
                label: 'CCTV',
                available: toilet.cctvYn == 'Y',
              ),
              _FacilityRow(
                icon: Icons.notifications_active_outlined,
                label: '비상벨',
                available: toilet.alarmYn == 'Y',
              ),
            ],
          ),

          // ── 비고 ──
          if (toilet.etc != null && toilet.etc!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle(title: '비고'),
            const SizedBox(height: 8),
            _InfoCard(
              children: [
                Text(
                  toilet.etc!,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),

          // ── 길 안내 버튼 ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showNavigationDialog(toilet),
              icon: const Icon(Icons.directions),
              label: const Text('길 안내'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── 정보 오류 신고 ──
          Center(
            child: TextButton.icon(
              onPressed: () {
                final name =
                    Uri.encodeComponent(toilet.name ?? '');
                context.push('/report/${toilet.seq}?name=$name');
              },
              icon: Icon(Icons.flag_outlined,
                  size: 16, color: Colors.grey.shade500),
              label: Text(
                '정보 오류 신고',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 보조 위젯 ───────────────────────────────────

class _OperatingBadge extends StatelessWidget {
  final bool isOperating;

  const _OperatingBadge({required this.isOperating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isOperating ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isOperating ? '운영중' : '운영종료',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isOperating ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type,
        style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _FacilityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool available;

  const _FacilityRow({
    required this.icon,
    required this.label,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: available ? Colors.green.shade500 : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: available ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ),
          Icon(
            available ? Icons.check_circle : Icons.cancel_outlined,
            size: 18,
            color: available ? Colors.green.shade400 : Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}
