import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:daeddong/features/map/presentation/map_screen.dart';
import 'package:daeddong/features/detail/presentation/detail_screen.dart';
import 'package:daeddong/features/favorites/presentation/favorites_screen.dart';
import 'package:daeddong/features/report/presentation/report_screen.dart';

int? parseRouteSeq(String? rawSeq) => int.tryParse(rawSeq ?? '');

final appRouter = GoRouter(
  initialLocation: '/map',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(
          path: '/map',
          builder: (context, state) => const MapScreen(),
        ),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/detail/:seq',
      builder: (context, state) {
        final seq = parseRouteSeq(state.pathParameters['seq']);
        if (seq == null) {
          return const _RouteErrorScreen(message: '잘못된 상세 경로입니다.');
        }
        return DetailScreen(seq: seq);
      },
    ),
    GoRoute(
      path: '/report/:seq',
      builder: (context, state) {
        final seq = parseRouteSeq(state.pathParameters['seq']);
        if (seq == null) {
          return const _RouteErrorScreen(message: '잘못된 제보 경로입니다.');
        }
        final name = state.uri.queryParameters['name'] ?? '';
        return ReportScreen(seq: seq, toiletName: name);
      },
    ),
  ],
);

class _MainShell extends StatelessWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = location.startsWith('/favorites') ? 1 : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == 0) {
            context.go('/map');
          } else {
            context.go('/favorites');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: '즐겨찾기',
          ),
        ],
      ),
    );
  }
}

class _RouteErrorScreen extends StatelessWidget {
  final String message;

  const _RouteErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('경로 오류')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/map'),
                child: const Text('지도로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
