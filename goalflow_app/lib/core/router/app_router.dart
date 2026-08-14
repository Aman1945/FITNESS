import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/verify_email_screen.dart';
import '../../presentation/screens/calendar_screen.dart';
import '../../presentation/screens/editors/create_action_screen.dart';
import '../../presentation/screens/editors/create_goal_screen.dart';
import '../../presentation/screens/editors/create_milestone_screen.dart';
import '../../presentation/screens/goal_detail_screen.dart';
import '../../presentation/screens/goals_screen.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/notifications_screen.dart';
import '../../presentation/screens/onboarding_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../presentation/screens/progress_screen.dart';
import '../../presentation/screens/reflection_screen.dart';
import '../../presentation/screens/settings/notification_prefs_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/shell.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/today_screen.dart';

/// Routing is declarative and the auth guard lives in exactly one redirect,
/// so no screen has to check "am I signed in?" for itself.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthStage>(AuthStage.unknown);
  ref.listen(authProvider, (_, next) => auth.value = next.stage);
  ref.onDispose(auth.dispose);

  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final stage = ref.read(authProvider).stage;
      final path = state.matchedLocation;

      const publicPaths = {
        '/login',
        '/register',
        '/forgot-password',
        '/verify-email',
      };
      final isPublic = publicPaths.contains(path);

      if (stage == AuthStage.unknown) return path == '/splash' ? null : '/splash';
      if (stage == AuthStage.signedOut) return isPublic ? null : '/login';
      if (stage == AuthStage.needsOnboarding) {
        return path == '/onboarding' || path == '/verify-email' ? null : '/onboarding';
      }
      // signed in and onboarded
      if (isPublic || path == '/splash' || path == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // Bottom-navigation shell keeps its own navigator so tab state survives.
      ShellRoute(
        navigatorKey: shellKey,
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/goals', builder: (_, __) => const GoalsScreen()),
          GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
          GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
      GoRoute(path: '/reflection', builder: (_, __) => const ReflectionScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const NotificationPrefsScreen(),
      ),
      GoRoute(path: '/goals/new', builder: (_, __) => const CreateGoalScreen()),
      GoRoute(
        path: '/goals/:id',
        builder: (_, s) => GoalDetailScreen(goalId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/goals/:id/edit',
        builder: (_, s) => CreateGoalScreen(goalId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/goals/:id/milestones/new',
        builder: (_, s) => CreateMilestoneScreen(goalId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/goals/:id/actions/new',
        builder: (_, s) => CreateActionScreen(
          goalId: s.pathParameters['id']!,
          milestoneId: s.uri.queryParameters['milestone'],
        ),
      ),
    ],
  );
});
