import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:daeddong/features/map/presentation/map_screen.dart';
import 'package:daeddong/features/detail/presentation/detail_screen.dart';
import 'package:daeddong/features/favorites/presentation/favorites_screen.dart';
import 'package:daeddong/features/report/presentation/report_screen.dart';

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
        final seq = int.parse(state.pathParameters['seq']!);
        return DetailScreen(seq: seq);
      },
    ),
    GoRoute(
      path: '/report/:seq',
      builder: (context, state) {
        final seq = int.parse(state.pathParameters['seq']!);
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
