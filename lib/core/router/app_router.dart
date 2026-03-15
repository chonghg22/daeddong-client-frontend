import 'package:go_router/go_router.dart';
import 'package:daeddong/features/map/presentation/map_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MapScreen(),
    ),
  ],
);
