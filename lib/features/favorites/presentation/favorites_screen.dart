import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:daeddong/core/widgets/admob_banner_widget.dart';
import 'package:daeddong/data/models/toilet_model.dart';
import 'package:daeddong/features/favorites/providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기'),
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '전체 삭제',
              onPressed: () => _showClearAllDialog(context, ref),
            ),
        ],
      ),
      bottomNavigationBar: const AdmobBannerWidget(),
      body: favorites.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              itemCount: favorites.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final toilet = favorites[index];
                return _FavoriteItem(
                  toilet: toilet,
                  onTap: () => context.push('/detail/${toilet.seq}'),
                  onLongPress: () =>
                      _showDeleteDialog(context, ref, toilet),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '저장한 화장실이 없어요',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '지도에서 화장실을 찾아 즐겨찾기에 추가해보세요',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, ToiletModel toilet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('즐겨찾기 삭제'),
        content: Text(
          '"${toilet.name ?? '화장실'}"을\n즐겨찾기에서 삭제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (toilet.seq != null) {
                ref.read(favoritesProvider.notifier).removeFavorite(toilet.seq!);
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('즐겨찾기를 모두 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(favoritesProvider.notifier).clearAll();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _FavoriteItem extends StatelessWidget {
  final ToiletModel toilet;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FavoriteItem({
    required this.toilet,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.wc, color: Colors.green.shade400, size: 24),
            ),
            const SizedBox(width: 12),

            // 이름 + 주소
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    toilet.name ?? '화장실',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (toilet.address != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      toilet.address!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // 시설 아이콘
                  Row(
                    children: [
                      if (toilet.babyYn == 'Y')
                        _FacilityIcon(
                          icon: Icons.child_care,
                          label: '기저귀',
                          color: Colors.blue,
                        ),
                      if (toilet.unusualYn == 'Y')
                        _FacilityIcon(
                          icon: Icons.accessible,
                          label: '장애인',
                          color: Colors.green,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // 화살표
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _FacilityIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FacilityIcon({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
