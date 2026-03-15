import 'package:go_router/go_router.dart';
import 'package:daeddong/features/map/presentation/map_screen.dart';
import 'package:daeddong/features/detail/presentation/detail_screen.dart';
import 'package:daeddong/features/favorites/presentation/favorites_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/map',
  routes: [
    GoRoute(
      path: '/map',
      builder: (context, state) => const MapScreen(),
    ),
    GoRoute(
      path: '/detail/:seq',
      builder: (context, state) {
        final seq = int.parse(state.pathParameters['seq']!);
        return DetailScreen(seq: seq);
      },
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
  ],
);
