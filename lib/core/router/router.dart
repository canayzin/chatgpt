import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/categories/presentation/categories_screen.dart';
import '../../features/content_studio/presentation/admin_content_dashboard_screen.dart';
import '../../features/categories/presentation/category_feed_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/growth/daily_knowledge/presentation/daily_knowledge_screen.dart';
import '../../features/growth/learning_series/presentation/learning_series_screen.dart';
import '../../features/growth/podcast/presentation/podcast_screen.dart';
import '../../features/growth/quiz/presentation/quiz_screen.dart';
import '../../features/growth/trending/presentation/trending_screen.dart';
import '../../features/growth/viral/presentation/invite_friends_screen.dart';
import '../../features/pages/favorites/presentation/favorites_screen.dart';
import '../../features/pages/profile/presentation/profile_screen.dart';
import '../../features/pages/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../navigation/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/feed',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
          GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
          GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/categories/:category',
        builder: (context, state) => CategoryFeedScreen(category: state.pathParameters['category'] ?? 'general'),
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/trending', builder: (context, state) => const TrendingScreen()),
      GoRoute(path: '/daily', builder: (context, state) => const DailyKnowledgeScreen()),
      GoRoute(path: '/series', builder: (context, state) => const LearningSeriesScreen()),
      GoRoute(path: '/podcast', builder: (context, state) => const PodcastScreen()),
      GoRoute(path: '/invite', builder: (context, state) => const InviteFriendsScreen()),
      GoRoute(path: '/admin/content-studio', builder: (context, state) => const AdminContentDashboardScreen()),
      GoRoute(
        path: '/quiz/:topic',
        builder: (context, state) => QuizScreen(topic: state.pathParameters['topic'] ?? 'psychology'),
      ),
    ],
    redirect: (context, state) => state.uri.path == '/' ? '/feed' : null,
  );
});
