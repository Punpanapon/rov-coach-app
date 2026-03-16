import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rov_coach/presentation/roster/roster_screen.dart';
import 'package:rov_coach/presentation/strategy/strategy_screen.dart';
import 'package:rov_coach/presentation/draft/smart_draft_screen.dart';
import 'package:rov_coach/presentation/results/results_screen.dart';
import 'package:rov_coach/presentation/vod_review/vod_review_screen.dart';
import 'package:rov_coach/presentation/hall_of_fame/hall_of_fame_screen.dart';
import 'package:rov_coach/providers/vod_review_provider.dart';

/// Generates a short, URL-safe alphanumeric room ID (8 chars).
String _generateRoomId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final path = state.uri.path;

    // Any route without a room ID → generate one and redirect to roster
    if (path == '/' || path == '/roster' || path == '/strategies' ||
        path == '/draft' || path == '/results' || path == '/vod') {
      return '/room/${_generateRoomId()}/roster';
    }
    return null;
  },
  routes: [
    // All tabs live inside /room/:roomId — one room per session
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/room/:roomId/roster',
          pageBuilder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return NoTransitionPage(
              child: RosterScreen(roomId: roomId),
            );
          },
        ),
        GoRoute(
          path: '/room/:roomId/strategies',
          pageBuilder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return NoTransitionPage(
              child: StrategyScreen(roomId: roomId),
            );
          },
        ),
        GoRoute(
          path: '/room/:roomId/draft',
          pageBuilder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return NoTransitionPage(
              child: DraftScreen(roomId: roomId),
            );
          },
        ),
        GoRoute(
          path: '/room/:roomId/results',
          pageBuilder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return NoTransitionPage(
              child: ResultsScreen(roomId: roomId),
            );
          },
        ),
        GoRoute(
          path: '/room/:roomId/vod',
          pageBuilder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return NoTransitionPage(
              child: VodReviewScreen(roomId: roomId),
            );
          },
        ),
        GoRoute(
          path: '/room/:roomId/fame',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HallOfFameScreen(),
          ),
        ),
      ],
    ),
  ],
);

/// Shell widget providing the persistent bottom navigation bar.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabSuffixes = ['roster', 'strategies', 'draft', 'results', 'vod', 'fame'];

  /// Extract the roomId from the current URL.
  String? _roomId(BuildContext context) {
    return GoRouterState.of(context).pathParameters['roomId'];
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // Match the last segment after /room/:roomId/
    final match = RegExp(r'^/room/[^/]+/(\w+)').firstMatch(location);
    if (match != null) {
      final tab = match.group(1);
      final idx = _tabSuffixes.indexOf(tab!);
      if (idx >= 0) return idx;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final roomId = _roomId(context);
    final isFullscreen = ref.watch(isFullscreenProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: isFullscreen
          ? null
          : NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          // Navigate within the same room — preserves the roomId
          if (roomId != null) {
            context.go('/room/$roomId/${_tabSuffixes[i]}');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Roster',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_mosaic_outlined),
            selectedIcon: Icon(Icons.auto_awesome_mosaic),
            label: 'Strategies',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'Draft',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Results',
          ),
          NavigationDestination(
            icon: Icon(Icons.ondemand_video_outlined),
            selectedIcon: Icon(Icons.ondemand_video),
            label: 'VOD',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Hall',
          ),
        ],
      ),
    );
  }
}
